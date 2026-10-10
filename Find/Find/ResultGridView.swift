import SwiftUI

/// All results (the "All" tab). Port of the web app's grid view in
/// find-home.component.html, built to web-products/find
/// design_handoff_find_grid_about_help. One card, four layouts by width,
/// with the same breakpoints as the web:
///   x-large (1200+)    4a  same card shape, tinted source plate
///   large (1000-1199)  4b  text first, 96pt thumbnail
///   medium (600-999)   4c  ranked list
///   phone (<600)       4d  one column, 72pt thumbnail
/// iPhone is always 4d; iPad picks by its current window width.
struct ResultGridView: View {
    let results: [FindRankedResult]
    let query: String
    let selectedIndex: Int
    let screenWidth: CGFloat
    let onBack: () -> Void
    let onOpen: (FindRankedResult) -> Void

    enum Layout {
        case plate, textFirst, ranked, phone

        init(width: CGFloat) {
            switch width {
            case 1200...: self = .plate
            case 1000..<1200: self = .textFirst
            case 600..<1000: self = .ranked
            default: self = .phone
            }
        }
    }

    private var layout: Layout { Layout(width: screenWidth) }

    private var columnCount: Int {
        switch layout {
        case .plate: return 4
        case .textFirst: return 3
        case .ranked, .phone: return 1
        }
    }

    private var sidePadding: CGFloat {
        switch layout {
        case .plate, .textFirst: return 40
        case .ranked: return 24
        case .phone: return 16
        }
    }

    private var gridSpacing: CGFloat {
        switch layout {
        case .plate: return 20
        case .textFirst: return 16
        case .ranked: return 8
        case .phone: return 10
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                if results.isEmpty {
                    Text("Run a search first.")
                        .font(Theme.font(15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    cards
                        .frame(maxWidth: 1360 - sidePadding * 2)
                        .padding(.horizontal, sidePadding)
                        .padding(.top, layout == .phone ? 6 : 20)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 150)
                }
            }
        }
        .background(Theme.bg)
    }

    // MARK: Header

