package com.vacantaurora.pricemonitor.ui

import android.annotation.SuppressLint
import android.webkit.CookieManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.viewinterop.AndroidView
import com.vacantaurora.pricemonitor.R
import com.vacantaurora.pricemonitor.data.CartParser

/**
 * Hosts an in-app WebView pointed at Amazon's sign-in page. Cookies persist in the
 * app-wide [CookieManager], so [CartParser]'s hidden WebView reuses the session.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(onDone: () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.login_title)) },
                actions = {
                    IconButton(onClick = onDone) {
                        Icon(Icons.Default.Check, contentDescription = stringResource(R.string.done))
                    }
                },
            )
        },
    ) { padding ->
        AndroidView(
            modifier = Modifier.fillMaxSize().padding(padding),
            factory = { context ->
                @SuppressLint("SetJavaScriptEnabled")
                WebView(context).apply {
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.userAgentString = CartParser.USER_AGENT
                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)
                    webViewClient = WebViewClient()
                    loadUrl(CartParser.SIGNIN_URL)
                }
            },
        )
    }
}
