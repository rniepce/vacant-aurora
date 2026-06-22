//
//  AmazonPriceMonitorApp.swift
//  Amazon Price Monitor
//

import SwiftUI

@main
struct AmazonPriceMonitorApp: App {
    @State private var priceStore = PriceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(priceStore)
                .onAppear {
                    #if DEBUG
                    if CommandLine.arguments.contains("-demoMode") {
                        MainActor.assumeIsolated {
                            priceStore.populateWithDemoData()
                        }
                    }
                    #endif
                }
        }
    }
}