    /// Phone: 44pt back circle and "N found". Wider: the pager pill with
    /// "Back / To result N" and "N found for <query>".
    private var header: some View {
        let isPhone = layout == .phone
        return HStack(spacing: 16) {
            Button(action: onBack) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .frame(width: isPhone ? 44 : 38, height: isPhone ? 44 : 38)
                        .background(isPhone ? Theme.surface : Theme.bg, in: Circle())
                    if !isPhone {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Back").font(Theme.font(12)).foregroundStyle(Theme.muted)
                            Text("To result \(selectedIndex + 1)").font(Theme.font(14, weight: .semibold)).foregroundStyle(Theme.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to result \(selectedIndex + 1)")

            Group {
                if isPhone {
                    Text("\(results.count) found")
                        .font(Theme.font(15, weight: .semibold))
                        .foregroundStyle(Theme.text)
                } else {
                    (Text("\(results.count) found").bold().foregroundStyle(Theme.text)
                        + Text(" for \(query)").foregroundStyle(Theme.muted))
                        .font(Theme.font(14))
                }
            }
            .lineLimit(1)
            .layoutPriority(1)

            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
        .padding(isPhone ? 0 : 6)
        .background {
            if !isPhone { Capsule().fill(Theme.surface) }
        }
        .frame(maxWidth: 1360 - sidePadding * 2)
        .padding(.horizontal, sidePadding)
        .padding(.top, isPhone ? 4 : 16)
        .padding(.bottom, isPhone ? 10 : 0)
        .frame(maxWidth: .infinity)
        .background(Theme.bg)
    }

    // MARK: Cards

    @ViewBuilder
    private var cards: some View {
        if columnCount == 1 {
            LazyVStack(spacing: gridSpacing) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    card(result, index: index)
                }
            }
        } else {
            // Grid (not LazyVGrid) so every card in a row ends at the same height.
            Grid(horizontalSpacing: gridSpacing, verticalSpacing: gridSpacing) {
                ForEach(rowStarts, id: \.self) { start in
                    GridRow(alignment: .top) {
                        ForEach(start..<min(start + columnCount, results.count), id: \.self) { index in
                            card(results[index], index: index)
                                .frame(maxHeight: .infinity, alignment: .top)
                        }
                        // Fill a short last row so cards keep their column width.
                        ForEach(0..<max(0, start + columnCount - results.count), id: \.self) { _ in
                            Color.clear.gridCellUnsizedAxes(.vertical)
                        }
                    }
                }
            }
        }
    }

    private var rowStarts: [Int] {
        Array(stride(from: 0, to: results.count, by: columnCount))
    }

    private func card(_ result: FindRankedResult, index: Int) -> some View {
        Button {
            onOpen(result)
        } label: {
            GridCard(result: result, query: query, index: index, isCurrent: index == selectedIndex, layout: layout)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card

private struct GridCard: View {
    let result: FindRankedResult
    let query: String
    let index: Int
    let isCurrent: Bool
    let layout: ResultGridView.Layout

    @State private var imageFailed = false

    private var imageURL: URL? {
        guard !result.imageUrl.isEmpty, !imageFailed else { return nil }
        return URL(string: result.imageUrl)
    }

    private var rank: String { String(format: "%02d", index + 1) }

    var body: some View {
        switch layout {
        case .plate: plateCard
        case .textFirst, .phone: textFirstCard
        case .ranked: rankedRow
        }
    }

    // 4a: media on top (image, or a tinted plate naming the source).
    private var plateCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay {
                    if let imageURL {
                        image(imageURL)
                    } else {
                        sourcePlate
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("#\(index + 1)").font(Theme.font(12, weight: .bold)).foregroundStyle(Theme.text)
                    domain
                    Spacer(minLength: 0)
                    if isCurrent { currentTag }
                }
                title(size: 17, lines: 2)
                summary(size: 14, lines: 3)
                Spacer(minLength: 0)
                contact
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 18)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { currentRing }
    }

    private var sourcePlate: some View {
        let tint = SourceTint(domain: result.displayUrl)
        return VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            if let kind = sourceKind {
                Text(kind).font(Theme.font(13, weight: .bold)).opacity(0.8)
            }
            Text(result.displayUrl)
                .font(Theme.font(26, weight: .bold))
                .tracking(-0.5)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(tint.foreground)
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .background(tint.background)
    }

    // 4b / 4d: text first, thumbnail on the right when there's an image.
    private var textFirstCard: some View {
        let isPhone = layout == .phone
        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if isPhone {
                        Text(rank).font(Theme.font(12, weight: .bold)).foregroundStyle(Theme.text)
                    } else {
                        Text(rank)
                            .font(Theme.font(11, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 26, height: 26)
                            .background(Theme.bg, in: Circle())
                    }
                    domain
                    if isCurrent { currentTag }
                }
                title(size: isPhone ? 16 : 18, lines: 2)
                summary(size: isPhone ? 13 : 14, lines: isPhone ? 2 : 4)
                contact
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let imageURL {
                let side: CGFloat = isPhone ? 72 : 96
                image(imageURL)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: isPhone ? 14 : 16, style: .continuous))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { currentRing }
    }

    // 4c: big rank, body, optional thumbnail. The current row is tinted.
    private var rankedRow: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(rank)
                .font(Theme.font(28, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.muted)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    domain
                    if isCurrent { currentTag }
                }
                title(size: 18, lines: nil)
                summary(size: 14, lines: 2)
                contact
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let imageURL {
                image(imageURL)
                    .frame(width: 132, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(isCurrent ? Theme.tBlue : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }

    // MARK: Pieces

    private var domain: some View {
        Text(result.displayUrl)
            .font(Theme.font(12))
            .foregroundStyle(Theme.muted)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private var currentTag: some View {
        Text("Current")
            .font(Theme.font(12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.blue, in: Capsule())
            .fixedSize()
    }

    @ViewBuilder
    private var currentRing: some View {
        if isCurrent {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.blue, lineWidth: 3)
        }
    }

    private func title(size: CGFloat, lines: Int?) -> some View {
        Text(highlighted(result.title, query: query))
            .font(Theme.font(size, weight: .bold))
            .foregroundStyle(Theme.text)
            .lineSpacing(1)
            .multilineTextAlignment(.leading)
            .lineLimit(lines)
    }

    @ViewBuilder
    private func summary(size: CGFloat, lines: Int) -> some View {
        if !result.summary.isEmpty {
            Text(highlighted(result.summary, query: query))
                .font(Theme.font(size))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .lineLimit(lines)
        }
    }

    @ViewBuilder
    private var contact: some View {
        let address = result.address ?? ""
        let phone = result.phone ?? ""
        // A place's distance ("0.5 mi") arrives as a pill, as on the web
        // (cardDistance in find-home.component.ts).
        let distance = result.pills.first { $0.range(of: #"^\d+(\.\d+)?\s*mi$"#, options: .regularExpression) != nil } ?? ""
        if !address.isEmpty || !phone.isEmpty || !distance.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if !address.isEmpty || !distance.isEmpty {
                    Text(address.isEmpty ? distance : distance.isEmpty ? address : "\(address) · \(distance)")
                }
                if !phone.isEmpty { Text(phone).fontWeight(.semibold) }
            }
            .font(Theme.font(13))
            .foregroundStyle(Theme.text)
        }
    }

    private func image(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                // A broken image switches the card to its no-image layout.
                Theme.surface2.onAppear { imageFailed = true }
            default:
                Theme.surface2
            }
        }
    }

    /// Kind label on a source plate; publisher results have none.
    private var sourceKind: String? {
        if !(result.address ?? "").isEmpty || !(result.phone ?? "").isEmpty { return "Local business" }
        switch result.sourceType {
        case .encyclopedia: return "Encyclopedia"
        case .medical: return "Health"
        case .government: return "Government"
        case .academic: return "Academic"
        case .official: return "Official site"
        default: return nil
        }
    }
}

/// The domain hashed into one of six tints, so a site always gets the same
/// plate colour. Same hash as sourceTint() in find-home.component.ts.
private struct SourceTint {
    let background: Color
    let foreground: Color

    init(domain: String) {
        let pairs: [(Color, Color)] = [
            (Theme.tBlue, Theme.tBlueFg),
            (Theme.tCyan, Theme.tCyanFg),
            (Theme.tPink, Theme.tPinkFg),
            (Theme.tViolet, Theme.tVioletFg),
            (Theme.tYellow, Theme.tYellowFg),
            (Theme.tGreen, Theme.tGreenFg),
        ]
        var hash: UInt32 = 0
        for unit in domain.lowercased().utf16 {
            hash = hash &* 31 &+ UInt32(unit)
        }
        (background, foreground) = pairs[Int(hash % UInt32(pairs.count))]
    }
}
