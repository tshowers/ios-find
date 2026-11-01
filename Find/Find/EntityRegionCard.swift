import SwiftUI

/// Round 5 types 7–9 (web: find-region-card): a country or US state (green)
/// or a city (blue). Flag or seal, a map or skyline, the local time (kept
/// running here) and weather, fact tiles, things to do and local news.
struct EntityRegionCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    let onSearch: (String) -> Void
    @StateObject private var sections = EntitySections()

    private var region: FindRegionSection? { sections.value("region", as: FindRegionSection.self) }
    private var local: FindRegionLocal? { sections.value("local", as: FindRegionLocal.self) }
    private var todo: FindRowsSection? { sections.value("todo", as: FindRowsSection.self) }
    private var news: FindEntityNewsSection? { sections.value("news", as: FindEntityNewsSection.self) }
    private var summary: FindEntitySummary? { sections.value("summary", as: FindEntitySummary.self) }
    private var tone: String { entity.type == "city" ? "blue" : "green" }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .task { await sections.load(["region", "local", "todo", "news", "summary"], fetch: fetch) }
    }

    private func content(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let local, let status = statusText(local, now: now) {
                EntityStatusPill(text: status, tone: tone)
            }

            if sections.isLoading("region") {
                EntitySkeleton(height: 200, radius: 20)
            } else {
                EntityHeroImage(url: region?.imageUrl, fit: entity.type != "city")
            }

            EntityIdentityRow(name: entity.name, meta: subtitle) {
                EntityThumb(url: region?.thumbUrl, fallback: entity.name)
            }

            if sections.isLoading("region") {
                EntitySkeleton(height: 40, radius: 20)
            } else {
                EntityKeyFacts(facts: keyFacts(now: now))
            }

            if let local {
                localPanel(local, now: now)
            } else if sections.isLoading("local") {
                EntitySkeleton(height: 200, radius: 20)
            }

            EntitySummaryBlock(summary: summary, isLoading: sections.isLoading("summary"))

            VStack(spacing: 10) {
                if let rows = todo?.rows, !rows.isEmpty {
                    EntityDisclosure(title: "Things to do", preview: firstRow(rows)) { EntityRows(rows: rows) }
                } else if sections.isLoading("todo") {
                    EntitySkeleton()
                }

                if let tiles = region?.tiles, !tiles.isEmpty {
                    EntityDisclosure(title: "Facts", preview: "\(tiles[0].label) \(tiles[0].value)") {
                        EntityTileRows(tiles: tiles)
                        ForEach(region?.lists ?? [], id: \.self) { list in
                            EntityListTitle(text: list.title)
                            EntityRows(rows: list.rows)
                        }
                    }
                }

                if let articles = news?.articles, !articles.isEmpty {
                    EntityDisclosure(title: "Local news", preview: articles[0].headline) {
                        ForEach(articles, id: \.self) { article in
                            EntityRow(name: article.headline, sub: [article.source, FindEntityFormat.ago(article.published)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), url: article.url)
                        }
                    }
                } else if sections.isLoading("news") {
                    EntitySkeleton()
                }
            }

            EntityActionTiles(actions: actions)
        }
    }

    private func localPanel(_ local: FindRegionLocal, now: Date) -> some View {
        EntityPanel(tone: tone) {
            VStack(alignment: .leading, spacing: 6) {
                EntityPanelLabel(text: "Local time")
                Text(time(local, now: now))
                    .font(Theme.font(44, weight: .bold))
                    .tracking(-1.2)
                Text([day(local, now: now), zoneName(local, now: now)].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Theme.font(15))
            }
            .accessibilityElement(children: .combine)
            if let weather = local.weather {
                EntityPanelDivider()
                VStack(alignment: .leading, spacing: 6) {
                    EntityPanelLabel(text: "Weather · \(local.place)")
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(weather.temperature)°").font(Theme.font(44, weight: .bold))
                        if let condition = weather.condition, !condition.isEmpty {
                            Text(condition).font(Theme.font(18, weight: .bold))
                        }
                        if let high = weather.high, let low = weather.low {
                            Text("H \(high)° · L \(low)°").font(Theme.font(15))
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Words

    /// "Asia · Capital Tokyo", or a city's "Washington, US".
    private var subtitle: String {
        guard let region else { return entity.label ?? "" }
        let meta = region.meta ?? []
        if entity.type == "city" { return meta.first { $0.label.isEmpty }?.value ?? "" }
        let second = region.tags?.dropFirst().first?.text
        let capital = meta.first { $0.label == "Capital" }.map { "Capital \($0.value)" }
        return [second, capital].compactMap { $0 }.joined(separator: " · ")
    }

    private func keyFacts(now: Date) -> [FindKeyFact] {
        var facts: [FindKeyFact] = []
        if let population = region?.meta?.first(where: { $0.label == "Population" }) {
            facts.append(FindKeyFact(value: population.value, label: "people"))
        }
        if let currency = region?.currency {
            facts.append(FindKeyFact(value: currency.code, label: "\(String(format: currency.rate >= 100 ? "%.1f" : "%.2f", currency.rate)) = $1"))
        }
        if let hours = hoursFromPhone(now: now), hours != 0 {
            facts.append(FindKeyFact(value: "\(hours > 0 ? "+" : "")\(FindEntityFormat.trim(hours))h", label: "from you"))
        }
        return facts
    }

    private var actions: [EntityAction] {
        guard let region else { return [] }
        var actions: [EntityAction?] = [EntityAction("Advisory", systemImage: "exclamationmark.shield", url: region.advisory?.url)]
        if let code = region.currency?.code {
            actions.append(EntityAction(code, systemImage: "arrow.left.arrow.right") { onSearch("1 USD to \(code)") })
        }
        actions.append(EntityAction("Map", systemImage: "map", url: region.links?.map))
        if entity.type != "country" { actions.append(EntityAction("Site", systemImage: "globe", url: region.links?.website)) }
        actions.append(EntityAction("Wikipedia", systemImage: "book", url: region.links?.wikipedia))
        return actions.compactMap { $0 }
    }

    private func firstRow(_ rows: [FindListRow]) -> String {
        guard let row = rows.first else { return "" }
        return [row.name, row.value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: Time there

    private func zone(_ local: FindRegionLocal) -> TimeZone {
        TimeZone(identifier: local.timeZone) ?? .current
    }

    private func time(_ local: FindRegionLocal, now: Date) -> String {
        FindEntityFormat.format(now, "jmm", timeZone: zone(local))
    }

    private func day(_ local: FindRegionLocal, now: Date) -> String {
        FindEntityFormat.format(now, "EEEMMMd", timeZone: zone(local))
    }

    private func zoneName(_ local: FindRegionLocal, now: Date) -> String {
        zone(local).abbreviation(for: now) ?? ""
    }

    /// The place's clock minus the phone's, in hours (5.5 for India from UTC).
    private func hoursFromPhone(now: Date) -> Double? {
        guard let local else { return nil }
        let seconds = zone(local).secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)
        return Double(seconds) / 3600
    }

    /// "10:12 AM in Tokyo · 18° Clear".
    private func statusText(_ local: FindRegionLocal, now: Date) -> String? {
        let weather = local.weather.map { "\($0.temperature)° \($0.condition ?? "")".trimmingCharacters(in: .whitespaces) }
        return ["\(time(local, now: now)) in \(local.place)", weather].compactMap { $0 }.joined(separator: " · ")
    }
}
