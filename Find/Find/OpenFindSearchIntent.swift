import AppIntents
import Foundation

extension Notification.Name {
    /// OpenFindSearchIntent opened the app; SearchView starts a new search.
    static let findOpenNewSearch = Notification.Name("findOpenNewSearch")
}

/// Opens Find to a new search with the keyboard up. Run by the "Search with
/// Find" control (Control Center, Lock Screen, Action button), which lives in
/// FindWidgetExtension, so this file is compiled into both targets;
/// openAppWhenRun makes perform() run in the app.
struct OpenFindSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Search with Find"
    static var description = IntentDescription("Opens Find ready to search.")
    static var openAppWhenRun = true

    /// Set by perform() and consumed by SearchView, which may not be on
    /// screen yet on a cold launch (same as AppDelegate.pendingWatchQuery).
    @MainActor static var pending = false

    @MainActor
    func perform() async throws -> some IntentResult {
        Self.pending = true
        NotificationCenter.default.post(name: .findOpenNewSearch, object: nil)
        return .result()
    }
}
