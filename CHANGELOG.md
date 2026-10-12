# Changelog

All notable changes to this project are documented here.

## 2026-10-12

### Changed
- Marketing version bumped 1.4 → 1.5 (build 8). 1.5 is built on its own
  branch so 1.4 can ship unchanged.

### Added
- Info: the company mission, "Our mission is to make search obsolete."
  (written in 2010), above the TODD line. Matches the web app's Info panel.
- Siri: "Ask Find" now shows its answer as a card (label, headline,
  detail, source) under the spoken answer.
- Siri: "Save that to Knowledge in Find" / "Save that with Find" / "Save the
  last Find answer" opens Docs' /knowledge/save with the last answer Ask
  Find gave. The Save tile and Siri build that link in one place
  (`KnowledgeSaveLink.swift`).
- "Search with Find" control for Control Center, the Lock Screen and the
  Action button (iOS 18): opens Find to a new search with the keyboard up.
  The control lives in FindWidgetExtension; its intent
  (`OpenFindSearchIntent.swift`) is compiled into the app too, so it opens
  the app. For a voice search from the Action button, assign the "Ask Find"
  shortcut instead (already available).

## 2026-10-02

### Changed
- Marketing version bumped 1.1 → 1.2 (build 5) for the redesign release.
- Result-page redesign, ported from the web app's design handoff (iPhone
  screens 2i–2k and 3i–3l): Helvetica Neue throughout, logo-colour tokens on
  white / near-black (`Theme.swift`; the older colour names now point at the
  new palette, so Awards, Info and the Grid recolour without layout changes).
- Home: logo + wordmark, a 54pt search field with a full-width Find button,
  and tinted 3×2 quick-search tiles.
- Result pager: 44pt Back/Next circles around logo-coloured progress segments
  and "N of M · See all"; Weather and Conversion show Back plus a label.
- Image rule on every result: the result's own image is a rounded 190pt hero;
  Find's fallback artwork is only ever a 72pt thumbnail; with no image the
  text takes the width. (The sports artwork used to replace real photos.)
- Weather: compact blue card, forecast rows with low→high range bars.
- Conversion: stacked From/To cards, swap button over the seam, 3×4 keypad
  (hold ⌫ to clear).
- Tab bar shows labels under the icons.
- Results now page with a standard horizontal swipe
  (`UIPageViewController` `.scroll`, 16pt gap between pages) instead of the
  iBooks-style page curl, which suited the original paper look but not the
  flat redesign. `FindResultPageCurlView` is renamed `FindResultPagerView`.

### Added
- News/Sports headline pages (`queryType` `sports`/`news`, `rssBacked`): tag,
  "source · 4h ago", Read/Copy action tiles, a "Next" preview card, and an
  attribution line built from the results' sources.
- Action tiles on every web and place result (2i), shown only when their
  data exists: any result with a link gets Site + Copy; a place (hours,
  address, phone, or a local search) also gets Go first - Apple Maps
  directions to the address, or a search for the name plus any "City, ST"
  in the title - and Call when there's a phone number. Decodes the backend's
  `address` / `phone` result fields, which the app previously ignored.
- Street addresses split across title segments are now recognised
  ("Young's Restaurant - 9413 16th Ave SW - Restaurants - Seattle, WA -
  EverOut Seattle" -> "Young's Restaurant", "9413 16th Ave SW, Seattle, WA"),
  so listing-site results get a clean name and the Go (Maps) tile.
- One-row "Right find?" feedback on result pages, posting to `find/feedback`
  (`FindFeedbackStore`).
- Movie answers (`queryType` `movie`): the app never decoded the backend's
  `movieRatings`, so a movie search showed only the query as a title. Now
  shows the poster, year · rating · runtime, IMDb / Rotten Tomatoes /
  Metacritic pills, plot, director / starring / genre, and IMDb / Copy link
  tiles, with a Back + "Movie" pager.

### Fixed
- The pager no longer shows "1 of 0" for answers with no ranked results.

- `FindComponents.swift` for the shared pieces (tags, action tiles, pager
  segments, relative times, weather symbols).

## 2026-09-24

### Released
- v1.0 (build 1) shipped to the App Store — the app's first public release.

### Added
- `FindLocationService.swift` — the app never had any `CoreLocation`
  integration before this, so the Weather quick action and "restaurants near
  me" sent no coordinates and silently fell back to a generic result. Location
  is now requested lazily (only for a location-shaped query, never on launch)
  and cached for the session, mirroring the web app's
  `resolveCoordinatesForQuery`. Added the required
  `NSLocationWhenInUseUsageDescription` to both build configs.

### Fixed
- Build number bumped to 2, then 3, then 4, for each new archive — App Store Connect
  requires a unique, increasing build number per upload within the same
  marketing version.

### Changed
- Marketing version bumped 1.0 → 1.1: since the initial 1.0 buildout, the app
  has picked up the Awards system, an updated Info page, and the six-button
  quick-action row (News, Sports, Weather, Events, Conversion, Restaurants) —
  enough accumulated user-facing change to call it a minor release rather
  than another 1.0 build.

## 2026-08-30

### Added
- "More from Taliferro Tech" and "Momentum system" product grid on the About
  screen, matching the web app's About page — links out to Email Signature
  Builder, SayIt, Ask TODD, Lead Vault, Maya, Taliferro Music, Pulse, Network,
  Outreach, Moves, Social, and Docs (`AboutModels.swift`).
- Website link and copyright line in the About screen's "Built by" footer.
- Real 1024×1024 App Store icon (generated from the in-app Find logo mark).
- Privacy manifest (`PrivacyInfo.xcprivacy`) declaring the app's use of
  `UserDefaults` for search history.
- README, this changelog, `.gitignore`, and the ad-hoc export options
  workflow — first commit of this app as its own repo under `apps/ios/`.

### Fixed
- `IPHONEOS_DEPLOYMENT_TARGET` was `26.5` (an invalid, auto-generated value)
  — set to `17.0`.
- No signing team was configured — set `DEVELOPMENT_TEAM` so the project
  archives for App Store / ad-hoc distribution.
- About screen copy for "Context pills & drill-down" and "People → Lead
  Vault" was out of sync with the web app's wording — brought back in line.

### Notes
- This app was previously an untracked working copy alongside a separate,
  unused `find-ios` starter folder (source-only, no `.xcodeproj`, no longer
  needed now that this app is the real one).
- Known gaps versus the web app, intentionally out of scope for this pass:
  weather-mode results, the question/answer card layout with grounded
  references, the first-party result badge, tilt/gyroscope navigation, and
  the automatic Lead Vault handoff for person queries (the data model
  already carries `FindQueryType.person`, but the UI doesn't act on it yet).
