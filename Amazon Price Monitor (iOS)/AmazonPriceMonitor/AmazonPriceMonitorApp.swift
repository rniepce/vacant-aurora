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
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
            print("Notifications granted: \(granted)")
        }
    }
}
