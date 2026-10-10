import SwiftUI

/// Company details shown on the Info screen. Mirrors MENU_COMPANY in
/// taliferro-ui/platform/universal-menu.model.ts, which the web app reads
/// directly; keep the two in step.
enum TaliferroCompany {
    static let name = "Taliferro Tech"
    static let legalName = "Taliferro Tech, LLC"
    static let url = URL(string: "https://taliferro.tech")!
    static let email = "support@taliferro.tech"
    static let links: [(label: String, url: URL)] = [
        ("Terms & Conditions", URL(string: "https://taliferro.tech/terms")!),
        ("Privacy Rights", URL(string: "https://taliferro.tech/privacy-rights")!),
        ("Privacy Policy", URL(string: "https://taliferro.tech/privacy")!),
        ("Careers", URL(string: "https://taliferro.tech/careers")!),
    ]
}

/// A row of small links that wraps onto as many centred lines as it needs.
struct FlowLinks: View {
    let links: [(label: String, url: URL)]

    var body: some View {
        FlowLayout(spacing: 16, lineSpacing: 6) {
            ForEach(links, id: \.label) { link in
                Link(link.label, destination: link.url)
            }
        }
        .font(Theme.font(13))
        .foregroundStyle(Theme.subtext)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var lines: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        var current: (indices: [Int], width: CGFloat, height: CGFloat) = ([], 0, 0)
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                lines.append(current)
                current = ([index], size.width, size.height)
            } else {
                current = (current.indices + [index], needed, max(current.height, size.height))
            }
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}
