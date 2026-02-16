//
//  LoginView.swift
//  Amazon Price Monitor
//

import SwiftUI
import WebKit

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var showLogin: Bool
    @State private var currentURL: String = "amazon.com.br"
    @State private var isLoading = true

    private let amazonURL = URL(string: "https://www.amazon.com.br/ap/signin?openid.pape.max_auth_age=0&openid.return_to=https%3A%2F%2Fwww.amazon.com.br%2Fgp%2Fcart%2Fview.html&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.assoc_handle=brflex&openid.mode=checkid_setup&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0")!

    var body: some View {
        NavigationStack {
            ZStack {
                // WebView
                AmazonWebView(
                    url: amazonURL,
                    onNavigationFinished: { webView, url in
                        if let urlString = url?.absoluteString {
                            currentURL = urlString
                                .replacingOccurrences(of: "https://www.", with: "")
                                .replacingOccurrences(of: "https://", with: "")

                            // Detect successful login
                            if !urlString.contains("signin") && !urlString.contains("ap/signin") {
                                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                                    let hasAuth = cookies.contains { $0.domain.contains("amazon.com.br") && ($0.name == "at-main" || $0.name == "session-id") }
                                    DispatchQueue.main.async {
                                        if hasAuth {
                                            isLoggedIn = true
                                        }
                                    }
                                }
                            }
                        }
                        isLoading = false
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ZStack {
                        Color(.systemBackground).opacity(0.6)
                            .ignoresSafeArea()
                        ProgressView("Carregando...")
                            .tint(Color(hex: "FF9900"))
                    }
                }
            }
            .navigationTitle("Login Amazon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(currentURL)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pronto") {
                        showLogin = false
                    }
                    .modifier(GlassProminentStyle())
                    .tint(Color(hex: "FF9900"))
                }
            }
        }
    }
}
