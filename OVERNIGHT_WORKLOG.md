# Canary — Overnight Worklog

## What it is

Canary is a native macOS menu-bar app (SwiftUI `MenuBarExtra`, macOS 14+) that
monitors a user's emails, passwords, and domains against known data breaches.
It checks emails via the Have I Been Pwned (HIBP) v3 API and the free
XposedOrNot API, audits passwords using HIBP's k-anonymity range API (only a
SHA-1 prefix leaves the machine), and watches domains for A/MX/NS/TXT DNS
changes. Findings are stored in an in-memory SQLite database serialized to disk
as an AES-256-GCM blob with a Keychain-managed key, surfaced as macOS
notifications, and exportable as a formatted PDF report. The app is structured
as a thin Xcode app target plus a local SPM package with two libraries:
`CanaryEngine` (all logic/IO) and `CanaryUI` (all SwiftUI views).

## Starting state

Honest starting completeness: **~80%.** This was a genuinely mature,
Mark-authored codebase (not a third-party clone): ~38 Swift source files,
2 prior commits, full feature set scaffolded and wired (dashboard, timeline,
settings, onboarding, CSV import, keyboard shortcuts, PDF export, scheduler,
notifications). A prior session had uncommitted work-in-progress: de-sandboxing
for direct distribution, a `DatabaseManager` `fileURL` override + corrupt-store
recovery, and project/version metadata.

What was actually broken on arrival:
- **`swift test` failed** — the round-trip DB test failed intermittently
  because all `DatabaseManager` tests shared the user's real on-disk store and
  Swift Testing runs them in parallel; concurrent `save()` calls stomped on
  each other. The prior session's `fileURL` override (added "so tests never
  touch the user's real data") had not actually been wired into the tests.
- **One Swift 6 concurrency warning** in `Engine.init` (captured `var` in a
  `@Sendable` closure).
- **XposedOrNot integration silently returned zero breaches** — the client
  called `/check-email/{email}`, which returns only breach *names* under a
  `breaches` key, never the `ExposedBreaches.breaches_details` structure the
  decoder expected. Verified against the live API. The detailed payload only
  comes from `/breach-analytics?email=`.
- **Missing LICENSE** (README badge linked to a non-existent file) and missing
  CHANGELOG.
- A silently-swallowed error in the PDF export path.

## What I changed, fixed, added, built

Engine / API fixes:
- `CanaryPackage/Sources/CanaryEngine/API/XposedOrNotClient.swift` — repointed
  `checkEmail` at the `/breach-analytics?email=` endpoint (built with
  `URLComponents` for correct query encoding) so it actually returns detailed
  breaches.
- `CanaryPackage/Sources/CanaryEngine/API/XposedOrNotModels.swift` — parse the
  `xposed_data` field as semicolon-delimited (accepting `,` as a fallback).
- `CanaryPackage/Sources/CanaryEngine/Scheduler/ScanScheduler.swift` +
  `.../Engine.swift` — made `onScan` a settable property assigned after init,
  eliminating the Swift 6 Sendable closure-capture warning. SPM now builds with
  **0 warnings.**
- `CanaryPackage/Sources/CanaryUI/Settings/SettingsView.swift` — PDF-export
  failures now surface via `engine.errorMessage` instead of an empty `catch`.

Tests (15 → 22, all passing):
- `Tests/CanaryEngineTests/DatabaseManagerTests.swift` — rewrote to give each
  test an isolated temp `fileURL` + unique Keychain service (the real fix the
  `fileURL` override was designed for). Flaky round-trip failure resolved.
- `Tests/CanaryEngineTests/HIBPClientTests.swift` — `MockURLProtocol` now uses
  an `NSLock` and no longer does a destructive global `reset()`, so parallel
  network-mock suites don't wipe each other's stubs.
- `Tests/CanaryEngineTests/XposedOrNotClientTests.swift` (new) — 3 tests
  locking in the corrected endpoint + parsing.
- `Tests/CanaryEngineTests/CSVImporterTests.swift` (new) — 4 tests covering
  quoted/escaped fields, Bitwarden detection, generic extraction, empty input.

Distribution / docs:
- `Canary/Canary.entitlements`, `project.yml`, `Canary.xcodeproj/project.pbxproj`
  — finalized the unsandboxed direct-distribution config and version metadata
  (from the prior WIP), committed.
