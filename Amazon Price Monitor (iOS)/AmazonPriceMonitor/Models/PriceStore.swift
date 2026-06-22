//
//  PriceStore.swift
//  Amazon Price Monitor
//

import Foundation
import Observation

@MainActor
@Observable
class PriceStore {
    var items: [CartItem] = []
    var isLoading = false
    var lastUpdated: Date?
    var errorMessage: String?

    private let storageKey = "amazon_price_data"
    private let lastUpdatedKey = "amazon_last_updated"

    /// Single reusable formatter (creating one per loop iteration is expensive).
    private static let iso = ISO8601DateFormatter()

    init() {
        load()
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            errorMessage = String(localized: "Could not save data.")
        }
        if let date = lastUpdated {
            UserDefaults.standard.set(date, forKey: lastUpdatedKey)
        }
    }

    func load() {
        lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            items = try JSONDecoder().decode([CartItem].self, from: data)
        } catch {
            // Don't wipe anything silently — surface the problem instead.
            errorMessage = String(localized: "Could not load saved data.")
        }
    }

    // MARK: - Process New Items

    func processNewItems(_ currentItems: [(id: String, title: String, price: Double, imageURL: String?)]) {
        var nextItems: [CartItem] = []
        let now = Date()

        for item in currentItems {
            // Find existing item to preserve history
            let existing = items.first(where: { $0.id == item.id })
            var history = existing?.history ?? []

            // Sanitize: keep only plausible prices
            history = history.filter { $0.price > 10 }

            let lastEntry = history.last

            // Anomaly detection: if price increased > 200%, reset history
            if let last = lastEntry, last.price > 0 {
                let increase = (item.price - last.price) / last.price * 100
                if increase > 200 {
                    history = []
                }
            }

            // Add a new entry unless we already recorded this exact price today
            let newEntry = PriceEntry(date: Self.iso.string(from: now), price: item.price)
            let lastDate = lastEntry.flatMap { Self.iso.date(from: $0.date) }
            let sameDay = lastDate.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false

            if lastEntry == nil || lastEntry?.price != item.price || !sameDay {
                history.append(newEntry)
            }

            // Limit history to the most recent 30 entries
            if history.count > 30 {
                history = Array(history.suffix(30))
            }

            nextItems.append(CartItem(id: item.id, title: item.title, imageURL: item.imageURL, history: history))
        }

        items = nextItems
        lastUpdated = now
        save()
    }

    // MARK: - Demo Data (screenshots / `-demoMode` launch argument)

    func populateWithDemoData() {
        let demoItems: [CartItem] = [
            CartItem(id: "B0CHX6BKK5", title: "Apple iPhone 15 Pro (256 GB) - Titânio Natural", imageURL: "https://m.media-amazon.com/images/I/41lRlXsSGsL._AC_SY200_.jpg", history: [
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 5)), price: 9299.00),
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 2)), price: 8999.00),
                PriceEntry(date: Self.iso.string(from: Date()), price: 8799.00)
            ]),
            CartItem(id: "B09DFCB66S", title: "Console PlayStation 5", imageURL: "https://m.media-amazon.com/images/I/51mWHXY8hyL._AC_SY200_.jpg", history: [
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 7)), price: 4499.00),
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 3)), price: 4199.00),
                PriceEntry(date: Self.iso.string(from: Date()), price: 3999.00)
            ]),
            CartItem(id: "B09V3HBW8Q", title: "Kindle Paperwhite 16 GB - Tela de 6,8\", temperatura de luz ajustável", imageURL: "https://m.media-amazon.com/images/I/41QYyFRGqWL._AC_SY200_.jpg", history: [
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 10)), price: 799.00),
                PriceEntry(date: Self.iso.string(from: Date()), price: 799.00)
            ]),
            CartItem(id: "B084J4WGV9", title: "Echo Dot (4ª Geração): Smart Speaker com Alexa - Cor Preta", imageURL: "https://m.media-amazon.com/images/I/51PBiByf5bL._AC_SY200_.jpg", history: [
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 15)), price: 399.00),
                PriceEntry(date: Self.iso.string(from: Date().addingTimeInterval(-86400 * 5)), price: 299.00),
                PriceEntry(date: Self.iso.string(from: Date()), price: 349.00)
            ])
        ]
        self.items = demoItems
        self.lastUpdated = Date()
    }
}
