import SwiftUI
import UIKit

// Find's design tokens - logo colours on white / near-black, following the
// system appearance. Mirrors the web app's find-home.component.css tokens
// (see web-products/find docs/design_handoff_find_results/README.md).
// The older names (background, surface, subtext, accent, ...) are kept and
// pointed at the new palette so every screen picks it up.
enum Theme {
    // MARK: Core tokens

    static let bg = adaptive(light: 0xffffff, dark: 0x0c0e13)
    static let surface = adaptive(light: 0xf2f3f6, dark: 0x171a22)
    static let surface2 = adaptive(light: 0xe4e7ed, dark: 0x242936)
    static let text = adaptive(light: 0x0f1115, dark: 0xf2f4f8)
    static let muted = adaptive(light: 0x5a6170, dark: 0x9aa2b2)
    static let blue = adaptive(light: 0x2f6bff, dark: 0x3d7bff)
    static let blueInk = adaptive(light: 0x1f55e0, dark: 0x86aeff)

    // Logo colours: progress segments, weather icons, range bars.
    static let cyan = Color(hex: 0x1fc8ec)
    static let yellow = Color(hex: 0xffd92e)
    static let pink = Color(hex: 0xff4fa8)
    static let violet = Color(hex: 0xa259ff)
    static let logoColors: [Color] = [blue, cyan, yellow, pink, violet]

    // Tinted pairs (background / foreground).
    static let tBlue = adaptive(light: 0xe3ecff, dark: 0x15254a)
    static let tBlueFg = adaptive(light: 0x1d4fd6, dark: 0xa3c1ff)
    static let tCyan = adaptive(light: 0xdaf6fc, dark: 0x0c2d35)
    static let tCyanFg = adaptive(light: 0x08657d, dark: 0x74e4f8)
    static let tPink = adaptive(light: 0xffe3f1, dark: 0x3a1029)
    static let tPinkFg = adaptive(light: 0xa8105a, dark: 0xff92c9)
    static let tViolet = adaptive(light: 0xefe5ff, dark: 0x2a1847)
    static let tVioletFg = adaptive(light: 0x6427c9, dark: 0xcdaaff)
    static let tYellow = adaptive(light: 0xfff4c2, dark: 0x2f2906)
    static let tYellowFg = adaptive(light: 0x6e5700, dark: 0xffe56a)
    static let tGreen = adaptive(light: 0xe0f6e6, dark: 0x0e2c19)
    static let tGreenFg = adaptive(light: 0x17703a, dark: 0x80e2a4)

    // MARK: Older names, pointed at the new palette

    static let background = bg
    static let cardBackground = bg
    static let subtext = muted
    static let border = surface2
    static let placeholder = muted
    static let accent = blue
    static let hairline = surface2
    /// Behind the grid header, context strip, and tab bar.
    static let chrome = bg

    // Query terms in the Grid stay red, as in the original release.
    static let highlightRed = adaptive(light: 0xd0021b, dark: 0xff5a5f)

    // MARK: Type

    /// Helvetica Neue everywhere, at a fixed size (the app pins Dynamic Type).
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", fixedSize: size).weight(weight)
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xff) / 255,
            green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255,
            alpha: 1
        )
    }
}
