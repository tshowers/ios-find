import SwiftUI
import UIKit

// Mirrors the web app's CSS custom properties (--todd-panel-bg,
// --todd-panel-text, --todd-surface-2, etc. in src/styles.css), which swap
// between light/dark token sets based on prefers-color-scheme. Each Color
// here adapts live to the system appearance the same way.
enum Theme {
    static let background = adaptive(
        light: .white,
        dark: UIColor(red: 0.051, green: 0.067, blue: 0.090, alpha: 1)   // #0d1117
    )

    static let cardBackground = adaptive(
        light: .white,
        dark: UIColor(red: 0.075, green: 0.110, blue: 0.153, alpha: 1)   // #131c27
    )

    static let surface = adaptive(
        light: UIColor(red: 0.973, green: 0.973, blue: 0.973, alpha: 1), // #f8f8f8
        dark: UIColor(red: 0.102, green: 0.145, blue: 0.208, alpha: 1)   // #1a2535
    )

    static let text = adaptive(
        light: UIColor(red: 0.133, green: 0.133, blue: 0.133, alpha: 1), // #222
        dark: UIColor(red: 0.941, green: 0.965, blue: 1.0, alpha: 1)     // #f0f6ff
    )

    static let subtext = adaptive(
        light: UIColor(red: 0.333, green: 0.333, blue: 0.333, alpha: 1), // #555
        dark: UIColor(red: 0.545, green: 0.643, blue: 0.741, alpha: 1)   // #8ba4bd
    )

    static let border = adaptive(
        light: UIColor.black.withAlphaComponent(0.08),
        dark: UIColor(red: 0, green: 0.749, blue: 1.0, alpha: 0.12)      // rgba(0,191,255,.12)
    )

    static let placeholder = adaptive(
        light: UIColor(red: 0.467, green: 0.467, blue: 0.467, alpha: 1), // #777
        dark: UIColor(red: 0.369, green: 0.478, blue: 0.580, alpha: 1)   // #5e7a94
    )

    // Same value both modes, matching --tl-blue in the web app's styles.css.
    static let accent = Color(red: 0.0, green: 0.749, blue: 1.0)         // #00bfff

    // Quick-action tile colors, matching the web app's find-home.component.css
    // .find-quick-action--* rules exactly (same in both light and dark mode there).
    static let quickActionNews = Color(red: 0.937, green: 0.267, blue: 0.267)        // #ef4444
    static let quickActionWeather = Color(red: 0.086, green: 0.514, blue: 0.910)     // #1683e8
    static let quickActionSports = Color(red: 0.086, green: 0.655, blue: 0.396)      // #16a765
    static let quickActionConversion = Color(red: 0.486, green: 0.227, blue: 0.929)  // #7c3aed
    static let quickActionRestaurants = Color(red: 0.898, green: 0.608, blue: 0.031) // #e59b08
    static let quickActionEvents = Color(red: 0.031, green: 0.569, blue: 0.698)      // #0891b2

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
