import SwiftUI

// Mirrors the web app's award-badge component: a fixed dark-navy/cyan
// "app icon" tile with a circuit-trace ring and a glowing center symbol,
// deliberately NOT theme-reactive (same fixed palette in light/dark mode) -
// these read as siblings of the static TODD icon assets (Network, Pulse,
// Outreach), not as adaptive UI chrome.
struct AwardBadgeView: View {
    let icon: FindAwardIcon
    let state: FindAwardState
    var size: CGFloat = 76

    private var radius: CGFloat { size * 0.25 }
    private var ringDiameter: CGFloat { size * 0.46 }
    private var nodeRadius: CGFloat { size * 0.028 }
    private var iconSize: CGFloat { size * 0.30 }

    var body: some View {
        ZStack {
            background

            if state == .unlocked {
                sheen
            }

            if state != .mystery {
                ring
                nodes
                centerIcon
            } else {
                mysteryRing
                Text("?")
                    .font(.system(size: size * 0.27, weight: .bold))
                    .foregroundStyle(Color(hex: 0x384049))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(state == .mystery ? Color(hex: 0x2C343C) : .clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
    }

    // MARK: - Background

    @ViewBuilder private var background: some View {
        switch state {
        case .unlocked:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x234A67), Color(hex: 0x0C1826), Color(hex: 0x060C14)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: Color(hex: 0x7FB3D8).opacity(0.32), radius: size * 0.16)
        case .locked:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: 0x232B33), Color(hex: 0x161C22)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        case .mystery:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(hex: 0x1B222A), Color(hex: 0x10141A)],
                    center: UnitPoint(x: 0.5, y: 0.32), startRadius: 0, endRadius: size * 0.75
                ))
        }
    }

    private var sheen: some View {
        RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
            .fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
            .frame(width: size * 0.76, height: size * 0.36)
            .offset(y: -size * 0.28)
    }

    // MARK: - Ring, nodes, accent dot

    private var ringColor: Color {
        state == .unlocked ? Color(hex: 0x7FB3D8) : Color(hex: 0x4A5560)
    }

    private var ring: some View {
        Circle()
            .strokeBorder(ringColor, style: StrokeStyle(lineWidth: size * 0.021, lineCap: .round, dash: [size * 0.10, size * 0.03, size * 0.19, size * 0.03]))
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var mysteryRing: some View {
        Circle()
            .strokeBorder(Color(hex: 0x2C343C).opacity(0.7), style: StrokeStyle(lineWidth: size * 0.016, dash: [size * 0.013, size * 0.026]))
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var nodes: some View {
        let r = ringDiameter / 2
        let nodeStroke = state == .unlocked ? Color(hex: 0xA9E0FF) : Color(hex: 0x4A5560)
        let nodeFill = state == .unlocked ? Color(hex: 0x0D1620) : Color(hex: 0x171C22)
        let accent = Color(hex: 0x8FD4FF)
        let accentLocked = Color(hex: 0x3A4450)

        return ZStack {
            Circle()
                .fill(nodeFill)
                .overlay(Circle().strokeBorder(nodeStroke, lineWidth: size * 0.017))
                .frame(width: nodeRadius * 2, height: nodeRadius * 2)
                .offset(y: -r)

            Circle()
                .fill(nodeFill)
                .overlay(Circle().strokeBorder(nodeStroke, lineWidth: size * 0.017))
                .frame(width: nodeRadius * 2, height: nodeRadius * 2)
                .offset(x: -r)

            Circle()
                .fill(state == .unlocked ? accent : accentLocked)
                .frame(width: nodeRadius * 2.2, height: nodeRadius * 2.2)
                .offset(x: r * 0.707, y: r * 0.707)
        }
    }

    // MARK: - Center symbol

    private var iconColor: Color {
        state == .unlocked ? Color(hex: 0xA9E0FF) : Color(hex: 0x525F6A)
    }

    @ViewBuilder private var centerIcon: some View {
        Group {
            if icon == .connector {
                ConnectorGlyph(color: iconColor, size: iconSize)
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
        }
        .shadow(color: state == .unlocked ? Color(hex: 0x8FD4FF).opacity(0.55) : .clear, radius: size * 0.06)
    }

    private var symbolName: String {
        switch icon {
        case .rebel: return "magnifyingglass"
        case .curious: return "lightbulb.fill"
        case .nightOwl: return "moon.stars.fill"
        case .earlyBird: return "sunrise.fill"
        case .connector: return "circle.grid.3x3.fill" // unused - ConnectorGlyph draws this one
        case .sharpEye: return "eye.fill"
        case .explorer: return "safari"
        case .specialist: return "diamond.fill"
        case .relentless: return "bolt.fill"
        case .tastemaker: return "star.fill"
        case .legend: return "questionmark"
        }
    }
}

/// The one icon without a good SF Symbol equivalent - three linked nodes,
/// matching the web badge's hand-drawn triangle-of-circuit-nodes exactly.
private struct ConnectorGlyph: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let top = CGPoint(x: w * 0.5, y: h * 0.08)
            let left = CGPoint(x: w * 0.06, y: h * 0.86)
            let right = CGPoint(x: w * 0.94, y: h * 0.86)
            let dotRadius = w * 0.11

            var lines = Path()
            lines.move(to: top); lines.addLine(to: left)
            lines.move(to: top); lines.addLine(to: right)
            lines.move(to: left); lines.addLine(to: right)
            context.stroke(lines, with: .color(color), style: StrokeStyle(lineWidth: w * 0.09, lineCap: .round))

            for point in [top, left, right] {
                let dot = Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
                context.stroke(dot, with: .color(color), lineWidth: w * 0.07)
            }
        }
        .frame(width: size, height: size)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

#Preview {
    HStack(spacing: 16) {
        AwardBadgeView(icon: .rebel, state: .unlocked, size: 90)
        AwardBadgeView(icon: .connector, state: .unlocked, size: 90)
        AwardBadgeView(icon: .sharpEye, state: .locked, size: 90)
        AwardBadgeView(icon: .legend, state: .mystery, size: 90)
    }
    .padding()
    .background(Color.black)
}
