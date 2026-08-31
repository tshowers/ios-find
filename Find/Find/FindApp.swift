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
            // The UI is a fixed light design (white backgrounds, black text)
            // with no dark-mode variants, so system-adaptive controls like
            // TextField's default text color silently turned white in dark
            // mode while its background stayed hardcoded white - invisible
            // typed text. Force light appearance app-wide instead of hunting
            // down every adaptive color individually.
            .preferredColorScheme(.light)
        }
    }
}
