![Find iOS](docs/find-ios-banner.png)

Native SwiftUI client for [Find](https://find.taliferro.tech) — a free,
no-account-required search experience built by [Taliferro Tech](https://taliferro.com).
Type any question, company, topic, or "weather in Seattle," and instead of a
page of ten blue links, Find hands you one strong result — a synthesized
answer, an entity summary, or a weather card — with source citations, an
image, and a handful of context pills to drill deeper. Companion to the
[web app](https://github.com/tshowers/find), calling the same shared
Taliferro Tech backend.

## Structure

```
Find/
  FindApp.swift          App entry point
  AppDelegate.swift       Orientation lock for tilt navigation
  FindModels.swift        Codable response models
  AboutModels.swift       Product-grid data for the About screen
  AppConfig.swift         Reads FIND_API_BASE_URL / FIND_API_KEY from the bundle
  FindAPIClient.swift      /find/search, /find/summarize
  TiltNavigationService.swift  Gyroscope-based tilt-to-drill-down
  Theme.swift              Light/dark adaptive color tokens
  SearchView.swift, SearchViewModel.swift, ShareSheet.swift
  Assets.xcassets          App icon, accent color, Find logo
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

- **One strong result, not a list** — a single answer or entity card up
  front; page through the other candidates with the shelf's back/forward
  chevrons or a left/right swipe
- **Grounded question answers** — for question-style queries ("what's the
  tallest animal on land"), Find synthesizes a short answer from multiple
  sources and shows a References section of the actual citations, each a
  tappable link to the source. Paging away from that first slide switches to
  each individual result's own title/summary/source, exactly like the grid
  shows for it
- **Weather mode** — a dedicated weather card (temperature, condition,
  feels-like, humidity, wind) for plain-language weather queries, with a
  branded fallback icon if the forecast provider has none
- **Context pills & drill-down** — up to 4 refinement pills per result;
  tapping one appends it to the current query and re-runs the search
- **Tilt navigation** — an optional gyroscope-based way to drill into a pill
  without touching the screen: flick the device toward a pill (left/right/
  up/down) to open it. Locks the device to portrait for the duration so the
  gesture doesn't fight with screen rotation
- **Grid view** — all candidate results as a two-column grid; tapping a tile
  opens that result's actual source, not an in-app detail screen — Find is
  meant to take you to the thing you found
- **Search history**
- **Trusted-source curation** — the backend excludes social/video feeds and
  a handful of low-quality aggregators outright, prefers a tiered list of
  wire services, investigative newsrooms, and public broadcasters for news
  results, and swaps in Taliferro-branded cards for those trusted sources
  instead of whatever image the source itself returns
- **Dark mode** — follows the system appearance, with a palette matching the
  web app's own light/dark tokens
- **About screen** — a "More from Taliferro Tech" / "Momentum system"
  product grid linking out to the rest of the TODD product family
- **Share sheet** for the current result

## For ad-hoc export builds

Copy `ExportOptions-AdHoc.plist.example` to `ExportOptions-AdHoc.plist`
and fill in your own Apple Developer Team ID (gitignored — kept local,
not committed).
