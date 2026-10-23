![Find iOS](docs/find-ios-banner.png)

# Find for iPhone and iPad

Native SwiftUI client for [Find](https://find.taliferro.tech), a free, no-account-required search experience built by [Taliferro Tech](https://taliferro.tech). Instead of ten blue links, Find hands you one strong result with context to go deeper.

This app is a hand-built port of the **web app** ([`web-products/find`](https://github.com/tshowers/find)) and is kept in step with it feature by feature. Both call the same shared Taliferro Tech backend. **Start with the web README**: it has the full API list, backend settings, the repo map and the deploy order. This file covers what's specific to iOS.

Bundle ID `tech.taliferro.Find` · Team `6377FLHLAG` · Version **1.4 (7)** · iOS/iPadOS **17.0+**

## Features

Everything in the web app (exact answers, places with distance and Open now, every location of a business, "why this result", follow-ups, Watch, share links, Save to Knowledge, weather, movies, headlines, history, awards, tilt navigation), plus:

- **Watch notifications.** A push when a watched find changes; tapping it opens that search.
- **"Find" in the share sheet.** Select text in Safari (or share a page) to see Find's answer in the sheet.
- **Home-screen widget** (small, medium). A search box plus the latest Watch change.
- **Siri and Shortcuts.** "Ask Find" / "Search Find" speaks the answer and shows it as a card, without opening the app. "Save that to Knowledge in Find" saves the last answer to Knowledge.

## Set up

1. Open `Find/Find.xcodeproj` in Xcode (built with Xcode 27).
2. Signing is **automatic** with team `6377FLHLAG`. On another team, change it on all three targets under Signing & Capabilities, and register your own App Group (below).
3. Pick the **Find** scheme and an iPhone or iPad simulator, then press ⌘R.

The project uses Xcode's **file-system-synchronized groups**: a new `.swift` file dropped into `Find/Find/`, `Find/FindShare/` or `Find/FindWidget/` joins that target automatically; no project-file edits needed. The one exception: `Find/Find/OpenFindSearchIntent.swift` is also compiled into FindWidgetExtension (for the Control Center control) through a membership exception in the project file. A file needed by both targets must be added there the same way, or by ticking the second target in Xcode's File inspector. There's no test target, so check changes with a build:

```bash
cd Find
xcodebuild -project Find.xcodeproj -scheme Find -destination 'generic/platform=iOS Simulator' -configuration Debug build
```

## Targets

| Target | Folder | What it is |
|---|---|---|
| **Find** | `Find/Find/` | The app |
| **FindShare** | `Find/FindShare/` | Share extension. It runs in its own process, so it has a small copy of the search call (`ShareModel.swift`) instead of using the app's client. Accepts text and web pages only (App Review rejects "accept everything"). |
| **FindWidgetExtension** | `Find/FindWidget/` | Home-screen widget. Reads the latest Watch change from the App Group and opens the app with `find://` links. Also the "Search with Find" control (Control Center, Lock Screen, Action button; iOS 18). |

All three must have the same version and build number; bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` on every target together.

## Configuration

| Setting | Where | What it is |
|---|---|---|
| `FIND_API_BASE_URL` | Build settings (Find target) | Shared API, `https://api.taliferro.tech/api`. `AppConfig.swift` falls back to this if the bundle doesn't have it. |
| `FIND_API_KEY` | Build settings (Find target) | Public client key sent as the bearer token, the same one the web app uses (`apiKey` in its `environment.ts`). `AppConfig.swift` has the same fallback. `FindShare/ShareModel.swift` repeats both values because extensions can't read the app's bundle. |
| App Group `group.tech.taliferro.find` | Entitlements, all three targets | Lets the widget read Watch changes (`widget.*` keys in shared `UserDefaults`) |
| Push Notifications (`aps-environment`) | `Find/Find.entitlements` | Watch notifications. Xcode builds register as `sandbox`, archives as `production`; the app tells the backend which (`FindWatchStore.registerDevice`). |
| `find://` URL scheme | `Find-Info.plist` (merged with the generated Info.plist) | `find://search?q=…`, `find://search`, `find://watching`; used by the widget |
| Location permission text | `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` | Weather, "near me", and the optional Use my location switch |
| Privacy manifest | `Find/Find/PrivacyInfo.xcprivacy` | Declares coarse location, search history and device ID (app functionality only, not linked, no tracking). **The App Store privacy label must match it.** |

Apple Developer setup already done for this app ID: Push Notifications enabled and App Group registered. The backend's Apple push key is team-wide (shared with Outreach, Pulse and Maya), so no certificate is needed.

**Per-device state** (`UserDefaults`): search history, awards, `find.useLocation`, `find.deviceId` (random id for Watch, no account), `find.hasWatches`.

## Code map

```
Find/Find/
  FindApp.swift              Entry point; creates the API client and FindWatchStore
  AppDelegate.swift          Orientation lock (tilt), push token, notification taps
  AppConfig.swift            API base URL and key
  FindAPIClient.swift        Every backend call (search, summarize, followup, share, watches, devices, feedback)
  FindModels.swift           Codable request/response types; mirrors find-experience.service.ts
  SearchViewModel.swift      Search, history, location switch, Open now, follow-ups, share links
  SearchView.swift           Home, results, All, History (+ Watching), Info, Awards, Share; tab bar
  ResultPageView.swift       One result page (actions, locations, why-this-result, follow-up, Watch)
  FindResultPagerView.swift  Page-curl pager around ResultPageView (UIKit); pass new inputs through it
  ResultGridView.swift       All: 4 layouts by width, like the web; Open now button
  FindWatchStore.swift       Watch a find: list, create/remove/renew, notifications, widget data
  FollowupBox.swift          "Ask about this result"
  WatchButton.swift          Watch / Watching button
  AskFindIntent.swift        Siri / Shortcuts: Ask Find (spoken answer + card), Save that to Knowledge
  KnowledgeSaveLink.swift    Docs /knowledge/save link, shared by the Save tile and Siri
  HeadlineFeeds.swift        ESPN/NPR headlines fetched on the phone, merged into News/Sports
  FindSpotlight.swift        iPhone search: recent searches and watched finds
  PointToPlaceView.swift     Point: arrow toward a place (compass + position)
  FindActivityMonitor.swift  "Adapt to what I'm doing": driving / walking (Motion & Fitness)
  FindSpeaker.swift          Reads answers aloud; face-down stops it
  OpenFindSearchIntent.swift "Search with Find" control's intent (also in FindWidgetExtension)
  FindLocationService.swift  Location, asked only when needed
  TaliferroCompany.swift     Company and policy links (mirrors MENU_COMPANY in taliferro-ui)
  Theme.swift                Colour tokens (match the web's)
```

## Rules worth knowing

- **Keep it in step with the web app.** Comments name the matching web code (`find-home.component.ts`, …); port changes both ways.
- **Send `features` and `timeZone`.** `FindAPIClient.search` sends `features: ["instant", "units"]`. A new answer type needs a new feature string, here and on the web, so older App Store versions keep working.
- **`FindQueryType` has an `.unknown` fallback, but `FindConversionCategory` doesn't.** An unknown conversion category fails the whole response. Add new categories to the enum before the backend sends them.
- **Pages inside `FindResultPagerView` can't see the environment.** They live in `UIHostingController`s, so pass new inputs explicitly (see `followupActions`, `watchStore`).

## Release

1. Destination **Any iOS Device (arm64)** → **Product → Archive** → **Distribute App → App Store Connect → Upload**.
2. In App Store Connect: new version, What's New, pick the build, update **App Privacy** if `PrivacyInfo.xcprivacy` changed, then submit.
3. Make sure any backend changes the release needs are already deployed.

For ad-hoc builds, copy `ExportOptions-AdHoc.plist.example` to `ExportOptions-AdHoc.plist` and fill in your team ID (it's gitignored).

See `CHANGELOG.md` for release history.