- `README.md` — rewritten to match reality: XposedOrNot provider, optional-HIBP
  -key model, CSV import, onboarding, real build/run commands, and a full
  **Distribution** section (Developer ID + notarization steps, plus the MAS
  re-sandboxing path).
- `LICENSE` (new, MIT) and `CHANGELOG.md` (new, v1.0.0).
- `tasks/todo.md` — updated with real build/test status and remaining items.
- Tagged **v1.0.0** locally.

## Current state — does it build? does it run? tests?

- **SPM build:** PASS, 0 warnings (`cd CanaryPackage && swift build`).
- **Xcode app build:** PASS from a clean DerivedData
  (`xcodegen generate && xcodebuild ... build`) → ad-hoc-signed `Canary.app`,
  identifier `com.canary.app`, `LSUIElement = YES`. 0 compiler warnings.
- **Run:** PASS — the built app launches as a menu-bar agent and runs without
  crashing or emitting any stderr (verified 5s clean run).
- **Tests:** 22/22 pass, repeatably (ran 3x to confirm no flakiness).

## How to run it locally

```bash
# Engine + UI + tests (fast loop)
cd CanaryPackage
swift build
swift test                 # 22 tests

# Full menu-bar app bundle
cd /Users/markksantos/Developer/Canary
xcodegen generate
xcodebuild -project Canary.xcodeproj -scheme Canary -configuration Debug \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Canary.app
# No Dock icon — look for the bird in the menu bar.
```

The app works immediately with no API key: password (k-anonymity) checks, DNS
monitoring, and XposedOrNot email breach checks are all free. Entering a HIBP
key in Settings additionally enables HIBP email + paste checks. The key is
stored in the macOS Keychain (never on disk in plaintext).

## How to deploy (when ready)

Direct distribution (recommended for this app):
1. `xcodegen generate`
2. Release build signed with a Developer ID:
   ```bash
   xcodebuild -project Canary.xcodeproj -scheme Canary -configuration Release \
     -derivedDataPath build/Release \
     CODE_SIGN_IDENTITY="Developer ID Application: <Name> (TEAMID)" \
     CODE_SIGN_STYLE=Manual build
   ```
3. Notarize:
   ```bash
   ditto -c -k --keepParent <Canary.app> Canary.zip
   xcrun notarytool submit Canary.zip --apple-id <id> --team-id <TEAMID> \
     --password <app-specific-password> --wait
   xcrun stapler staple <Canary.app>
   ```
4. Package as a DMG (`create-dmg`) or attach to a GitHub Release.

Mac App Store path: re-enable `com.apple.security.app-sandbox` and add
`keychain-access-groups` + `com.apple.security.network.client` in
`Canary/Canary.entitlements`, then archive/upload via Xcode Organizer.

(No deploy was performed — the project is deploy-READY only.)

## NEEDS FROM MARK

1. **HIBP API key (paid, ~$4/mo)** — not present in any sibling project's
   `.env` (checked KEYS_CATALOG.md). Required only to verify/enable HIBP email
   + paste checks end-to-end. Everything else (passwords, DNS, XposedOrNot
   email checks) already works without it. The key is entered at runtime in the
   app's Settings, not a build-time env var, so there is nothing to wire into a
   `.env`.
2. **Distribution channel decision** — DMG, GitHub Releases, or Mac App Store.
   Direct distribution is wired and documented; MAS needs the entitlement swap
   above.
3. **Apple Developer ID + notarization** — needed to ship to other Macs (the
   local build is ad-hoc signed and runs only on this machine without it).
4. **App icon (optional polish)** — no asset catalog/`.icns` exists; the app
   uses a generic icon. Harmless for a menu-bar app (no Dock icon), but matters
   for Finder/DMG presentation.

## Honest completeness % now and what remains

**~95%.** Builds clean, runs clean, 22/22 tests pass, all features wired and
working, docs/license/changelog in place, deploy-ready for direct distribution.

Remaining (none blocking a local/dev ship):
- HIBP email/paste path is code-complete but unverified live (gated on the paid
  key above).
- DNS MX/NS/TXT values are stored/displayed as raw wire bytes — change
  *detection* works correctly (byte-for-byte baseline diffing), but pretty
  decoding of MX priorities, NS hostnames, and TXT strings is a future
  enhancement. A-record resolution returns a single resolved address.
- No app icon asset (see above).
- Notarization/store submission require Mark's Apple account.
