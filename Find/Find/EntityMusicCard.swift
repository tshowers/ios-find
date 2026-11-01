import SwiftUI
import AVFoundation
import Combine

/// Round 5 types 3–5 (web: find-music-card): a song or album (pink) or an
/// artist or band (violet). No lyrics (they need a licence): the song's
/// panel plays Apple's 30-second preview and links to its lyrics on Genius.
struct EntityMusicCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    @StateObject private var sections = EntitySections()
    @StateObject private var preview = EntityPreviewPlayer()

    private var facts: FindMusicFactsSection? { sections.value("facts", as: FindMusicFactsSection.self) }
    private var apple: FindMusicAppleSection? { sections.value("apple", as: FindMusicAppleSection.self) }
    private var summary: FindEntitySummary? { sections.value("summary", as: FindEntitySummary.self) }
    private var tone: String { entity.type == "artist" ? "violet" : "pink" }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let status = statusText { EntityStatusPill(text: status, tone: tone) }

            if entity.type == "artist" {
                if sections.isLoading("facts") {
                    EntitySkeleton(height: 200, radius: 20)
                } else {
                    EntityHeroImage(url: facts?.imageUrl)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                EntityTagChips(tags: tags)
                EntityIdentityRow(name: entity.name, meta: meta) {
                    EntityThumb(url: entity.type == "artist" ? facts?.imageUrl : apple?.artworkUrl, fallback: entity.name, width: 72, height: 72, fill: true)
                }
            }

            if facts != nil { EntityActionTiles(actions: listen) }

            panel

            EntitySummaryBlock(summary: summary, isLoading: sections.isLoading("summary"))

            VStack(spacing: 10) {
                if !tiles.isEmpty {
                    EntityDisclosure(title: "Facts", preview: "\(tiles[0].label) \(tiles[0].value)") { EntityTileRows(tiles: tiles) }
                } else if sections.isLoading("facts") {
                    EntitySkeleton()
                }
                if entity.type == "album", let tracks = apple?.tracks, !tracks.isEmpty {
                    EntityDisclosure(title: "Tracklist", preview: [apple?.trackCount.map { "\($0) tracks" }, apple?.length].compactMap { $0 }.joined(separator: " · ")) {
                        EntityRows(rows: rows(tracks, numbered: true))
                    }
                }
                if entity.type == "artist", let songs = apple?.topSongs, !songs.isEmpty {
                    EntityDisclosure(title: "Top songs", preview: songs[0].name) { EntityRows(rows: rows(songs, numbered: false)) }
                }
                if entity.type == "artist", let albums = apple?.albums, !albums.isEmpty {
                    EntityDisclosure(title: "Albums", preview: [albums[0].name, albums[0].value].compactMap { $0 }.joined(separator: " · ")) {
                        EntityRows(rows: albums)
                        if let members = facts?.members, !members.isEmpty {
                            EntityListTitle(text: "Members")
                            EntityRows(rows: members)
                        }
                    }
                }
                if entity.type != "artist", let credits = facts?.credits, !credits.isEmpty {
                    EntityDisclosure(title: "Credits", preview: [credits[0].name, credits[0].value].compactMap { $0 }.joined(separator: " · ")) { EntityRows(rows: credits) }
                }
            }

            EntityActionTiles(actions: actions)
        }
        .task { await sections.load(["facts", "apple", "summary"], fetch: fetch) }
        .onDisappear { preview.stop() }
    }

    // MARK: Panel

    @ViewBuilder
    private var panel: some View {
        switch entity.type {
        case "song":
            if facts != nil || apple != nil {
                EntityPanel(tone: tone) {
                    if let url = apple?.track?.previewUrl.flatMap(URL.init(string:)) {
                        VStack(alignment: .leading, spacing: 10) {
                            EntityPanelLabel(text: "Listen · 30-second preview")
                            Button { preview.toggle(url) } label: {
                                Label(preview.isPlaying ? "Pause preview" : "Play preview", systemImage: preview.isPlaying ? "pause.fill" : "play.fill")
                                    .font(Theme.font(16, weight: .bold))
                                    .foregroundStyle(Theme.text)
                                    .padding(.horizontal, 18)
                                    .frame(height: 44)
                                    .background(Theme.bg, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        EntityPanelDivider()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        EntityPanelLabel(text: "Lyrics")
                        if let url = URL(string: lyricsURL) {
                            Link(destination: url) {
                                HStack {
                                    Text("Read the lyrics on Genius").font(Theme.font(17, weight: .bold))
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square").font(.system(size: 17, weight: .semibold))
                                }
                                .foregroundStyle(Theme.text)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                        Text("Lyrics are licensed to Genius, so Find links to them.").font(Theme.font(13))
                    }
                }
            } else if sections.isLoading("apple") {
                EntitySkeleton(height: 180, radius: 20)
            }
        case "album":
            if let reviews = facts?.reviews, !reviews.isEmpty {
                EntityPanel(tone: tone) {
                    EntityPanelLabel(text: "Reviews")
                    HStack(spacing: 10) {
                        ForEach(reviews, id: \.self) { review in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(review.score).font(Theme.font(20, weight: .bold))
                                Text(review.source).font(Theme.font(12)).foregroundStyle(Theme.muted)
                            }
                            .foregroundStyle(Theme.text)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }
        default:
            if let latest = apple?.latest {
                EntityPanel(tone: tone) {
                    EntityPanelLabel(text: "Latest release")
                    HStack(spacing: 14) {
                        EntityThumb(url: latest.artworkUrl, fallback: latest.name, width: 64, height: 64, fill: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(latest.name).font(Theme.font(20, weight: .bold))
                            Text([latest.kind, releaseDay(latest.released)].compactMap { $0 }.joined(separator: " · ")).font(Theme.font(14))
                        }
                    }
                }
            }
        }
    }

    // MARK: Words

    private var tags: [FindEntityTag] {
        let genre = facts?.tiles?.first { $0.label == "Genre" }?.value.split(separator: ",").first.map(String.init)
        return [FindEntityTag(text: entity.label ?? "Music", tone: tone)] + (genre.map { [FindEntityTag(text: $0, tone: "plain")] } ?? [])
    }

    private var meta: String {
        guard let facts else { return "" }
        let tile = { (label: String) in facts.tiles?.first { $0.label == label }?.value ?? "" }
        switch entity.type {
        case "song":
            return [facts.artist ?? "", (facts.album ?? "").ifEmpty(apple?.album ?? ""), tile("Length")].filter { !$0.isEmpty }.joined(separator: " · ")
        case "album":
            return [facts.artist ?? "", String((facts.released ?? "").prefix(4)), apple?.trackCount.map { "\($0) tracks" } ?? "", (apple?.length ?? "").ifEmpty(tile("Length"))]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        default:
            let since = tile("Active since")
            return [tile("From"), since.isEmpty ? "" : "Since \(since)"].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    private var tiles: [FindStatTile] {
        var tiles = facts?.tiles ?? []
        if entity.type == "album", let count = apple?.trackCount, !tiles.contains(where: { $0.label == "Tracks" }) {
            tiles.insert(FindStatTile(label: "Tracks", value: String(count), sub: apple?.length), at: min(1, tiles.count))
        }
        if entity.type == "artist", let count = apple?.albumCount, count > 0 {
            tiles.insert(FindStatTile(label: "Albums", value: String(count), sub: "On Apple Music"), at: min(2, tiles.count))
        }
        return Array(tiles.prefix(6))
    }

    private var searchText: String {
        [entity.name, entity.type == "artist" ? nil : facts?.artist].compactMap { $0 }.joined(separator: " ")
    }

    private var encodedSearch: String {
        searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    /// Spotify, Apple Music, YouTube Music: the item's own pages, else a search there.
    private var listen: [EntityAction] {
        [
            EntityAction("Spotify", systemImage: "play.fill", url: (facts?.links?.spotify ?? "").ifEmpty("https://open.spotify.com/search/\(encodedSearch)")),
            EntityAction("Apple Music", systemImage: "music.note", url: (apple?.links?.apple ?? "").ifEmpty("https://music.apple.com/us/search?term=\(encodedSearch)")),
            EntityAction("YouTube", systemImage: "play.rectangle.fill", url: "https://music.youtube.com/search?q=\(encodedSearch)"),
        ].compactMap { $0 }
    }

    private var lyricsURL: String {
        (facts?.links?.genius ?? "").ifEmpty("https://genius.com/search?q=\(encodedSearch)")
    }

    private var actions: [EntityAction] {
        let links = facts?.links
        switch entity.type {
        case "song":
            return [
                EntityAction("Lyrics", systemImage: "text.alignleft", url: lyricsURL),
                EntityAction("Video", systemImage: "video.fill", url: (links?.youtube ?? "").ifEmpty("https://www.youtube.com/results?search_query=\(encodedSearch)%20official%20video")),
                EntityAction("Artist", systemImage: "person.fill", url: apple?.links?.appleArtist),
                EntityAction("Wikipedia", systemImage: "book", url: links?.wikipedia),
            ].compactMap { $0 }
        case "album":
            return [
                EntityAction("Lyrics", systemImage: "text.alignleft", url: (links?.genius ?? "").ifEmpty("https://genius.com/search?q=\(encodedSearch)")),
                EntityAction("Artist", systemImage: "person.fill", url: apple?.links?.appleArtist),
                EntityAction("Wikipedia", systemImage: "book", url: links?.wikipedia),
            ].compactMap { $0 }
        default:
            let name = entity.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return [
                // Tour dates: no free source, so a search where tickets are sold.
                EntityAction("Tour dates", systemImage: "ticket", url: "https://www.ticketmaster.com/search?q=\(name)"),
                EntityAction("Site", systemImage: "globe", url: links?.website),
                EntityAction("Wikipedia", systemImage: "book", url: links?.wikipedia),
            ].compactMap { $0 }
        }
    }

    private var statusText: String? {
        if entity.type == "artist" {
            return apple?.latest.map { "New \($0.kind.lowercased()): \($0.name)" }
        }
        guard let artist = facts?.artist, !artist.isEmpty else { return nil }
        return "\(entity.label ?? "Music") · \(artist)"
    }

    /// An album's tracks are numbered; an artist's top songs aren't (their numbers are from their own albums).
    private func rows(_ tracks: [FindMusicTrack], numbered: Bool) -> [FindListRow] {
        tracks.map { track in
            FindListRow(name: "\(numbered ? track.number.map { "\($0). " } ?? "" : "")\(track.name)", value: track.length, sub: track.album, url: track.url)
        }
    }

    private func releaseDay(_ text: String?) -> String? {
        FindEntityFormat.day(text).map { FindEntityFormat.format($0, "yMMMd", timeZone: TimeZone(identifier: "UTC")!) }
    }
}

/// Plays one 30-second preview at a time.
@MainActor
final class EntityPreviewPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    private var player: AVPlayer?
    private var url: URL?
    private var endObserver: NSObjectProtocol?

    func toggle(_ url: URL) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        if self.url != url || player == nil {
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            self.url = url
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.isPlaying = false
                    self?.player?.seek(to: .zero)
                }
            }
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        isPlaying = false
    }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
