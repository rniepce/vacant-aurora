//
//  AmazonWebView.swift
//  Amazon Price Monitor
//

import SwiftUI
import WebKit

struct AmazonWebView: UIViewRepresentable {
    /// Shared mobile Safari user agent so Amazon serves the same markup to login and cart scraping.
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    let url: URL
    var onNavigationFinished: ((WKWebView, URL?) -> Void)?
    var webViewRef: ((WKWebView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigationFinished: onNavigationFinished)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Persists cookies across launches

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = AmazonWebView.userAgent

        // Allow back/forward swipe
        webView.allowsBackForwardNavigationGestures = true

        webViewRef?(webView)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op: we don't reload on updates
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var onNavigationFinished: ((WKWebView, URL?) -> Void)?

        init(onNavigationFinished: ((WKWebView, URL?) -> Void)?) {
            self.onNavigationFinished = onNavigationFinished
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onNavigationFinished?(webView, webView.url)
        }
    }
}
