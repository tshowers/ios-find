//
//  FindApp.swift
//  Find
//
//  Created by Ty Showers on 7/16/26.
//

import SwiftUI

@main
struct FindApp: App {
    private let apiClient = FindAPIClient(config: .fromBundle())

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SearchView(viewModel: SearchViewModel(apiClient: apiClient))
            }
        }
    }
}
