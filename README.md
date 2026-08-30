![Find iOS](docs/find-ios-banner.png)

Native SwiftUI client for [Find](https://find.taliferro.tech) — a free,
no-account-required search experience that hands you one strong result
instead of a page of ten blue links. Companion to the
[web app](https://github.com/tshowers/find).

## Structure

```
Find/
  App/            App entry point (FindApp.swift)
  Models/         Codable response models (FindModels.swift, AboutModels.swift)
  Services/       AppConfig, FindAPIClient
  SearchView.swift, SearchViewModel.swift, ShareSheet.swift
  Assets.xcassets Asset catalog (app icon, accent color, Find logo)
  PrivacyInfo.xcprivacy
```

Bundle ID: `tech.taliferro.Find`.

## Setup

Open `Find.xcodeproj` directly in Xcode — the project uses Xcode's
file-system-synchronized groups, so any file dropped into `Find/Find/`
is picked up automatically.

Before running on a device, set your own signing team in the target's
Signing & Capabilities tab (or edit `DEVELOPMENT_TEAM` in
`project.pbxproj`).

## Configuration

The app reads `FIND_API_BASE_URL` from the bundle (see `AppConfig.swift`),
currently pointed at the shared Taliferro Tech backend
(`https://api.taliferro.tech/api`) — the same endpoints
(`POST /find/search`, `POST /find/summarize`) the web app calls.

## Features

- Search, single-strongest-result view, swipe between alternatives
- Context pills & drill-down
- Grid view of all candidate results
- Search history
- About screen with a "More from Taliferro Tech" / "Momentum system"
  product grid, linking out to the rest of the TODD product family
- Share sheet for the current result

## For ad-hoc export builds

Copy `ExportOptions-AdHoc.plist.example` to `ExportOptions-AdHoc.plist`
and fill in your own Apple Developer Team ID (gitignored — kept local,
not committed).
