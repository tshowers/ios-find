import AppIntents
import SwiftUI
import WidgetKit

/// "Search with Find" for Control Center, the Lock Screen and the Action
/// button (iOS 18): opens Find to a new search with the keyboard up.
@available(iOS 18.0, *)
struct FindSearchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "FindSearchControl") {
            ControlWidgetButton(action: OpenFindSearchIntent()) {
                Label("Find", systemImage: "magnifyingglass")
            }
        }
        .displayName("Search with Find")
        .description("Opens Find ready to type.")
    }
}
