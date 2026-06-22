//
//  ContentView.swift
//  Amazon Price Monitor
//

import SwiftUI

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
            AmazonAuth.isLoggedIn { loggedIn in
                isLoggedIn = loggedIn
            }
        }
    }
}
