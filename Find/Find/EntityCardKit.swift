import SwiftUI
import Combine

// The pieces every single-item card is built from (web: the shared "ec-"
// styles in find-entity-card.component.css, iPhone layout "B"): a status
// pill, a hero image, the name row, stat chips, the 16Ahead summary,
// collapsible sections, four action tiles and "More results". Sizes and
// tints follow design_handoff_find_single_results (rounds 4 and 5).

// MARK: Loading, section by section

/// One card's sections. Each loads on its own, so the card fills in as they
/// arrive: loading shows a placeholder, missing hides the piece.
@MainActor
final class EntitySections: ObservableObject {
    enum State {
        case loading
        case missing
        case loaded(Data)
    }

    @Published private(set) var states: [String: State] = [:]
    private let decoder = JSONDecoder()

    func load(_ sections: [String], fetch: @escaping @Sendable (String) async -> Data?) async {
        states = Dictionary(uniqueKeysWithValues: sections.map { ($0, State.loading) })
        await withTaskGroup(of: (String, Data?).self) { group in
            for section in sections {
                group.addTask { (section, await fetch(section)) }
            }
            for await (section, data) in group {
                states[section] = data.map(State.loaded) ?? .missing
            }
        }
    }

    /// Fetches one section again, keeping what's shown if the refresh fails
    /// (a live score refreshing every 30 s).
    func refresh(_ section: String, fetch: @escaping @Sendable (String) async -> Data?) async {
        if let data = await fetch(section) { states[section] = .loaded(data) }
    }

    func isLoading(_ section: String) -> Bool {
        if case .loading = states[section] ?? .loading { return true }
        return false
    }

    func value<T: Decodable>(_ section: String, as type: T.Type) -> T? {
        guard case .loaded(let data) = states[section] else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

// MARK: Tints

enum EntityTone {
    static func colors(_ tone: String) -> (background: Color, foreground: Color) {
        switch tone {
        case "blue": return (Theme.tBlue, Theme.tBlueFg)
        case "green": return (Theme.tGreen, Theme.tGreenFg)
        case "cyan": return (Theme.tCyan, Theme.tCyanFg)
        case "pink": return (Theme.tPink, Theme.tPinkFg)
        case "violet": return (Theme.tViolet, Theme.tVioletFg)
        case "yellow": return (Theme.tYellow, Theme.tYellowFg)
        default: return (Theme.surface, Theme.text)
        }
    }
}

// MARK: Pieces

struct EntityTagChips: View {
    let tags: [FindEntityTag]

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    let colors = EntityTone.colors(tag.tone)
                    Text(tag.text)
                        .font(Theme.font(13, weight: .semibold))
                        .foregroundStyle(colors.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(colors.background, in: Capsule())
                }
            }
        }
    }
}

/// "● Live · Q3 8:42", "● Open now · until 9 PM", "● 10:12 AM in Tokyo".
struct EntityStatusPill: View {
    let text: String
    let tone: String

