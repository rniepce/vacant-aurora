//
//  CartItem.swift
//  Amazon Price Monitor
//

import Foundation

struct PriceEntry: Codable, Identifiable {
    var id: String { date }
    let date: String
    let price: Double
}

struct CartItem: Codable, Identifiable {
    let id: String // ASIN
    var title: String
    var history: [PriceEntry]

    var currentPrice: Double? {
        history.last?.price
    }

    var lowestPrice: Double? {
        history.map(\.price).min()
    }

    var highestPrice: Double? {
        history.map(\.price).max()
    }

    var priceChangePercent: Double? {
        guard history.count >= 2,
              let first = history.first?.price,
              let last = history.last?.price,
              first > 0 else { return nil }
        return ((last - first) / first) * 100
    }

    enum Trend {
        case up, down, stable
    }

    var trend: Trend {
        guard let change = priceChangePercent else { return .stable }
        if change < -0.01 { return .down }
        if change > 0.01 { return .up }
        return .stable
    }
}
