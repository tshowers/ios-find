import SwiftUI
import AVKit
import WebKit

/// design_handoff_find_taliferro_results (web: find-company-card, iPhone
/// layout 5c): our own company ("taliferro tech") and products ("image
/// creator"), another company ("apple", 5e) and a product to buy ("dell xps
/// 14", 5d). One card: a video that plays in place, the 16Ahead summary, stat
/// tiles, Call / Email / Directions, then the tinted panel (a product's steps,
/// another company's next earnings report, or prices at stores).
struct EntityCompanyCard: View {
    let entity: FindEntity
    let fetch: @Sendable (String) async -> Data?
    @StateObject private var sections = EntitySections()

    private var overview: FindCardOverview? { sections.value("overview", as: FindCardOverview.self) }
    private var summary: FindEntitySummary? { sections.value("summary", as: FindEntitySummary.self) }
    private var market: FindCompanyMarket? { sections.value("market", as: FindCompanyMarket.self) }
    private var youtube: FindCardVideos? { sections.value("videos", as: FindCardVideos.self) }

    /// Another company or a product to buy: not ours, so videos come from YouTube.
    private var isExternal: Bool { entity.type == "corporation" || entity.type == "item" }
    private var isOurCompany: Bool { entity.type == "company" }

    private var sectionNames: [String] {
        switch entity.type {
        case "corporation": return ["overview", "summary", "market", "videos"]
        case "item": return ["overview", "summary", "videos"]
        default: return ["overview", "summary"]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                EntityTagChips(tags: overview?.tags ?? [])
                EntityIdentityRow(name: entity.name, meta: metaLine) {
                    logo
                }
            }

            videoBlock

            EntitySummaryBlock(summary: summary, isLoading: sections.isLoading("summary"))

            if sections.isLoading("overview") {
                EntitySkeleton(height: 90, radius: 16)
            } else if !tiles.isEmpty {
                tileGrid
            }

            if !contacts.isEmpty { contactRow }

            if let panel = overview?.panel { panelView(panel) }

            VStack(spacing: 10) { disclosures }

            EntityActionTiles(actions: actions)
        }
        .task { await sections.load(sectionNames, fetch: fetch) }
    }

    // MARK: Identity

    private var logo: some View {
        ZStack {
            // Company logos and product photos sit on white; our product icons fill their tile.
            if entity.type != "product" { Color.white }
            if let url = FindWebURL.resolve(entity.logoUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit().padding(entity.type == "product" ? 0 : 8)
                    } else {
                        Theme.surface2
                    }
                }
            } else {
                Text(String(entity.name.prefix(1))).font(Theme.font(24, weight: .bold)).foregroundStyle(Theme.muted)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metaLine: String {
        (overview?.meta ?? []).map(\.value).joined(separator: " · ")
    }

    // MARK: Video

    private var videos: [FindCardVideo] {
        (isExternal ? youtube?.videos : overview?.videos) ?? []
    }

    private var videosLoading: Bool {
        sections.isLoading("overview") || (isExternal && sections.isLoading("videos"))
    }

    @ViewBuilder
    private var videoBlock: some View {
        if videosLoading {
            EntitySkeleton(height: 200, radius: 22)
        } else if !videos.isEmpty || !isExternal {
            // Ours always have a player ("Video coming soon" until there's one); others' only with videos.
            EntityVideoPlayer(videos: videos, name: entity.name, logoUrl: entity.logoUrl)
        }
    }

    // MARK: Tiles and contacts

    /// Another company's market cap leads its tiles.
    private var tiles: [FindStatTile] {
        (market?.tile.map { [$0] } ?? []) + (overview?.tiles ?? [])
    }

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(tiles, id: \.self) { tile in
                VStack(alignment: .leading, spacing: 3) {
                    Text(tile.label).font(Theme.font(12)).foregroundStyle(Theme.muted)
                    Text(tile.value).font(Theme.font(20, weight: .bold)).foregroundStyle(Theme.text).lineLimit(2).minimumScaleFactor(0.8)
                    if let sub = tile.sub, !sub.isEmpty {
                        Text(sub).font(Theme.font(12)).foregroundStyle(Theme.muted).lineLimit(2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var contacts: [FindCardContact] {
        overview?.panel?.kind == "contact" ? overview?.panel?.contacts ?? [] : []
    }

    /// Call / Email / Directions (or Website) as three tiles.
    private var contactRow: some View {
        HStack(spacing: 10) {
            ForEach(contacts.prefix(3), id: \.self) { contact in
                if let url = URL(string: contact.url) {
                    Link(destination: url) {
                        VStack(spacing: 8) {
                            Image(systemName: contactIcon(contact.kind))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.blue, in: Circle())
                            Text(contact.label).font(Theme.font(14, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(contact.label), \(contact.value)")
                    .accessibilityIdentifier("find-contact-\(contact.kind)")
                }
            }
        }
    }

    private func contactIcon(_ kind: String) -> String {
        switch kind {
        case "call": return "phone.fill"
        case "email": return "envelope.fill"
        case "website": return "globe"
        default: return "mappin.and.ellipse"
        }
    }

    // MARK: Panel

    @ViewBuilder
    private func panelView(_ panel: FindCardPanel) -> some View {
        switch panel.kind {
        case "steps":
            EntityPanel(tone: "cyan") {
                EntityPanelLabel(text: panel.label)
                ForEach(Array((panel.steps ?? []).enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)").font(Theme.font(22, weight: .bold))
                        Text(step).font(Theme.font(15)).foregroundStyle(Theme.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case "prices":
            EntityPanel(tone: "cyan") {
                EntityPanelLabel(text: panel.label)
                ForEach(panel.prices ?? [], id: \.self) { price in
                    priceRow(price)
                }
                if let text = panel.text, !text.isEmpty {
                    Text(text).font(Theme.font(13)).opacity(0.85).fixedSize(horizontal: false, vertical: true)
                }
            }
        default:
            // The contacts are tiles of their own; another company's next earnings report gets the panel.
            if let next = market?.next {
                EntityPanel(tone: "cyan") {
                    EntityPanelLabel(text: next.label)
                    Text(next.title).font(Theme.font(22, weight: .bold))
                    Text(next.text).font(Theme.font(15)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func priceRow(_ price: FindStorePrice) -> some View {
        let row = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(price.store).font(Theme.font(15, weight: .bold)).foregroundStyle(Theme.text)
                Text(price.name).font(Theme.font(13)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            if price.lowest {
                Text("Lowest")
                    .font(Theme.font(12, weight: .bold))
                    .foregroundStyle(Theme.tGreenFg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.tGreen, in: Capsule())
            }
            Text(price.price)
                .font(Theme.font(price.lowest ? 22 : 18, weight: .bold))
                .foregroundStyle(price.lowest ? Theme.text : Theme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        return Group {
            if let url = URL(string: price.url) {
                Link(destination: url) { row }.buttonStyle(.plain)
            } else {
                row
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var disclosures: some View {
        if let chips = overview?.chips, !chips.items.isEmpty {
            EntityDisclosure(title: chips.title, preview: chips.items.joined(separator: ", ")) {
                EntityFlow(spacing: 8) {
                    ForEach(chips.items, id: \.self) { item in
                        Text(item)
                            .font(Theme.font(15, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Theme.bg, in: Capsule())
                    }
                }
                .padding(.top, 4)
            }
        }

        ForEach(overview?.lists ?? [], id: \.self) { list in
            EntityDisclosure(title: list.title, preview: list.rows.first?.name ?? "") {
                ForEach(list.rows, id: \.self) { row in namedRow(row) }
            }
        }

        if let groups = overview?.groups, !groups.isEmpty {
            EntityDisclosure(title: "Spaces", preview: "\(groups[0].name) · \(groups[0].products.map(\.name).joined(separator: ", "))") {
                ForEach(groups, id: \.self) { group in
                    EntityRow(name: group.name, sub: group.products.map(\.name).joined(separator: ", "))
                }
            }
        }

        if let usedBy = overview?.usedBy, !usedBy.isEmpty {
            EntityDisclosure(title: "Used by", preview: usedBy.map(\.name).joined(separator: ", ")) {
                ForEach(usedBy, id: \.self) { use in
                    EntityRow(name: use.name, sub: use.text, url: FindWebURL.resolve(use.url)?.absoluteString)
                }
            }
        }

        if let founder = overview?.founder {
            EntityDisclosure(title: "Founder", preview: founder.name) {
                EntityRow(name: founder.name, value: founder.linkedin != nil ? "LinkedIn" : nil, sub: founder.role, url: founder.linkedin)
            }
        }

        if !(overview?.more ?? []).isEmpty || !(overview?.faq ?? []).isEmpty {
            EntityDisclosure(title: overview?.faq?.isEmpty == false ? "Questions" : "About", preview: overview?.faq?.first?.q ?? overview?.more?.first?.title ?? "") {
                ForEach(overview?.more ?? [], id: \.self) { block in
                    EntityListTitle(text: block.title)
                    ForEach(block.rows ?? [], id: \.self) { row in namedRow(row) }
                    if let text = block.text, !text.isEmpty {
                        Text(text).font(Theme.font(15)).foregroundStyle(Theme.muted).padding(.top, 6).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let faq = overview?.faq, !faq.isEmpty {
                    EntityListTitle(text: "Questions")
                    ForEach(faq, id: \.self) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.q).font(Theme.font(15, weight: .bold)).foregroundStyle(Theme.text)
                            Text(item.a).font(Theme.font(15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    /// A row whose score is colored by how good it is (a product's reviews).
    private func namedRow(_ row: FindNamedRow) -> some View {
        let body = HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(Theme.font(15, weight: .semibold)).foregroundStyle(Theme.text)
                if let sub = row.sub, !sub.isEmpty {
                    Text(sub).font(Theme.font(13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let value = row.value, !value.isEmpty {
                Text(value).font(Theme.font(15, weight: .bold)).foregroundStyle(toneColor(row.tone)).multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.surface2).frame(height: 1) }

        return Group {
            if let url = row.url.flatMap(URL.init(string:)) {
                Link(destination: url) { body.contentShape(Rectangle()) }.buttonStyle(.plain)
            } else {
                body
            }
        }
    }

    private func toneColor(_ tone: String?) -> Color {
        switch tone {
        case "strong": return Theme.tGreenFg
        case "mixed": return Theme.tYellowFg
        case "weak": return Theme.tPinkFg
        default: return Theme.text
        }
    }

    // MARK: Actions

    private var actions: [EntityAction] {
        (overview?.actions ?? []).compactMap { action in
            EntityAction(action.shortLabel ?? action.label, systemImage: actionIcon(action.kind), url: FindWebURL.resolve(action.url)?.absoluteString)
        }
    }

    private func actionIcon(_ kind: String) -> String {
        switch kind {
        case "email": return "envelope.fill"
        case "products": return "square.grid.2x2"
        case "company": return "building.2"
        case "linkedin": return "person.crop.square"
        case "stock": return "chart.line.uptrend.xyaxis"
        case "news": return "newspaper"
        case "buy": return "cart.fill"
        case "compare": return "scalemass"
        default: return "arrow.up.right.square"
        }
    }
}

// MARK: Video player

/// Plays in the card, never on a new page (web: find-video-player): an MP4
/// in the system player, a YouTube link in YouTube's own embed. Several
/// videos get chips to switch between them; none shows "Video coming soon".
struct EntityVideoPlayer: View {
    let videos: [FindCardVideo]
    let name: String
    let logoUrl: String?
    @State private var index = 0
    @State private var isPlaying = false
    @Environment(\.colorScheme) private var colorScheme

    private var current: FindCardVideo? { videos.indices.contains(index) ? videos[index] : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Color(red: 0.047, green: 0.055, blue: 0.075)
                if let video = current {
                    if isPlaying {
                        playing(video)
                    } else {
                        poster(video)
                    }
                } else {
                    comingSoon
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityIdentifier("find-video")

            if videos.count > 1 { chips }
        }
    }

    @ViewBuilder
    private func playing(_ video: FindCardVideo) -> some View {
        if let id = Self.youtubeID(video.url) {
            YouTubeEmbedView(videoID: id).id(id)
        } else if let url = FindWebURL.resolve(sourceURL(video)) {
            InlineVideoView(url: url).id(url)
        }
    }

    private func poster(_ video: FindCardVideo) -> some View {
        Button {
            isPlaying = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let url = posterURL(video) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: .bottom)
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.06, green: 0.07, blue: 0.08))
                        .frame(width: 60, height: 60)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(video.title).font(Theme.font(16, weight: .bold)).lineLimit(2)
                        Text([video.sub, video.duration].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(Theme.font(12))
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(video.title)")
    }

    private var comingSoon: some View {
        VStack(spacing: 12) {
            if let url = FindWebURL.resolve(logoUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFit().padding(8) }
                }
                .frame(width: 64, height: 64)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text("Video coming soon").font(Theme.font(16, weight: .bold)).foregroundStyle(.white)
            Text(name).font(Theme.font(12)).foregroundStyle(.white.opacity(0.75))
        }
        .accessibilityElement(children: .combine)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(videos.enumerated()), id: \.offset) { offset, video in
                    Button {
                        index = offset
                        isPlaying = true
                    } label: {
                        Text(video.title)
                            .font(Theme.font(14, weight: .semibold))
                            .lineLimit(1)
                            .frame(maxWidth: 240)
                            .foregroundStyle(offset == index ? Theme.bg : Theme.text)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(offset == index ? Theme.text : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(offset == index ? .isSelected : [])
                }
            }
        }
    }

    private func sourceURL(_ video: FindCardVideo) -> String {
        colorScheme == .light ? video.urlLight ?? video.url : video.url
    }

    private func posterURL(_ video: FindCardVideo) -> URL? {
        let poster = colorScheme == .light ? video.posterLight ?? video.poster : video.poster
        if let url = FindWebURL.resolve(poster) { return url }
        return Self.youtubeID(video.url).flatMap { URL(string: "https://i.ytimg.com/vi/\($0)/hqdefault.jpg") }
    }

    static func youtubeID(_ url: String) -> String? {
        let pattern = #"(?:youtube\.com/(?:watch\?v=|embed/|shorts/)|youtu\.be/)([A-Za-z0-9_-]{11})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              let range = Range(match.range(at: 1), in: url) else { return nil }
        return String(url[range])
    }
}

/// An MP4 in the system player, started as soon as it shows.
private struct InlineVideoView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let player = AVPlayer(url: url)
                self.player = player
                player.play()
            }
            .onDisappear { player?.pause() }
    }
}

/// YouTube's embed, inline. The page is loaded with find.16ahead.com as its
/// origin: YouTube refuses to play an embed that has none.
private struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.isScrollEnabled = false
        // Built from the id alone, so only YouTube's own embed can load.
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}iframe{position:fixed;inset:0;width:100%;height:100%;border:0}</style></head>
        <body><iframe src="https://www.youtube.com/embed/\(videoID)?autoplay=1&playsinline=1&rel=0" allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen></iframe></body></html>
        """
        view.loadHTMLString(html, baseURL: FindWebURL.site)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}
}