    var body: some View {
        let colors = EntityTone.colors(tone)
        HStack(spacing: 8) {
            Circle().fill(colors.foreground).frame(width: 8, height: 8)
            Text(text).font(Theme.font(14, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(colors.foreground)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 7)
        .background(colors.background, in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EntityHeroImage: View {
    let url: String?
    var height: CGFloat = 200
    /// A map is shown whole on a plain background, not cropped.
    var fit = false

    var body: some View {
        if let url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    if fit {
                        image.resizable().scaledToFit().padding(12)
                    } else {
                        image.resizable().scaledToFill()
                    }
                case .failure:
                    Color.clear
                default:
                    Theme.surface
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

/// The square (or poster-shaped) picture beside the name; the first letter when there's none.
struct EntityThumb: View {
    let url: String?
    let fallback: String
    var width: CGFloat = 56
    var height: CGFloat = 56
    var fill = false

    var body: some View {
        ZStack {
            Theme.surface2
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if case .success(let image) = phase {
                        if fill {
                            image.resizable().scaledToFill()
                        } else {
                            image.resizable().scaledToFit().padding(width * 0.1)
                        }
                    } else {
                        initial
                    }
                }
            } else {
                initial
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: fill ? 14 : 16, style: .continuous))
    }

    private var initial: some View {
        Text(String(fallback.prefix(1)))
            .font(Theme.font(24, weight: .bold))
            .foregroundStyle(Theme.muted)
    }
}

struct EntityIdentityRow<Thumb: View>: View {
    let name: String
    let meta: String
    @ViewBuilder let thumb: () -> Thumb

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            thumb()
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(Theme.font(26, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if !meta.isEmpty {
                    Text(meta)
                        .font(Theme.font(14))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// "123.8M people", "JPY ¥157.3 = $1": bold value, plain label.
struct EntityKeyFacts: View {
    let facts: [FindKeyFact]

    var body: some View {
        if !facts.isEmpty {
            EntityFlow(spacing: 8) {
                ForEach(facts, id: \.self) { fact in
                    (Text(fact.value).font(Theme.font(15, weight: .bold)) + Text(fact.label.isEmpty ? "" : " \(fact.label)").font(Theme.font(15)))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(Theme.surface2, lineWidth: 1.5))
                }
            }
        }
    }
}

struct EntitySummaryBlock: View {
    let summary: FindEntitySummary?
    let isLoading: Bool

    var body: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image("SixteenAheadMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("16Ahead summary").font(Theme.font(13, weight: .bold))
                    if let sources = summary.sources, !sources.isEmpty {
                        Text("· \(sources.joined(separator: ", "))")
                            .font(Theme.font(13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Text(summary.text)
                    .font(Theme.font(15))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if isLoading {
            EntitySkeleton(height: 110)
        }
    }
}

/// A tinted panel (the round-4 "now" tile, the round-5 feature panel).
struct EntityPanel<Content: View>: View {
    let tone: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        let colors = EntityTone.colors(tone)
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .foregroundStyle(colors.foreground)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct EntityPanelLabel: View {
    let text: String
    var body: some View { Text(text).font(Theme.font(13, weight: .bold)) }
}

struct EntityPanelDivider: View {
    // A shape fills with the panel's foreground colour.
    var body: some View { Rectangle().frame(height: 1.5).opacity(0.9) }
}

/// One collapsible section: title, a one-line preview, a chevron.
struct EntityDisclosure<Content: View>: View {
    let title: String
    let preview: String
    @ViewBuilder let content: () -> Content
    @State private var isOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Text(title).font(Theme.font(15, weight: .bold)).foregroundStyle(Theme.text)
                    Text(preview)
                        .font(Theme.font(14))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOpen ? .isSelected : [])

            if isOpen {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// Name left (bold), value right (bold), an optional muted line under the name.
struct EntityRow: View {
    let name: String
    var value: String? = nil
    var sub: String? = nil
    var url: String? = nil
    var highlight = false

    var body: some View {
        let row = HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(Theme.font(15, weight: highlight ? .heavy : .semibold))
                    .foregroundStyle(highlight ? Theme.blueInk : Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub, !sub.isEmpty {
                    Text(sub).font(Theme.font(13)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let value, !value.isEmpty {
                Text(value).font(Theme.font(15, weight: .bold)).foregroundStyle(Theme.text).multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Rectangle().fill(Theme.surface2).frame(height: 1) }

        if let url, let link = URL(string: url) {
            Link(destination: link) { row.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else {
            row
        }
    }
}

struct EntityRows: View {
    let rows: [FindListRow]

    var body: some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            EntityRow(name: row.name, value: row.value, sub: row.sub, url: row.url)
        }
    }
}

struct EntityListTitle: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.font(12, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(Theme.muted)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

struct EntityAction: Identifiable {
    let label: String
    let systemImage: String
    let url: URL?
    var run: (() -> Void)? = nil
    var id: String { label }

    init?(_ label: String, systemImage: String, url: String?) {
        guard let url, let link = URL(string: url), !url.isEmpty else { return nil }
        self.label = label
        self.systemImage = systemImage
        self.url = link
    }

    /// An action Find runs itself ("Convert USD to JPY" searches for it).
    init(_ label: String, systemImage: String, run: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.url = nil
        self.run = run
    }
}

/// Up to four 64pt tiles, the first one blue.
struct EntityActionTiles: View {
    let actions: [EntityAction]
    @Environment(\.openURL) private var openURL

    var body: some View {
        if !actions.isEmpty {
            HStack(spacing: 10) {
                ForEach(Array(actions.prefix(4).enumerated()), id: \.element.id) { index, action in
                    Button {
                        if let run = action.run { run() } else if let url = action.url { openURL(url) }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: action.systemImage).font(.system(size: 19, weight: .semibold))
                            Text(action.label).font(Theme.font(12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(index == 0 ? .white : Theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(index == 0 ? Theme.blue : Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// "More results for "seattle" · 16 ›": swaps the card for the usual results.
struct EntityMoreButton: View {
    let query: String
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("More results for “\(query)”").font(Theme.font(16, weight: .bold)).lineLimit(1)
                if let count, count > 0 {
                    Text("· \(count)").font(Theme.font(16, weight: .semibold)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Theme.bg, in: Circle())
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("find-entity-more")
    }
}

struct EntitySkeleton: View {
    var height: CGFloat = 50
    var radius: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.surface)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .redacted(reason: .placeholder)
    }
}

/// Wraps chips onto as many lines as they need.
struct EntityFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// The card's tiles as rows inside a collapsible section.
struct EntityTileRows: View {
    let tiles: [FindStatTile]

    var body: some View {
        ForEach(tiles, id: \.self) { tile in
            EntityRow(name: tile.label, value: tile.value, sub: tile.sub)
        }
    }
}
