//
//  DashboardView.swift
//  Amazon Price Monitor
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

enum SortOption: String, CaseIterable {
    case biggestDrop = "Maior Queda"
    case lowestPrice = "Menor Preço"
}

struct DashboardView: View {
    @Environment(PriceStore.self) private var store
    @Binding var showLogin: Bool
    @Binding var isLoggedIn: Bool
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var sortOption: SortOption = .biggestDrop

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if store.isLoading {
                    Spacer()
                    ProgressView("Lendo carrinho...")
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showLogin = true
                } label: {
                    Image(systemName: isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle.badge.exclamationmark")
                        .foregroundStyle(isLoggedIn ? Color(hex: "4CAF50") : Color(hex: "FF9900"))
                }
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    refreshCart()
                } label: {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .modifier(GlassProminentStyle())
                .tint(Color(hex: "FF9900"))
                .disabled(store.isLoading)

                Spacer()

                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            Label(option.rawValue, systemImage: sortOption == option ? "checkmark" : "")
                        }
                    }
                } label: {
                    Label(sortOption.rawValue, systemImage: "arrow.up.arrow.down")
                }
                .modifier(GlassStyle())
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                guard url.startAccessingSecurityScopedResource() else {
                    importMessage = "Sem permissão para acessar arquivo."
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: url)
                    let count = try store.importFromJSON(data)
                    importMessage = "✅ \(count) itens importados!"
                } catch {
                    importMessage = "❌ \(error.localizedDescription)"
                }
            case .failure(let error):
                importMessage = "❌ \(error.localizedDescription)"
            }
        }
        .alert("Importação", isPresented: .init(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Nenhum item rastreado", systemImage: "cart")
        } description: {
            Text(isLoggedIn ?
                 "Toque em \"Atualizar\" para ler seu carrinho da Amazon" :
                 "Faça login na Amazon primeiro, depois atualize seu carrinho"
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
                    Label("Atualizado \(date.formatted(.relative(presentation: .named)))", systemImage: "clock")
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
            await refreshCartAsync()
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

    private func refreshCart() {
        store.isLoading = true
        store.errorMessage = nil

        CartParser.fetchCart { result in
            DispatchQueue.main.async {
                store.isLoading = false
                switch result {
                case .success(let items):
                    store.processNewItems(items)
                    store.errorMessage = nil
                    isLoggedIn = true
                case .failure(let error):
                    store.errorMessage = error.localizedDescription
                    if case .loginRequired = error {
                        isLoggedIn = false
                    }
                }
            }
        }
    }

    private func refreshCartAsync() async {
        await withCheckedContinuation { continuation in
            CartParser.fetchCart { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let items):
                        store.processNewItems(items)
                        store.errorMessage = nil
                        isLoggedIn = true
                    case .failure(let error):
                        store.errorMessage = error.localizedDescription
                        if case .loginRequired = error {
                            isLoggedIn = false
                        }
                    }
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Item Row (Amazon-style within Liquid Glass)

struct ItemRowView: View {
    let item: CartItem

    var body: some View {
        HStack(spacing: 14) {
            // Product image placeholder with glass feel
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                Image(systemName: "shippingbox")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)

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
                            Text(String(format: "%.2f", price))
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
