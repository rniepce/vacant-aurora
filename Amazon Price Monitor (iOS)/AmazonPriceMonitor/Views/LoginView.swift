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
    /// Whether the user was already logged in when this sheet opened. Used so we
    /// auto-dismiss only on a *fresh* login, not when they reopen it to view the account.
    @State private var initiallyLoggedIn = false

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

                            // Detect a successful login once we've left the sign-in flow.
                            if !urlString.contains("signin") && !urlString.contains("ap/signin") {
                                AmazonAuth.isLoggedIn { loggedIn in
                                    guard loggedIn else { return }
                                    let isFreshLogin = !initiallyLoggedIn
                                    isLoggedIn = true
                                    // On a brand-new login, close the sheet right away. The
                                    // dashboard observes isLoggedIn and loads the cart itself,
                                    // so the user never has to tap Refresh after signing in.
                                    if isFreshLogin { showLogin = false }
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
                        ProgressView("Loading...")
                            .tint(Color(hex: "FF9900"))
                    }
                }
            }
            .navigationTitle("Amazon Login")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { initiallyLoggedIn = isLoggedIn }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(currentURL)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showLogin = false
                    }
                    .modifier(GlassProminentStyle())
                    .tint(Color(hex: "FF9900"))
                }
            }
        }
    }
}
