import SwiftUI

/// Round 5 types 1–2 (web: find-media-card): a movie (violet) or TV show
/// (cyan). Score pills show only the sources OMDb returned. No showtimes or
/// streaming prices (no free source): a movie links out for tickets or where
/// to watch, a show to its own service.
struct EntityMediaCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    @StateObject private var sections = EntitySections()

    private var isMovie: Bool { entity.type == "movie" }
    private var title: FindMediaTitleSection? { sections.value("title", as: FindMediaTitleSection.self) }
    private var facts: FindMovieFactsSection? { sections.value("facts", as: FindMovieFactsSection.self) }
    private var show: FindTvShowSection? { sections.value("show", as: FindTvShowSection.self) }
    private var summary: FindEntitySummary? { sections.value("summary", as: FindEntitySummary.self) }
    private var tone: String { isMovie ? "violet" : "cyan" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let status = statusText { EntityStatusPill(text: status, tone: tone) }

            VStack(alignment: .leading, spacing: 10) {
                EntityTagChips(tags: tags)
                EntityIdentityRow(name: entity.name, meta: (title?.meta ?? []).joined(separator: " · ")) {
                    EntityThumb(url: title?.posterUrl ?? show?.imageUrl, fallback: entity.name, width: 72, height: 108, fill: true)
                }
            }

            if let scores = title?.scores, !scores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    EntityFlow(spacing: 10) {
                        ForEach(scores, id: \.self) { score in scorePill(score) }
                    }
                    if let via = title?.scoresVia, !via.isEmpty {
                        Text(via).font(Theme.font(12)).foregroundStyle(Theme.muted)
                    }
                }
            } else if sections.isLoading("title") {
                EntitySkeleton(height: 40, radius: 20)
            }

            if isMovie {
                if let release { moviePanel(release) } else if sections.isLoading("title") { EntitySkeleton(height: 160, radius: 20) }
            } else if let show, show.next != nil || show.latest != nil || !(show.service ?? "").isEmpty {
                tvPanel(show)
            } else if sections.isLoading("show") {
                EntitySkeleton(height: 200, radius: 20)
            }

            EntitySummaryBlock(summary: summary, isLoading: sections.isLoading("summary"))

            VStack(spacing: 10) {
                if !tiles.isEmpty {
                    EntityDisclosure(title: isMovie ? "Box office and facts" : "Facts", preview: "\(tiles[0].label) \(tiles[0].value)") {
                        EntityTileRows(tiles: tiles)
                    }
                }
                if !cast.isEmpty {
                    EntityDisclosure(title: "Cast", preview: [cast[0].name, cast[0].value].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")) {
                        EntityRows(rows: cast)
                    }
                }
                if isMovie, !crew.isEmpty {
                    EntityDisclosure(title: "Crew and awards", preview: crew[0].name) {
                        EntityRows(rows: crew)
                        if let awards = title?.awards, !awards.isEmpty {
                            Text(awards).font(Theme.font(14)).foregroundStyle(Theme.muted).padding(.top, 8).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if !isMovie, let seasons = show?.seasons, !seasons.isEmpty {
                    EntityDisclosure(title: "Seasons and episodes", preview: [seasons[0].name, seasons[0].value].compactMap { $0 }.joined(separator: " · ")) {
                        EntityRows(rows: seasons)
                        if let episodes = show?.episodes, !episodes.isEmpty {
                            EntityListTitle(text: "Season \(show?.currentSeason.map(String.init) ?? "") episodes")
                            EntityRows(rows: episodes)
                        }
                    }
                }
            }

            EntityActionTiles(actions: actions)
        }
        .task { await sections.load(isMovie ? ["title", "facts", "summary"] : ["title", "show", "summary"], fetch: fetch) }
    }

    // MARK: Panels

    private func moviePanel(_ release: (headline: String, line: String, pill: String)) -> some View {
        EntityPanel(tone: tone) {
            VStack(alignment: .leading, spacing: 6) {
                EntityPanelLabel(text: "Where to watch")
                Text(release.headline).font(Theme.font(22, weight: .bold))
                if !release.line.isEmpty { Text(release.line).font(Theme.font(15)) }
            }
            if let awards = title?.awards, !awards.isEmpty {
                EntityPanelDivider()
                VStack(alignment: .leading, spacing: 6) {
                    EntityPanelLabel(text: "Awards")
                    Text(awards).font(Theme.font(15)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tvPanel(_ show: FindTvShowSection) -> some View {
        EntityPanel(tone: tone) {
            if let next = show.next {
                VStack(alignment: .leading, spacing: 6) {
                    EntityPanelLabel(text: "Next episode")
                    Text(episodeTitle(next)).font(Theme.font(22, weight: .bold))
                    Text([episodeDay(next), episodeTime(next), show.service].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(Theme.font(15))
                }
            }
            if let latest = show.latest {
                if show.next != nil { EntityPanelDivider() }
                VStack(alignment: .leading, spacing: 6) {
                    EntityPanelLabel(text: "Latest episode")
                    Text(episodeTitle(latest)).font(Theme.font(show.next == nil ? 22 : 18, weight: .bold))
                    Text(["Aired \(episodeDay(latest) ?? "")", latest.runtime.map { "\($0) min" }].compactMap { $0 }.joined(separator: " · ")).font(Theme.font(15))
                }
            }
            if let service = show.service, !service.isEmpty {
                EntityPanelDivider()
                VStack(alignment: .leading, spacing: 8) {
                    EntityPanelLabel(text: "Where to watch")
                    Group {
                        if let link = show.serviceUrl.flatMap(URL.init(string:)) {
                            Link(service, destination: link)
                        } else {
                            Text(service)
                        }
                    }
                    .font(Theme.font(15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.bg, in: Capsule())
                }
            }
        }
    }

    /// The handoff's simple text marks: IMDb yellow block, RT circle, MC square.
    private func scorePill(_ score: FindMediaScore) -> some View {
        HStack(spacing: 8) {
            switch score.source {
            case "imdb":
                Text("IMDb").font(Theme.font(11, weight: .heavy)).foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Theme.yellow, in: RoundedRectangle(cornerRadius: 5))
            case "rt":
                Text("RT").font(Theme.font(10, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color(hex: 0xd4183a), in: Circle())
            default:
                Text("MC").font(Theme.font(10, weight: .heavy)).foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color(hex: 0x1d7a3a), in: RoundedRectangle(cornerRadius: 6))
            }
            Text(score.value).font(Theme.font(18, weight: .bold)).foregroundStyle(Theme.text)
            if let scale = score.scale, !scale.isEmpty {
                Text(scale).font(Theme.font(13)).foregroundStyle(Theme.muted)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .frame(height: 40)
        .background(Theme.surface, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(score.label) \(score.value)\(score.scale ?? "")")
    }

    // MARK: Words

    private var tags: [FindEntityTag] {
        let own = title?.tags ?? [FindEntityTag(text: entity.label ?? (isMovie ? "Movie" : "TV series"), tone: tone)]
        if let status = show?.statusTag, !status.isEmpty { return own + [FindEntityTag(text: status, tone: "pink")] }
        return own
    }

    private var tiles: [FindStatTile] {
        if isMovie {
            let order = ["Box office", "US gross", "Budget", "IMDb votes"]
            return ((title?.tiles ?? []) + (facts?.tiles ?? []))
                .sorted { (order.firstIndex(of: $0.label) ?? order.count) < (order.firstIndex(of: $1.label) ?? order.count) }
        }
        return (show?.tiles ?? []) + (title?.tiles ?? [])
    }

    /// Cast with roles when Wikidata has them, else OMDb's top-billed names.
    private var cast: [FindListRow] {
        isMovie ? (facts?.cast ?? title?.cast ?? []) : (show?.cast ?? [])
    }

    private var crew: [FindListRow] {
        var rows = title?.crew ?? []
        if let composer = facts?.composer, !composer.isEmpty {
            rows.append(FindListRow(name: composer, value: "Music", sub: nil, url: nil))
        }
        return rows
    }

    private var release: (headline: String, line: String, pill: String)? {
        guard let title, isMovie else { return nil }
        let date = FindEntityFormat.day(title.released)
        let day = date.map { FindEntityFormat.format($0, "MMMd", timeZone: TimeZone(identifier: "UTC")!) } ?? ""
        let by = facts?.distributors?.first.map { "Released by \($0)" } ?? ""
        switch title.status {
        case "theaters":
            return ("In theaters now", [day.isEmpty ? "" : "Opened \(day)", by].filter { !$0.isEmpty }.joined(separator: " · "), "In theaters")
        case "coming":
            return (day.isEmpty ? "Coming soon" : "In theaters \(day)", by, day.isEmpty ? "Coming soon" : "Opens \(day)")
        default:
            let year = date.map { String(Calendar(identifier: .gregorian).component(.year, from: $0)) } ?? ""
            return ("Streaming, rent or buy", [year.isEmpty ? "" : "Out since \(year)", by].filter { !$0.isEmpty }.joined(separator: " · "), "")
        }
    }

    private var statusText: String? {
        if isMovie { return release.flatMap { $0.pill.isEmpty ? nil : $0.pill } }
        if let next = show?.next {
            return ["Next: \(next.code)", episodeDay(next)].compactMap { $0 }.joined(separator: " · ")
        }
        return show?.statusTag.flatMap { $0.isEmpty ? nil : $0 }
    }

    private var actions: [EntityAction] {
        guard let links = title?.links else { return [] }
        if isMovie {
            let primary = title?.status == "released"
                ? EntityAction("Watch", systemImage: "tv", url: links.watch)
                : EntityAction("Tickets", systemImage: "ticket", url: links.tickets)
            let site = EntityAction(facts?.links?.website?.isEmpty == false ? "Site" : "Wikipedia", systemImage: "arrow.up.right.square", url: (facts?.links?.website ?? "").ifEmpty(facts?.links?.wikipedia ?? ""))
            return [primary, EntityAction("Trailer", systemImage: "play.fill", url: links.trailer), EntityAction("IMDb", systemImage: "arrow.up.right.square", url: links.imdb), site].compactMap { $0 }
        }
        return [
            EntityAction("Watch", systemImage: "play.fill", url: show?.serviceUrl),
            EntityAction("Episodes", systemImage: "list.bullet", url: show?.links?.guide),
            EntityAction("Trailer", systemImage: "play.rectangle", url: links.trailer),
            EntityAction("IMDb", systemImage: "arrow.up.right.square", url: links.imdb),
        ].compactMap { $0 }
    }

    private func episodeTitle(_ episode: FindTvEpisode) -> String {
        [episode.code, episode.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func episodeDay(_ episode: FindTvEpisode) -> String? {
        guard let date = FindEntityFormat.date(episode.airstamp) ?? FindEntityFormat.day(episode.airdate) else { return nil }
        return FindEntityFormat.format(date, "EEEMMMd")
    }

    private func episodeTime(_ episode: FindTvEpisode) -> String? {
        FindEntityFormat.date(episode.airstamp).map { FindEntityFormat.format($0, "jmm") }
    }
}
