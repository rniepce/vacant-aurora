package com.vacantaurora.pricemonitor.data

import android.annotation.SuppressLint
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONObject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** One scraped row before it is merged into price history. */
data class CartScrapeItem(
    val id: String,
    val title: String,
    val price: Double,
    val imageURL: String?,
)

sealed class CartParserException(message: String) : Exception(message) {
    object LoginRequired : CartParserException("login_required")
    object NoItems : CartParserException("no_items")
    object Timeout : CartParserException("timeout")
    class ParseError(val reason: String) : CartParserException(reason)
}

/**
 * Loads the Amazon cart in an off-screen [WebView], waits for it to render, then
 * injects [assets/cart_parser.js] to scrape the items — mirroring the iOS
 * CartParser's hidden WKWebView approach. Cookies are shared with the login
 * WebView via the app-wide [CookieManager], so a logged-in session is reused.
 */
object CartParser {

    const val CART_URL = "https://www.amazon.com.br/gp/cart/view.html"

    // Full OpenID sign-in URL that returns to the cart, mirroring the iOS LoginView.
    // The bare /ap/signin path is rejected by Amazon ("page not found").
    const val SIGNIN_URL =
        "https://www.amazon.com.br/ap/signin?openid.pape.max_auth_age=0" +
            "&openid.return_to=https%3A%2F%2Fwww.amazon.com.br%2Fgp%2Fcart%2Fview.html" +
            "&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select" +
            "&openid.assoc_handle=brflex&openid.mode=checkid_setup" +
            "&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select" +
            "&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0"

    // Shared mobile Safari user agent so Amazon serves the same markup to login and
    // cart scraping — identical to the iOS app's AmazonWebView.userAgent.
    const val USER_AGENT =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
            "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private const val TIMEOUT_MS = 25_000L
    private const val RENDER_DELAY_MS = 1_500L

    @SuppressLint("SetJavaScriptEnabled")
    suspend fun fetchCart(context: Context): List<CartScrapeItem> =
        suspendCancellableCoroutine { continuation ->
            val main = Handler(Looper.getMainLooper())
            main.post {
                val script = runCatching {
                    context.assets.open("cart_parser.js").bufferedReader().use { it.readText() }
                }.getOrElse {
                    continuation.resumeWithException(CartParserException.ParseError("missing parser script"))
                    return@post
                }

                val webView = WebView(context.applicationContext)
                var finished = false

                CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
                webView.settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    userAgentString = USER_AGENT
                }

                fun teardown() {
                    webView.stopLoading()
                    webView.webViewClient = WebViewClient()
                    webView.destroy()
                }

                fun finish(result: Result<List<CartScrapeItem>>) {
                    if (finished) return
                    finished = true
                    main.removeCallbacksAndMessages(null)
                    teardown()
                    if (continuation.isActive) continuation.resumeWith(result)
                }

                // Watchdog: always finish even if the page hangs (captcha, redirect loop).
                main.postDelayed({
                    finish(Result.failure(CartParserException.Timeout))
                }, TIMEOUT_MS)

                webView.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView, url: String?) {
                        if (finished) return

                        if (url != null && (url.contains("signin") || url.contains("ap/signin"))) {
                            finish(Result.failure(CartParserException.LoginRequired))
                            return
                        }

                        // Give dynamic content a moment to render, then inject the parser.
                        main.postDelayed({
                            if (finished) return@postDelayed
                            view.evaluateJavascript(script) { raw ->
                                finish(parseResult(raw))
                            }
                        }, RENDER_DELAY_MS)
                    }

                    override fun onReceivedError(
                        view: WebView,
                        errorCode: Int,
                        description: String?,
                        failingUrl: String?,
                    ) {
                        finish(Result.failure(CartParserException.ParseError(description ?: "load error")))
                    }
                }

                continuation.invokeOnCancellation { main.post { finish(Result.failure(CartParserException.Timeout)) } }
                webView.loadUrl(CART_URL)
            }
        }

    /** evaluateJavascript hands back a JSON-encoded string literal; decode it then parse. */
    private fun parseResult(raw: String?): Result<List<CartScrapeItem>> {
        if (raw == null || raw == "null") return Result.failure(CartParserException.NoItems)
        return try {
            // The result is a quoted JSON string ("{...}"); unwrap it to the inner JSON.
            val inner = org.json.JSONTokener(raw).nextValue()
            val json = when (inner) {
                is String -> JSONObject(inner)
                is JSONObject -> inner
                else -> return Result.failure(CartParserException.NoItems)
            }
            if (json.has("error")) return Result.failure(CartParserException.LoginRequired)

            val arr = json.optJSONArray("items")
                ?: return Result.failure(CartParserException.NoItems)
            val items = buildList {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val id = o.optString("id", "")
                    val title = o.optString("title", "")
                    if (id.isEmpty()) continue
                    add(
                        CartScrapeItem(
                            id = id,
                            title = title.ifEmpty { "Unknown Product" },
                            price = o.optDouble("price", 0.0),
                            imageURL = if (o.isNull("imageURL")) null else o.optString("imageURL").ifEmpty { null },
                        )
                    )
                }
            }
            if (items.isEmpty()) Result.failure(CartParserException.NoItems) else Result.success(items)
        } catch (e: Exception) {
            Result.failure(CartParserException.ParseError(e.message ?: "parse error"))
        }
    }
}
