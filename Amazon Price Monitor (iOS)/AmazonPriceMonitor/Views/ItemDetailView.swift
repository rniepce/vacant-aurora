//
//  ItemDetailView.swift
//  Amazon Price Monitor
//

import SwiftUI
import Charts

struct ItemDetailView: View {
    let item: CartItem

    private var amazonURL: URL? {
        URL(string: "https://www.amazon.com.br/dp/\(item.id)")
    }

    var body: some View {
        List {
            // Stats Cards
            Section {
                HStack(spacing: 12) {
                    StatCard(label: "Current", value: formatPrice(item.currentPrice), color: Color(hex: "FF9900"))
                    StatCard(label: "Lowest", value: formatPrice(item.lowestPrice), color: Color(hex: "007600"))
                    StatCard(label: "Highest", value: formatPrice(item.highestPrice), color: Color(hex: "CC0C39"))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Discount badge
            if let change = item.priceChangePercent, abs(change) > 0.01 {
                Section {
                    HStack(spacing: 6) {
                        Image(systemName: change < 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                            .foregroundStyle(change < 0 ? Color(hex: "007600") : Color(hex: "CC0C39"))
                        Text(String(format: String(localized: "%@ since first record"),
                                    String(format: "%.1f%%", abs(change))))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(change < 0 ? Color(hex: "007600") : Color(hex: "CC0C39"))
                    }
                }
            }

            // Chart
            if item.history.count >= 2 {
                Section("Price History") {
                    chartView
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("Insufficient data", systemImage: "chart.line.uptrend.xyaxis")
                    } description: {
                        Text("At least 2 records are needed for the chart")
                    }
                }
            }

            // Price History List
            Section("Records") {
                ForEach(item.history.reversed()) { entry in
                    HStack {
                        if let date = parseDate(entry.date) {
                            Text(date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("R$")
                                .font(.caption)
                            Text(entry.price.priceValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color(hex: "FF9900"))
                    }
                }
            }

            // Amazon Link
            if let url = amazonURL {
                Section {
                    Link(destination: url) {
                        Label("View on Amazon", systemImage: "safari")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color(hex: "FF9900"))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.title.count > 30 ? String(item.title.prefix(27)) + "..." : item.title)
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color(hex: "FF9900"))
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(item.history) { entry in
                if let date = parseDate(entry.date) {
                    AreaMark(
                        x: .value("Date", date),
                        y: .value("Price", entry.price)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "FF9900").opacity(0.2), Color(hex: "FF9900").opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", date),
                        y: .value("Price", entry.price)
                    )
                    .foregroundStyle(Color(hex: "FF9900"))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", date),
                        y: .value("Price", entry.price)
                    )
                    .foregroundStyle(Color(hex: "FF9900"))
                    .symbolSize(24)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text("R$" + price.formatted(.number.precision(.fractionLength(0))))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(.quaternary)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 200)
    }

    // MARK: - Helpers

    private func formatPrice(_ price: Double?) -> String {
        guard let price else { return "—" }
        return "R$ \(price.priceValue)"
    }

    private func parseDate(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let label: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
