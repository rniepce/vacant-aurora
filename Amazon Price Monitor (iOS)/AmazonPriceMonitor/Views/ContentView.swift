//
//  ContentView.swift
//  Amazon Price Monitor
//

import SwiftUI
import WebKit

struct ContentView: View {
    @Environment(PriceStore.self) private var store
    @State private var showLogin = false
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            DashboardView(showLogin: $showLogin, isLoggedIn: $isLoggedIn)
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(isLoggedIn: $isLoggedIn, showLogin: $showLogin)
        }
        .onAppear {
            // Check if we have cookies (approximate login check)
            checkLoginStatus()
        }
    }

    private func checkLoginStatus() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let amazonCookies = cookies.filter { $0.domain.contains("amazon.com.br") }
            let hasSession = amazonCookies.contains { $0.name == "session-id" || $0.name == "at-main" }
            DispatchQueue.main.async {
                isLoggedIn = hasSession
            }
        }
    }
}
