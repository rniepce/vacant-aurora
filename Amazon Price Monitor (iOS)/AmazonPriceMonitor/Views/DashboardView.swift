//
//  DashboardView.swift
//  Amazon Price Monitor
//

import SwiftUI
import UIKit

enum SortOption: CaseIterable {
    case biggestDrop
    case lowestPrice

    var titleKey: LocalizedStringKey {
        switch self {
        case .biggestDrop: return "Biggest Drop"
        case .lowestPrice: return "Lowest Price"
        }
    }
}

struct DashboardView: View {
    @Environment(PriceStore.self) private var store
    @Binding var showLogin: Bool
    @Binding var isLoggedIn: Bool
    @State private var sortOption: SortOption = .biggestDrop

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if store.isLoading {
                    Spacer()
                    ProgressView("Reading cart...")
                    Spacer()
                } else if store.items.isEmpty {
                    emptyStateView
                } else {
                    itemListView
                }
            }
        }
        .navigationTitle(Text(verbatim: "Radar de Preços"))
        .tint(.brandOrange)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoggedIn {
                    Menu {
                        Button {
                            showLogin = true
                        } label: {
                            Label("Amazon Login", systemImage: "person.crop.circle")
                        }
                        Button(role: .destructive, action: signOut) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Account")
                } else {
                    Button {
                        showLogin = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(Color(hex: "FF9900"))
                    }
                    .accessibilityLabel("Account")
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                } label: {
                    Label(sortOption.titleKey, systemImage: "arrow.up.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                .modifier(GlassStyle())

                Spacer()

                Button {
                    Task { await refreshCart() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .labelStyle(.titleAndIcon)
                .modifier(GlassProminentStyle())
                .tint(.brandOrange)
                .disabled(store.isLoading)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No items tracked", systemImage: "cart")
        } description: {
            VStack(spacing: 8) {
                Text(isLoggedIn ?
                     "Tap 'Refresh' to read your Amazon cart" :
                     "Log in to Amazon first, then refresh your cart"
                )
                if let error = store.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Item List

    private var itemListView: some View {
        List {
            if store.totalSavings > 0 {
                Section {
                    SavingsHeroCard(
                        totalSavings: store.totalSavings,
                        droppingCount: store.droppingCount,
                        totalCount: store.items.count
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            if let error = store.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                ForEach(sortedItems) { item in
                    NavigationLink {
                        ItemDetailView(item: item)
                    } label: {
                        ItemRowView(item: item)
                    }
                }
            } header: {
                Text(listHeaderText)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshCart()
        }
    }

    private var sortedItems: [CartItem] {
        switch sortOption {
        case .biggestDrop:
            return store.items.sorted { a, b in
                (a.priceChangePercent ?? 0) < (b.priceChangePercent ?? 0)
            }
        case .lowestPrice:
            return store.items.sorted { a, b in
                (a.currentPrice ?? .infinity) < (b.currentPrice ?? .infinity)
            }
        }
    }

    /// Section header: "Updated <when> · N items" — replaces the search-bar-shaped pill.
    private var listHeaderText: String {
        let itemsText = String(format: String(localized: "%lld items"), store.items.count)
        guard let date = store.lastUpdated else { return itemsText }
        let updated = String(format: String(localized: "Updated %@"),
                             date.formatted(.relative(presentation: .named)))
        return "\(updated) · \(itemsText)"
    }

    // MARK: - Actions

    @MainActor
    private func refreshCart() async {
        store.isLoading = true
        store.errorMessage = nil
        defer { store.isLoading = false }

        do {
            let items = try await CartParser.fetchCart()
            store.processNewItems(items)
            store.errorMessage = nil
            isLoggedIn = true
        } catch let error as CartParserError {
            store.errorMessage = error.localizedDescription
            if case .loginRequired = error {
                isLoggedIn = false
            }
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func signOut() {
        AmazonAuth.signOut {
            isLoggedIn = false
        }
    }
}

// MARK: - Item Row (Amazon-style within Liquid Glass)

struct ItemRowView: View {
    let item: CartItem

    var body: some View {
        HStack(spacing: 14) {
            // Product image
            if let urlString = item.imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        imagePlaceholder
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                imagePlaceholder
            }

            VStack(alignment: .leading, spacing: 5) {
                // Product title
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Price + change badge
                HStack(spacing: 8) {
                    if let price = item.currentPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("R$")
                                .font(.caption)
                            Text(price.priceValue)
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(.priceText)
                    }

                    if let change = item.priceChangePercent, abs(change) > 0.01 {
                        HStack(spacing: 3) {
                            Image(systemName: change < 0 ? "arrow.down" : "arrow.up")
                                .font(.system(size: 8, weight: .bold))
                            Text("\(String(format: "%.1f", abs(change)))%")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(change < 0 ? Color(hex: "007600") : Color(hex: "CC0C39"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            (change < 0 ? Color(hex: "007600") : Color(hex: "CC0C39")).opacity(0.1)
                        )
                        .clipShape(Capsule())
                    }
                }

                // Lowest price ever recorded
                if let low = item.lowestPrice {
                    Text(verbatim: "\(String(localized: "Lowest")) · R$ \(low.priceValue)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var rowAccessibilityLabel: Text {
        var parts = [item.title]
        if let price = item.currentPrice {
            parts.append("R$ \(price.priceValue)")
        }
        if let change = item.priceChangePercent, abs(change) > 0.01 {
            let pct = String(format: "%.1f%%", abs(change))
            parts.append(change < 0
                ? String(localized: "Price fell \(pct)")
                : String(localized: "Price rose \(pct)"))
        }
        return Text(parts.joined(separator: ", "))
    }

    private var imagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
            Image(systemName: "shippingbox")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
        }
        .frame(width: 56, height: 56)
    }
}

// MARK: - Savings Hero

struct SavingsHeroCard: View {
    let totalSavings: Double
    let droppingCount: Int
    let totalCount: Int

    private let positive = Color(hex: "007600")

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tracked savings")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: "−R$")
                        .font(.title3.weight(.semibold))
                    Text(totalSavings.priceValue)
                        .font(.title2.weight(.bold))
                }
                .foregroundStyle(positive)

                Text(String(format: String(localized: "%1$lld of %2$lld dropping"),
                            droppingCount, totalCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 34))
                .foregroundStyle(positive.opacity(0.45))
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Glass Button Style Helpers

struct GlassProminentStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

struct GlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

// MARK: - Color Extension

extension ShapeStyle where Self == Color {
    /// Bright Amazon-style orange — used for tints, buttons, and chart strokes,
    /// i.e. on filled/glass surfaces where text contrast is not the concern.
    static var brandOrange: Color { Color(hex: "FF9900") }

    /// Orange used for price *text*. The bright brand orange on a plain background
    /// only reaches ~1.9:1 contrast (fails WCAG AA), so this darkens it in light mode
    /// and brightens it in dark mode — legible text that still reads as the brand.
    static var priceText: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1) // #FBBF24
                : UIColor(red: 0.706, green: 0.325, blue: 0.035, alpha: 1) // #B45309
        })
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
