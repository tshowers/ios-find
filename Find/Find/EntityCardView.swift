import SwiftUI

/// The single-item card for whatever the query names (web: the entity,
/// business, shop, region and media cards in find-home). It shows while the
/// normal search is still running; "More results" swaps in the usual pages.
struct EntityCardView: View {
    let entity: FindEntity
    let query: String
    let moreCount: Int?
    /// Loads one section's JSON (nil when there's none).
    let fetch: @Sendable (String) async -> Data?
    let watchStore: FindWatchStore
    let onMore: () -> Void
    /// A search the card runs itself ("Convert USD to JPY").
    let onSearch: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Group {
                switch entity.type {
                case "sports":
                    EntitySportsCard(entity: entity, fetch: fetch)
                case "store", "restaurant", "service":
                    EntityBusinessCard(entity: entity, fetch: fetch)
                case "shop":
                    EntityShopCard(entity: entity, query: query, fetch: fetch, watchStore: watchStore)
                case "country", "state", "city":
                    EntityRegionCard(entity: entity, fetch: fetch, onSearch: onSearch)
                case "movie", "tv":
                    EntityMediaCard(entity: entity, fetch: fetch)
                case "artist", "album", "song":
                    EntityMusicCard(entity: entity, fetch: fetch)
                default:
                    EmptyView()
                }
            }
            // A new entity starts a fresh card (its own sections and open state).
            .id("\(entity.type)|\(entity.id)")

            EntityMoreButton(query: query, count: moreCount, action: onMore)
        }
        .accessibilityIdentifier("find-entity-card")
    }
}

// MARK: Teams (NFL, NBA, MLB, college)

