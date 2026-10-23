import SwiftUI

/// TODD Market's public network search (functions/market, shop.routes.js).
private let marketBase = "https://market.taliferro.tech"

/// A product an independent store in the Market network sells.
struct MarketItem: Codable, Hashable {
    let id: String
    let title: String
    let priceCents: Int?
    let image: String?
    let storeName: String
    let storeSlug: String
}

/// A product from a shop Market has listed but that hasn't joined (Market's "Not on TODD Market yet").
struct MarketListingItem: Codable, Hashable {
    let id: String
    let title: String
    let priceCents: Int?
    let image: String?
    let url: String
    let storeName: String
}

private struct MarketSearchResponse: Decodable {
    let items: [MarketItem]?
    let listingItems: [MarketListingItem]?
}

/// What the strip shows for one query: member-store items, or (only when
/// there are none) listed shops' products.
struct MarketStripContent: Hashable {
    var items: [MarketItem] = []
    var total = 0
    var listings: [MarketListingItem] = []
}

/// Fetches once per query so every page of a result shares one request.
@MainActor
final class MarketStripLoader {
    static let shared = MarketStripLoader()
    private var cache: [String: MarketStripContent] = [:]

    func content(for query: String) async -> MarketStripContent {
        if let cached = cache[query] { return cached }
        guard let url = URL(string: "\(marketBase)/api/network/search") else { return MarketStripContent() }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query, "lite": true])

        var content = MarketStripContent()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return content }
            let body = try JSONDecoder().decode(MarketSearchResponse.self, from: data)
            // No photo, no card (Market's lite search already leaves those out).
            let withImages = (body.items ?? []).filter { !($0.image ?? "").isEmpty }
            content.total = withImages.count
            content.items = Array(withImages.prefix(4))
            if withImages.isEmpty {
                // Listed shops' photos are sometimes http://, which ATS would block.
                content.listings = Array((body.listingItems ?? [])
                    .filter { !($0.image ?? "").isEmpty && ($0.url.hasPrefix("https://") || $0.url.hasPrefix("http://")) }
                    .map { item in
                        MarketListingItem(
                            id: item.id, title: item.title, priceCents: item.priceCents,
                            image: item.image.map { $0.hasPrefix("http://") ? "https://" + $0.dropFirst(7) : $0 },
                            url: item.url, storeName: item.storeName
                        )
                    }
                    .prefix(4))
            }
        } catch {
            return content
        }
        cache[query] = content
        return content
    }
}

/// "From local stores on TODD Market": items independent stores in the
/// Market network sell that match the search. When no member store has it,
/// the same strip shows products from shops Market has listed, marked "Not
/// on TODD Market yet", with their own site and "Buy it here" (Market's
/// search, where "Want to buy it here?" lives). Mirrors the web app's
/// market-strip.component.ts; shown only for shopping searches
/// (the response's shoppingIntent), under the result.
struct MarketStripView: View {
    let query: String

    @State private var content = MarketStripContent()
    @State private var failedImages: Set<String> = []

    private var searchURL: URL? {
        var components = URLComponents(string: marketBase + "/")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    private var items: [MarketItem] { content.items.filter { !failedImages.contains($0.id) } }
    private var listings: [MarketListingItem] { content.listings.filter { !failedImages.contains($0.id) } }

    var body: some View {
        Group {
            if !items.isEmpty {
                memberStrip
            } else if !listings.isEmpty {
                listedStrip
            }
        }
        .task(id: query) {
            failedImages = []
            content = await MarketStripLoader.shared.content(for: query)
        }
    }

    private var memberStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                label("From local stores on TODD Market", systemImage: "bag")
                Spacer(minLength: 0)
                if let searchURL {
                    Link("See all \(content.total) →", destination: searchURL)
                        .font(Theme.font(13, weight: .semibold))
                        .foregroundStyle(Theme.blueInk)
                }
            }
            grid {
                ForEach(items, id: \.id) { item in
                    if let url = itemURL(item) {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 4) {
                                photo(item.image, id: item.id)
                                store(item.storeName)
                                title(item.title)
                                if let cents = item.priceCents {
                                    price(cents)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("From local stores on TODD Market")
    }

    private var listedStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                label("From independent shops", systemImage: "storefront")
                Spacer(minLength: 0)
                Text("Not on TODD Market yet")
                    .font(Theme.font(12, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.bg, in: Capsule())
            }
            grid {
                ForEach(listings, id: \.id) { item in
                    let shopURL = URL(string: item.url)
                    VStack(alignment: .leading, spacing: 4) {
                        if let shopURL {
                            Link(destination: shopURL) { photo(item.image, id: item.id) }
                                .accessibilityLabel("\(item.title) at \(item.storeName)")
                        }
                        store(item.storeName)
                        title(item.title)
                        if let cents = item.priceCents, cents > 0 {
                            price(cents)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .leading, spacing: 4) {
                            if let shopURL {
                                Link("Shop on their site ↗", destination: shopURL)
                            }
                            if let searchURL {
                                Link("Buy it here", destination: searchURL)
                            }
                        }
                        .font(Theme.font(13, weight: .semibold))
                        .foregroundStyle(Theme.blueInk)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("From independent shops, not on TODD Market yet")
    }

    private func grid<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)], spacing: 10, content: content)
    }

    private func label(_ text: String, systemImage: String) -> some View {
        Label(text.uppercased(), systemImage: systemImage)
            .font(Theme.font(13, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(Theme.muted)
            .lineLimit(2)
    }

    /// A photo that doesn't load takes its card with it.
    private func photo(_ image: String?, id: String) -> some View {
        AsyncImage(url: image.flatMap(URL.init(string:))) { phase in
            switch phase {
            case .success(let loaded):
                loaded.resizable().scaledToFill()
            case .failure:
                Color.clear.onAppear { failedImages.insert(id) }
            default:
                Theme.surface2
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func store(_ name: String) -> some View {
        Text(name)
            .font(Theme.font(12, weight: .bold))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(14, weight: .bold))
            .foregroundStyle(Theme.text)
            .lineSpacing(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func price(_ cents: Int) -> some View {
        Text(Self.formatPrice(cents))
            .font(Theme.font(14, weight: .bold))
            .foregroundStyle(Theme.text)
    }

    private func itemURL(_ item: MarketItem) -> URL? {
        var components = URLComponents(string: "\(marketBase)/\(item.storeSlug)")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    static func formatPrice(_ cents: Int) -> String {
        if cents % 100 == 0 {
            return "$" + (cents / 100).formatted(.number.locale(Locale(identifier: "en_US")))
        }
        return String(format: "$%.2f", Double(cents) / 100)
    }
}
