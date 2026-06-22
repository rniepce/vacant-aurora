//
//  CartParser.swift
//  Amazon Price Monitor
//

import WebKit

typealias CartScrapeItem = (id: String, title: String, price: Double, imageURL: String?)

enum CartParserError: Error, LocalizedError {
    case loginRequired
    case noItems
    case timeout
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .loginRequired:
            return String(localized: "You need to log in to Amazon first.")
        case .noItems:
            return String(localized: "No items found in the cart.")
        case .timeout:
            return String(localized: "Timed out reading the cart. Please try again.")
        case .parseError(let msg):
            return String(format: String(localized: "Error reading cart: %@"), msg)
        }
    }
}

enum CartParser {

    static let cartURL = URL(string: "https://www.amazon.com.br/gp/cart/view.html")!

    /// JavaScript that parses the Amazon cart HTML and returns a JSON array of items.
    static let parserScript = """
    (function() {
        function parseCurrency(str) {
            let clean = str.replace(/[^\\d.,]/g, '').trim();
            if (!clean) return null;
            if (clean.includes(',')) {
                clean = clean.replace(/\\./g, '');
                clean = clean.replace(',', '.');
            } else {
                clean = clean.replace(/\\./g, '');
            }
            const val = parseFloat(clean);
            return isNaN(val) ? null : val;
        }

        const title = document.querySelector('title')?.textContent || '';
        if (title.includes('Sign In') || title.includes('Fazer login') || title.includes('sign-in')) {
            return JSON.stringify({ error: 'login_required' });
        }

        const activeItems = Array.from(document.querySelectorAll('#sc-active-cart .sc-list-item[data-asin]'));
        const savedItems = Array.from(document.querySelectorAll('#sc-saved-cart .sc-list-item[data-asin], #sc-secondary-list .sc-list-item[data-asin]'));
        let itemElements = [...activeItems, ...savedItems];

        if (itemElements.length === 0) {
            itemElements = Array.from(document.querySelectorAll('.sc-list-item[data-asin]'));
        }
        if (itemElements.length === 0) {
            itemElements = Array.from(document.querySelectorAll('.sc-list-item'));
        }

        const results = [];
        const invalidTerms = ['economize', 'save', 'poupe', 'desconto', 'de:', 'was:', 'recomendado'];

        itemElements.forEach(el => {
            const asin = el.getAttribute('data-asin');
            if (!asin) return;

            let title = 'Unknown Product';
            const titleSelectors = ['.sc-product-title', '.a-truncate-full', '.sc-grid-item-product-title', 'span.a-list-item a.a-link-normal span'];
            for (const sel of titleSelectors) {
                const tEl = el.querySelector(sel);
                if (tEl) { title = tEl.textContent.trim(); break; }
            }

            // Extract product image URL
            let imageURL = '';
            const imgSelectors = ['.sc-product-image img', '.sc-item-image img', 'img[alt]', 'img'];
            for (const sel of imgSelectors) {
                const imgEl = el.querySelector(sel);
                if (imgEl && imgEl.src && !imgEl.src.includes('transparent-pixel') && !imgEl.src.includes('spacer')) {
                    imageURL = imgEl.src;
                    break;
                }
            }

            let priceRaw = '';
            const priceSelectors = ['.sc-product-price', '.sc-price', '.a-offscreen', '.a-color-price', 'span[id^="sc-subtotal-amount-buybox"]'];

            for (const sel of priceSelectors) {
                const candidates = el.querySelectorAll(sel);
                for (const pEl of candidates) {
                    if (pEl.classList.contains('a-text-strike') || pEl.closest('.a-text-strike')) continue;
                    const text = pEl.textContent.trim();
                    const textLower = text.toLowerCase();
                    if (invalidTerms.some(term => textLower.includes(term))) continue;
                    if (pEl.parentElement) {
                        const parentText = pEl.parentElement.textContent.toLowerCase();
                        if (parentText.length < 50 && invalidTerms.some(term => parentText.includes(term))) continue;
                    }
                    if (/R\\$\\s?[\\d.,]+/.test(text)) { priceRaw = text; break; }
                }
                if (priceRaw) break;
            }

            if (!priceRaw) {
                const text = el.innerText || '';
                const matches = [...text.matchAll(/R\\$\\s?[\\d.,]+/g)];
                for (const m of matches) {
                    const valStr = m[0];
                    const index = m.index;
                    const prefix = text.substring(Math.max(0, index - 20), index).toLowerCase();
                    if (invalidTerms.some(term => prefix.includes(term))) continue;
                    priceRaw = valStr;
                    break;
                }
            }

            if (priceRaw) {
                const priceVal = parseCurrency(priceRaw);
                if (priceVal !== null && priceVal > 10) {
                    results.push({ id: asin, title: title, price: priceVal, imageURL: imageURL || null });
                }
            }
        });

        return JSON.stringify({ items: results });
    })();
    """

