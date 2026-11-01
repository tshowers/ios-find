import SwiftUI

/// A 16Ahead Store shop (web: find-shop-card): the shop in its own colours,
/// its products with a Watch on each, and a link to shop it on 16ahead.store.
struct EntityShopCard: View {
    let entity: FindEntity
    let query: String
    let fetch: @Sendable (String) async -> Data?
    @ObservedObject var watchStore: FindWatchStore
    @StateObject private var sections = EntitySections()
    @Environment(\.colorScheme) private var colorScheme

    private var shop: FindShopSection? { sections.value("shop", as: FindShopSection.self) }
    private var storeURL: String { shop?.url ?? entity.website ?? "https://16ahead.store" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                EntityTagChips(tags: [FindEntityTag(text: "16Ahead Store shop", tone: "violet")] + (shop?.category.map { [FindEntityTag(text: $0, tone: "plain")] } ?? []))
                EntityIdentityRow(name: entity.name, meta: [shop?.location, "16ahead.store"].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")) {
                    EntityThumb(url: entity.logoUrl, fallback: entity.name)
                }
            }

            if sections.isLoading("shop") {
                EntitySkeleton(height: 180, radius: 20)
            } else if let shop {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Shop on 16Ahead Store").font(Theme.font(13, weight: .bold))
                    Text((shop.heroLine ?? "").ifEmpty(shop.description ?? ""))
                        .font(Theme.font(20, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    if !facts.isEmpty {
                        Text(facts.joined(separator: " · ")).font(Theme.font(14))
                    }
                    if let url = URL(string: storeURL) {
                        Link(destination: url) {
                            Label("Visit store", systemImage: "bag.fill")
                                .font(Theme.font(15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 44)
                                .background(Theme.blue, in: Capsule())
                        }
                    }
                }
                .foregroundStyle(tint.foreground)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if let description = shop.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        (Text("About this shop").font(Theme.font(13, weight: .bold)) + Text(" · from \(entity.name)").font(Theme.font(13)).foregroundColor(Theme.muted))
                        Text(description).font(Theme.font(15)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 0) {
                    if let collections = shop.collections, !collections.isEmpty {
                        EntityListTitle(text: "Shop by category")
                        EntityTagChips(tags: collections.map { collection in FindEntityTag(text: collection.count.map { "\(collection.name) \($0)" } ?? collection.name, tone: "plain") })
                            .padding(.bottom, 8)
                    }
                    if let shipping = shop.shipping, !shipping.isEmpty { EntityRow(name: "Shipping", value: shipping.joined(separator: " · ")) }
                    if let returns = shop.returns, !returns.isEmpty { EntityRow(name: "Returns", value: returns) }
                }

                if let products = shop.products, !products.isEmpty {
                    EntityListTitle(text: "Products")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                        ForEach(products) { product in productTile(product) }
                    }
                }
            }

            EntityActionTiles(actions: [
                EntityAction("Visit shop", systemImage: "bag.fill", url: storeURL),
                EntityAction("All shops", systemImage: "storefront", url: "https://16ahead.store/stores"),
            ].compactMap { $0 })
        }
        .task { await sections.load(["shop"], fetch: fetch) }
    }

    private var facts: [String] {
        guard let shop else { return [] }
        return [
            shop.productCount.map { "\($0) product\($0 == 1 ? "" : "s")" },
            shop.freeShippingOver.flatMap { $0.isEmpty ? nil : "Free shipping over \($0)" },
        ].compactMap { $0 }
    }

    /// The shop's own colours (light and dark), else violet.
    private var tint: (background: Color, foreground: Color) {
        let dark = colorScheme == .dark
        let background = Color(hexString: dark ? entity.tintDark : entity.tint)
        let foreground = Color(hexString: dark ? entity.tintFgDark : entity.tintFg)
        if let background, let foreground { return (background, foreground) }
        return EntityTone.colors("violet")
    }

    private func productTile(_ product: FindShopProduct) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Link(destination: URL(string: product.url) ?? URL(string: storeURL)!) {
                VStack(alignment: .leading, spacing: 6) {
                    ZStack {
                        Theme.surface
                        if let image = product.imageUrl, let url = URL(string: image) {
                            AsyncImage(url: url) { phase in
                                if case .success(let picture) = phase { picture.resizable().scaledToFill() }
                            }
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text(product.title).font(Theme.font(14, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(2)
                    if let price = product.price, !price.isEmpty {
                        Text(price).font(Theme.font(14, weight: .bold)).foregroundStyle(Theme.text)
                    }
                }
            }
            .buttonStyle(.plain)
            if let watchUrl = product.watchUrl, !watchUrl.isEmpty {
                WatchButton(store: watchStore, query: query, url: watchUrl, title: "\(product.title) · \(entity.name)", queryType: "entity", address: nil, phone: nil)
            }
        }
    }
}

extension Color {
    /// "#5b3df5" or "5b3df5"; nil for anything else.
    init?(hexString: String?) {
        guard var text = hexString?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
