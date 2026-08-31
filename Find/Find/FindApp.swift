//
//  FindApp.swift
//  Find
//
//  Created by Ty Showers on 7/16/26.
//

import SwiftUI

@main
struct FindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let apiClient = FindAPIClient(config: .fromBundle())

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SearchView(viewModel: SearchViewModel(apiClient: apiClient))
            }
            // Every screen is a fixed-pixel custom layout (circular tab
            // icons, precise card grids) rather than adaptive/reflowing text
            // layouts, and SF Symbols + system fonts still scale with the
            // user's accessibility text-size setting even at a fixed point
            // size unless pinned. At larger accessibility sizes that blew
            // the tab bar icons up into overlapping blobs. Locking to the
            // standard size doesn't add real large-text support - it just
            // stops the app from breaking for those users; true support
            // would need each screen redesigned to reflow.
            .dynamicTypeSize(.large)
        }
    }
}
