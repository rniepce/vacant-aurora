//
//  CartParser.swift
//  Amazon Price Monitor
//

import WebKit

class CartParser {

    static let cartURL = URL(string: "https://www.amazon.com.br/gp/cart/view.html")!

    /// JavaScript that parses the Amazon cart HTML and returns JSON array of items.
    /// Ported from offscreen.js parseCart() and parseCurrency() functions.
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

            let title = 'Produto Desconhecido';
            const titleSelectors = ['.sc-product-title', '.a-truncate-full', '.sc-grid-item-product-title', 'span.a-list-item a.a-link-normal span'];
            for (const sel of titleSelectors) {
                const tEl = el.querySelector(sel);
                if (tEl) { title = tEl.textContent.trim(); break; }
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
                    results.push({ id: asin, title: title, price: priceVal });
                }
            }
        });

        return JSON.stringify({ items: results });
    })();
    """

    /// Fetches and parses the cart using a hidden WKWebView
    static func fetchCart(completion: @escaping (Result<[(id: String, title: String, price: Double)], CartParserError>) -> Void) {
        DispatchQueue.main.async {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default() // Uses same cookies as login webview

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

            let delegate = CartParserDelegate(webView: webView, completion: completion)
            webView.navigationDelegate = delegate

            // We need to retain the delegate
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

            let request = URLRequest(url: cartURL, cachePolicy: .reloadIgnoringLocalCacheData)
            webView.load(request)
        }
    }
}

enum CartParserError: Error, LocalizedError {
    case loginRequired
    case noItems
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .loginRequired: return "Você precisa fazer login na Amazon primeiro."
        case .noItems: return "Nenhum item encontrado no carrinho."
        case .parseError(let msg): return "Erro ao ler carrinho: \(msg)"
        }
    }
}

private class CartParserDelegate: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let completion: (Result<[(id: String, title: String, price: Double)], CartParserError>) -> Void
    var hasCompleted = false

    init(webView: WKWebView, completion: @escaping (Result<[(id: String, title: String, price: Double)], CartParserError>) -> Void) {
        self.webView = webView
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasCompleted else { return }

        // Check if we were redirected to login
        if let url = webView.url?.absoluteString,
           (url.contains("signin") || url.contains("ap/signin")) {
            hasCompleted = true
            completion(.failure(.loginRequired))
            return
        }

        // Wait a moment for dynamic content to load, then inject parser
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self, !self.hasCompleted else { return }

            webView.evaluateJavaScript(CartParser.parserScript) { result, error in
                self.hasCompleted = true

                if let error = error {
                    self.completion(.failure(.parseError(error.localizedDescription)))
                    return
                }

                guard let jsonString = result as? String,
                      let data = jsonString.data(using: .utf8) else {
                    self.completion(.failure(.parseError("Invalid response")))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let _ = json["error"] as? String {
                            self.completion(.failure(.loginRequired))
                            return
                        }

                        if let itemsArray = json["items"] as? [[String: Any]] {
                            let items = itemsArray.compactMap { dict -> (id: String, title: String, price: Double)? in
                                guard let id = dict["id"] as? String,
                                      let title = dict["title"] as? String,
                                      let price = dict["price"] as? Double else { return nil }
                                return (id: id, title: title, price: price)
                            }

                            if items.isEmpty {
                                self.completion(.failure(.noItems))
                            } else {
                                self.completion(.success(items))
                            }
                        } else {
                            self.completion(.failure(.noItems))
                        }
                    }
                } catch {
                    self.completion(.failure(.parseError(error.localizedDescription)))
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(.failure(.parseError(error.localizedDescription)))
    }
}