    /// Fetches and parses the cart using a hidden WKWebView.
    @MainActor
    static func fetchCart() async throws -> [CartScrapeItem] {
        try await withCheckedThrowingContinuation { continuation in
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default() // Uses same cookies as the login web view

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.customUserAgent = AmazonWebView.userAgent

            // The delegate keeps the web view alive and resumes the continuation exactly once.
            let delegate = CartParserDelegate(webView: webView) { result in
                continuation.resume(with: result)
            }
            webView.navigationDelegate = delegate
            // Retain the delegate for the lifetime of the web view (navigationDelegate is weak).
            objc_setAssociatedObject(webView, &CartParserDelegate.assocKey, delegate, .OBJC_ASSOCIATION_RETAIN)

            let request = URLRequest(url: cartURL, cachePolicy: .reloadIgnoringLocalCacheData)
            webView.load(request)
        }
    }
}

private final class CartParserDelegate: NSObject, WKNavigationDelegate {
    static var assocKey: UInt8 = 0

    private let webView: WKWebView
    private let completion: (Result<[CartScrapeItem], CartParserError>) -> Void
    private var hasCompleted = false
    private var watchdog: Timer?

    init(webView: WKWebView, completion: @escaping (Result<[CartScrapeItem], CartParserError>) -> Void) {
        self.webView = webView
        self.completion = completion
        super.init()
        // Guarantee we always finish, even if the page never loads (captcha, hang, redirect loop).
        watchdog = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) { [weak self] _ in
            self?.finish(.failure(.timeout))
        }
    }

    /// Completes exactly once and fully tears down the web view, breaking the
    /// web view <-> delegate retain cycle so neither leaks.
    private func finish(_ result: Result<[CartScrapeItem], CartParserError>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        watchdog?.invalidate()
        watchdog = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        objc_setAssociatedObject(webView, &CartParserDelegate.assocKey, nil, .OBJC_ASSOCIATION_RETAIN)
        completion(result)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        // Detect a redirect to the sign-in page.
        if let url = webView.url?.absoluteString,
           url.contains("signin") || url.contains("ap/signin") {
            finish(.failure(.loginRequired))
            return
        }

        // Give dynamic content a moment to render, then inject the parser.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !self.hasCompleted else { return }

            webView.evaluateJavaScript(CartParser.parserScript) { [weak self] result, error in
                guard let self else { return }

                if let error {
                    self.finish(.failure(.parseError(error.localizedDescription)))
                    return
                }

                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8) else {
                    self.finish(.failure(.parseError(String(localized: "Invalid response"))))
                    return
                }

                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.finish(.failure(.noItems))
                        return
                    }
                    if json["error"] != nil {
                        self.finish(.failure(.loginRequired))
                        return
                    }
                    guard let itemsArray = json["items"] as? [[String: Any]] else {
                        self.finish(.failure(.noItems))
                        return
                    }

                    let items: [CartScrapeItem] = itemsArray.compactMap { dict in
                        guard let id = dict["id"] as? String,
                              let title = dict["title"] as? String,
                              let price = dict["price"] as? Double else { return nil }
                        return (id: id, title: title, price: price, imageURL: dict["imageURL"] as? String)
                    }

                    self.finish(items.isEmpty ? .failure(.noItems) : .success(items))
                } catch {
                    self.finish(.failure(.parseError(error.localizedDescription)))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(.parseError(error.localizedDescription)))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(.parseError(error.localizedDescription)))
    }
}

// MARK: - Amazon login state

enum AmazonAuth {
    /// Considers the user logged in only when a real auth cookie is present.
    /// `session-id` alone is set for anonymous sessions, so it is intentionally ignored.
    static func isLoggedIn(_ completion: @escaping (Bool) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let loggedIn = cookies.contains { cookie in
                cookie.domain.hasSuffix("amazon.com.br")
                    && (cookie.name == "at-main" || cookie.name == "sess-at-main")
            }
            DispatchQueue.main.async { completion(loggedIn) }
        }
    }

    /// Clears the Amazon web session (cookies, caches, local storage) used by the
    /// login and cart web views, so the next refresh requires signing in again.
    /// Locally stored price history is left untouched.
    static func signOut(_ completion: @escaping () -> Void) {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            let amazonRecords = records.filter { $0.displayName.contains("amazon") }
            store.removeData(ofTypes: types, for: amazonRecords) {
                DispatchQueue.main.async { completion() }
            }
        }
    }
}