/// Round 4 type 1 (and r5 type 6, college): live-first.
struct EntitySportsCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    @StateObject private var sections = EntitySections()

    private var team: FindSportsTeamSection? { sections.value("team", as: FindSportsTeamSection.self) }
    private var games: FindSportsGamesSection? { sections.value("games", as: FindSportsGamesSection.self) }
    private var leaders: FindSportsLeadersSection? { sections.value("leaders", as: FindSportsLeadersSection.self) }
    private var news: FindEntityNewsSection? { sections.value("news", as: FindEntityNewsSection.self) }
    private var summary: FindEntitySummary? { sections.value("summary", as: FindEntitySummary.self) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let status { EntityStatusPill(text: status.text, tone: status.tone) }

            if sections.isLoading("team") {
                EntitySkeleton(height: 200, radius: 20)
            } else {
                EntityHeroImage(url: team?.imageUrl)
            }

            VStack(alignment: .leading, spacing: 10) {
                EntityTagChips(tags: [FindEntityTag(text: entity.label ?? "Team", tone: "cyan")] + (team?.tags ?? []))
                EntityIdentityRow(name: entity.name, meta: [team?.record, team?.standing].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")) {
                    EntityThumb(url: entity.logoUrl, fallback: entity.name)
                }
            }

            if let live = games?.live { scoreboard(live) }

            if sections.isLoading("team") {
                EntitySkeleton(height: 40, radius: 20)
            } else {
                EntityKeyFacts(facts: team?.keyFacts ?? [])
            }

            EntitySummaryBlock(summary: summary, isLoading: sections.isLoading("summary"))

            VStack(spacing: 10) {
                if let game = games?.live ?? games?.last {
                    EntityDisclosure(title: games?.live != nil ? "This game" : "Last game", preview: gamePreview(game)) {
                        scoreLines(game)
                        if games?.live == nil, let recap = game.recap, !recap.isEmpty { note(recap) }
                        if let venue = game.venue, !venue.isEmpty { note([day(game.date), venue].compactMap { $0 }.joined(separator: " · ")) }
                    }
                } else if sections.isLoading("games") {
                    EntitySkeleton()
                }

                if let tiles = team?.tiles, !tiles.isEmpty {
                    EntityDisclosure(title: "Season stats", preview: tiles.filter { $0.label != "Record" }.prefix(2).map { "\($0.value) \($0.label.lowercased())" }.joined(separator: " · ")) {
                        EntityTileRows(tiles: tiles)
                        if let division = team?.division {
                            EntityListTitle(text: division.division)
                            ForEach(division.rows, id: \.self) { row in
                                EntityRow(name: row.name, value: row.record, highlight: row.isTeam == true)
                            }
                        }
                    }
                } else if sections.isLoading("team") {
                    EntitySkeleton()
                }

                if let leaders, !(leaders.offense.isEmpty && leaders.defense.isEmpty) {
                    EntityDisclosure(title: "Player leaders", preview: leaders.offense.first.map { "\($0.name) · \($0.stat)" } ?? "") {
                        leaderRows(leaders.offense, title: leaders.offenseTitle ?? "Leaders")
                        leaderRows(leaders.defense, title: leaders.defenseTitle ?? "More leaders")
                    }
                } else if sections.isLoading("leaders") {
                    EntitySkeleton()
                }

                if let articles = news?.articles, !articles.isEmpty {
                    EntityDisclosure(title: "Latest news", preview: articles[0].headline) {
                        ForEach(articles, id: \.self) { article in
                            EntityRow(name: article.headline, sub: (["ESPN", FindEntityFormat.ago(article.published)] as [String?]).compactMap { $0 }.joined(separator: " · "), url: article.url)
                        }
                    }
                } else if sections.isLoading("news") {
                    EntitySkeleton()
                }

                if let next = games?.next {
                    EntityDisclosure(title: "Next game", preview: [next.homeAway, next.opponent].compactMap { $0 }.joined(separator: " ") + (day(next.date).map { " · \($0)" } ?? "")) {
                        EntityRow(name: "Opponent", value: [next.homeAway, next.opponent].compactMap { $0 }.joined(separator: " "))
                        if let date = FindEntityFormat.date(next.date) {
                            EntityRow(name: "When", value: FindEntityFormat.format(date, "EEEMMMdjmm"))
                        }
                        if let network = next.network, !network.isEmpty { EntityRow(name: "TV", value: network) }
                        if let venue = next.venue, !venue.isEmpty { EntityRow(name: "Venue", value: venue) }
                        if let line = next.line, !line.isEmpty { EntityRow(name: "Line", value: line) }
                    }
                }
            }

            EntityActionTiles(actions: actions)
        }
        .task { await sections.load(["team", "games", "leaders", "news", "summary"], fetch: fetch) }
        // Scores refresh every 30 s while a game is on; a failed refresh keeps the last score.
        .task(id: games?.live?.id) {
            guard games?.live != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await sections.refresh("games", fetch: fetch)
            }
        }
    }

    private var status: (text: String, tone: String)? {
        if let live = games?.live {
            return (["Live", live.detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), "pink")
        }
        if let next = games?.next, let date = FindEntityFormat.date(next.date), Calendar.current.isDateInToday(date) {
            return (["Today", FindEntityFormat.format(date, "jmm"), next.network].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), "cyan")
        }
        return nil
    }

    private var actions: [EntityAction] {
        guard let links = entity.links else { return [] }
        let league = entity.league ?? "nfl"
        let isBasketball = league == "nba" || league == "mens-college-basketball"
        return [
            games?.live.flatMap { EntityAction("Live", systemImage: "dot.radiowaves.left.and.right", url: "https://www.espn.com/\(league)/game/_/gameId/\($0.id)") }
                ?? EntityAction("ESPN", systemImage: "arrow.up.right.square", url: links.espn),
            EntityAction(links.siteName ?? "League", systemImage: isBasketball ? "basketball" : league == "mlb" ? "baseball" : "football", url: links.site),
            EntityAction("Schedule", systemImage: "calendar", url: links.schedule),
            EntityAction("Tickets", systemImage: "ticket", url: links.tickets),
        ].compactMap { $0 }
    }

    private func scoreboard(_ game: FindSportsGame) -> some View {
        EntityPanel(tone: "pink") {
            HStack {
                side(game.away, behind: isBehind(game.away, game.home))
                Spacer()
                VStack(spacing: 2) {
                    Text(game.period ?? "").font(Theme.font(15, weight: .bold))
                    if let clock = game.clock, !clock.isEmpty, !(game.period ?? "").contains(clock) {
                        Text(clock).font(Theme.font(15, weight: .bold))
                    }
                }
                Spacer()
                side(game.home, behind: isBehind(game.home, game.away))
            }
            let footer = [game.situation, game.network].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            if !footer.isEmpty { Text(footer).font(Theme.font(14)) }
        }
    }

    private func side(_ side: FindGameSide, behind: Bool) -> some View {
        VStack(spacing: 2) {
            Text(side.abbr ?? "").font(Theme.font(15, weight: .bold))
            Text(side.score ?? "–").font(Theme.font(44, weight: .bold))
        }
        .opacity(behind ? 0.55 : 1)
    }

    private func isBehind(_ side: FindGameSide, _ other: FindGameSide) -> Bool {
        guard let mine = Double(side.score ?? ""), let theirs = Double(other.score ?? "") else { return false }
        return mine < theirs
    }

    private func scoreLines(_ game: FindSportsGame) -> some View {
        VStack(spacing: 0) {
            ForEach([game.away, game.home], id: \.self) { side in
                EntityRow(name: side.name ?? side.abbr ?? "", value: side.score, highlight: side.winner == true)
            }
        }
    }

    private func gamePreview(_ game: FindSportsGame) -> String {
        if game.state == "in" {
            return "\(game.away.abbr ?? "") \(game.away.score ?? "") – \(game.home.abbr ?? "") \(game.home.score ?? "")" + (game.detail.map { " · \($0)" } ?? "")
        }
        return [game.result, game.score, game.homeAway, game.opponentAbbr].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func leaderRows(_ rows: [FindLeaderRow], title: String) -> some View {
        Group {
            if !rows.isEmpty {
                EntityListTitle(text: title)
                ForEach(rows, id: \.self) { row in
                    EntityRow(name: row.name, value: row.stat, sub: [row.label, row.position, row.detail].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                }
            }
        }
    }

    private func day(_ text: String?) -> String? {
        FindEntityFormat.date(text).map { FindEntityFormat.format($0, "EEEMMMd") }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Theme.font(14)).foregroundStyle(Theme.muted).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
    }
}
