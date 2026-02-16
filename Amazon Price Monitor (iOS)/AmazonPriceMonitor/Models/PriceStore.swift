//
//  PriceStore.swift
//  Amazon Price Monitor
//

import Foundation
import UserNotifications
import Observation

@Observable
class PriceStore {
    var items: [CartItem] = []
    var isLoading = false
    var lastUpdated: Date?
    var errorMessage: String?

    private let storageKey = "amazon_price_data"
    private let lastUpdatedKey = "amazon_last_updated"

    // Config
    var notifyMethod: String = "percentage" // "percentage" or "absolute"
    var notifyValue: Double = 10

    init() {
        load()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        if let date = lastUpdated {
            UserDefaults.standard.set(date, forKey: lastUpdatedKey)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CartItem].self, from: data) {
            items = decoded
        }
        lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    // MARK: - Process New Items (ported from background.js processItems)

    func processNewItems(_ currentItems: [(id: String, title: String, price: Double)]) {
        var nextItems: [CartItem] = []

        for item in currentItems {
            // Find existing item to preserve history
            let existing = items.first(where: { $0.id == item.id })
            var history = existing?.history ?? []

            // Sanitize: keep only prices > 10
            history = history.filter { $0.price > 10 }

            let lastEntry = history.last

            // Anomaly detection: if price increased > 200%, reset history
            if let last = lastEntry {
                let increase = (item.price - last.price) / last.price * 100
                if increase > 200 {
                    print("Anomaly for \(item.id): +\(Int(increase))%. Resetting history.")
                    history = []
                }
            }

            // Notification logic
            if let lastSafe = history.last, lastSafe.price > 10 {
                let oldPrice = lastSafe.price
                let priceDiff = oldPrice - item.price

                var shouldNotify = false
                if notifyMethod == "percentage" {
                    if (priceDiff / oldPrice) * 100 >= notifyValue { shouldNotify = true }
                } else {
                    if priceDiff >= notifyValue { shouldNotify = true }
                }

                if shouldNotify && priceDiff > 0 {
                    sendNotification(title: item.title, oldPrice: oldPrice, newPrice: item.price)
                }
            }

            // Add new entry
            let newEntry = PriceEntry(
                date: ISO8601DateFormatter().string(from: Date()),
                price: item.price
            )

            let lastDate = lastEntry.flatMap { entry -> String? in
                let formatter = ISO8601DateFormatter()
                return formatter.date(from: entry.date).map {
                    DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .none)
                }
            }
            let currentDate = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)

            if lastEntry == nil || lastEntry?.price != item.price || lastDate != currentDate {
                history.append(newEntry)
            }

            // Limit history to 30 entries
            if history.count > 30 {
                history.removeFirst()
            }

            nextItems.append(CartItem(id: item.id, title: item.title, history: history))
        }

        print("Sync complete. Storing \(nextItems.count) items (was \(items.count)).")
        items = nextItems
        lastUpdated = Date()
        save()
    }

    // MARK: - Import from Chrome Extension JSON

    func importFromJSON(_ data: Data) throws -> Int {
        // Chrome extension format: { "ASIN": { "title": "...", "history": [{ "date": "...", "price": 123 }] } }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }

        var importedCount = 0

        for (asin, value) in json {
            guard let dict = value as? [String: Any],
                  let title = dict["title"] as? String,
                  let historyArray = dict["history"] as? [[String: Any]] else {
                continue
            }

            let history: [PriceEntry] = historyArray.compactMap { entry in
                guard let date = entry["date"] as? String,
                      let price = entry["price"] as? Double,
                      price > 10 else { return nil }
                return PriceEntry(date: date, price: price)
            }

            guard !history.isEmpty else { continue }

            // Merge: if item already exists, prepend imported history before existing
            if let existingIndex = items.firstIndex(where: { $0.id == asin }) {
                let existingDates = Set(items[existingIndex].history.map(\.date))
                let newEntries = history.filter { !existingDates.contains($0.date) }
                items[existingIndex].history = newEntries + items[existingIndex].history
                // Sort by date
                items[existingIndex].history.sort { $0.date < $1.date }
            } else {
                items.append(CartItem(id: asin, title: title, history: history))
            }
            importedCount += 1
        }

        save()
        return importedCount
    }

    enum ImportError: Error, LocalizedError {
        case invalidFormat
        var errorDescription: String? {
            "Formato de arquivo inválido. Use o JSON exportado pela extensão Chrome."
        }
    }

    // MARK: - Notifications

    private func sendNotification(title: String, oldPrice: Double, newPrice: Double) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Queda de Preço!"
        let shortTitle = title.count > 40 ? String(title.prefix(37)) + "..." : title
        content.body = "\(shortTitle) caiu de R$ \(String(format: "%.2f", oldPrice)) para R$ \(String(format: "%.2f", newPrice))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
}
