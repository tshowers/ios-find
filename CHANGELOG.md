# Changelog

All notable changes to this project are documented here.

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
