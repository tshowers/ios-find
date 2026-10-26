import StoreKit
import UIKit

/// Asks for an App Store rating once someone has had enough good searches.
/// iOS decides whether the prompt actually shows (at most 3 times a year, never
/// in TestFlight), so this asks at most once per app version, then starts the
/// count over. The same helper lives in Taliferro Music.
@MainActor
enum AppReview {
    static let appStoreID = "6806954591"

    /// Opens the App Store's review form - the "Rate Find" card in Info. Unlike
    /// the prompt, iOS doesn't limit this.
    static let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!

    private static let countKey = "find.review.count"
    private static let daysKey = "find.review.days"
    private static let askedVersionKey = "find.review.askedVersion"

    /// Records one good moment. Once there have been `threshold` of them across
    /// `minDays` different days, asks for a rating a moment later (so the
    /// result shows first) - unless `canAsk` is false, in which case the next
    /// good moment tries again.
    static func recordSuccess(threshold: Int, minDays: Int = 1, canAsk: Bool = true) {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: countKey) + 1
        defaults.set(count, forKey: countKey)

        var days = defaults.stringArray(forKey: daysKey) ?? []
        if days.count < minDays, !days.contains(today) {
            days.append(today)
            defaults.set(days, forKey: daysKey)
        }

        guard canAsk, count >= threshold, days.count >= minDays,
              defaults.string(forKey: askedVersionKey) != appVersion else { return }

        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            // Background audio keeps Music counting with the screen locked; the
            // prompt can only show in the foreground, so wait for a later moment.
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }

            defaults.set(appVersion, forKey: askedVersionKey)
            defaults.set(0, forKey: countKey)
            defaults.removeObject(forKey: daysKey)
            AppStore.requestReview(in: scene)
        }
    }

    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private static var today: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
