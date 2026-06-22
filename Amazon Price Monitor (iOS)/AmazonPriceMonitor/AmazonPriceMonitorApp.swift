//
//  AmazonPriceMonitorApp.swift
//  Amazon Price Monitor
//

import SwiftUI
import UserNotifications

@main
struct AmazonPriceMonitorApp: App {
    @State private var priceStore = PriceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(priceStore)
                .onAppear {
                    requestNotificationPermission()
                    if CommandLine.arguments.contains("-demoMode") {
                        MainActor.assumeIsolated {
                            priceStore.populateWithDemoData()
                        }
                    }
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
