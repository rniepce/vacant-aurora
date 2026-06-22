//
//  DashboardView.swift
//  Amazon Price Monitor
//

import SwiftUI

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
        .navigationTitle("Price Monitor")
        .tint(Color(hex: "FF9900"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showLogin = true
                } label: {
                    Image(systemName: isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(isLoggedIn ? Color(hex: "4CAF50") : Color(hex: "FF9900"))
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Task { await refreshCart() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .modifier(GlassProminentStyle())
                .tint(Color(hex: "FF9900"))
                .disabled(store.isLoading)

                Spacer()

                Menu {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.titleKey).tag(option)
                        }
                    }
                } label: {
                    Label(sortOption.titleKey, systemImage: "arrow.up.arrow.down")
                }
                .modifier(GlassStyle())
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No items tracked", systemImage: "cart")
        } description: {
            Text(isLoggedIn ?
                 "Tap 'Refresh' to read your Amazon cart" :
                 "Log in to Amazon first, then refresh your cart"
            )
        }
    }

    // MARK: - Item List

    private var itemListView: some View {
        List {
            if let error = store.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let date = store.lastUpdated {
                Section {
                    Label {
                        Text(String(format: String(localized: "Updated %@"),
                                    date.formatted(.relative(presentation: .named))))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(Color(hex: "FF9900"))
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
            }

            Spacer(minLength: 0)

            // Trend indicator
            Circle()
                .fill(trendColor)
                .frame(width: 8, height: 8)
                .shadow(color: trendColor.opacity(0.5), radius: 3)
        }
        .padding(.vertical, 4)
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

    private var trendColor: Color {
        switch item.trend {
        case .down: return Color(hex: "007600")
        case .up: return Color(hex: "CC0C39")
        case .stable: return Color(hex: "E0A800")
        }
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
