<div align="center">

# 🐤 Canary

**A native macOS menu bar app that monitors your digital footprint against data breaches.**

[![Swift](https://img.shields.io/badge/Swift-5.10-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-MenuBarExtra-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

[Features](#features) · [Getting Started](#getting-started) · [Tech Stack](#tech-stack)

</div>

---

## Features

- **Breach Monitoring** — Check emails against known data breaches via the HIBP v3 API (paid key) *and* the free [XposedOrNot](https://xposedornot.com) API, with results de-duplicated across both providers
- **Paste Detection** — Discover if your email addresses have appeared in public pastes (HIBP)
- **Password Auditing** — Verify passwords against breach databases using k-anonymity (SHA-1 prefix only, plaintext never leaves your machine — no API key required)
- **DNS Surveillance** — Track A, MX, NS, and TXT record changes for your domains with automatic baseline diffing
- **Encrypted Storage** — In-memory SQLite database serialized to disk as an AES-256-GCM encrypted blob with Keychain-managed keys
- **Menu Bar Native** — Lives in your menu bar with a window-style popover, no Dock icon
- **Breach Timeline** — Chronological, expandable feed of all findings grouped by date
- **macOS Notifications** — Alerts for new breaches, pastes, and DNS changes with per-type toggles
- **PDF Reports** — Export a formatted security report of all assets and findings
- **Scheduled Scans** — Configurable 1h / 6h / 12h / 24h automatic scanning
- **CSV Import** — Bulk-import emails/passwords from 1Password, Bitwarden, Safari, or generic CSV exports
- **Onboarding** — Three-step first-run flow (welcome → API key → first asset)
- **Launch at Login** — One-click toggle via SMAppService
- **Zero Dependencies** — Pure Apple frameworks only, no third-party Swift packages

## Getting Started

### Prerequisites

- macOS 14 Sonoma or later
- Xcode 15+ with Swift 5.10+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to (re)generate the Xcode project
- A [HIBP API key](https://haveibeenpwned.com/API/Key) is **optional** — it unlocks HIBP email/paste breach checks. Password (k-anonymity) checks, DNS monitoring, and XposedOrNot email breach checks all work with no key. The key is entered in the app's Settings and stored in the macOS Keychain; it is never written to disk in plaintext.

### Build & run

Engine + UI as a Swift package (fast iteration, runs the test suite):

```bash
cd CanaryPackage
swift build
swift test          # 22 tests
```

Full menu-bar app bundle (regenerates the Xcode project from `project.yml`):

```bash
xcodegen generate
xcodebuild -project Canary.xcodeproj -scheme Canary -configuration Debug \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/Canary.app
```

The app has no Dock icon (`LSUIElement = YES`); look for the bird in the menu bar.

### Permissions

Canary ships **unsandboxed** for direct distribution (DMG / GitHub Releases) so it can
use the default Keychain when ad-hoc or Developer ID signed. It requests:

| Permission | Reason |
|---|---|
| Network Client | HIBP / XposedOrNot API requests and DNS resolution |
| Keychain Access | Storing the database encryption key and the HIBP API key |
| Notifications | Breach / paste / DNS-change alerts (requested at first launch) |

## Tech Stack

| Component | Technology |
|---|---|
| UI Framework | SwiftUI `MenuBarExtra` with `.window` style |
| Observation | `@Observable` macro (macOS 14+) |
| Networking | `URLSession` + `async/await` |
| DNS Resolution | `dnssd` framework + `NWConnection` |
| Database | SQLite3 C API (in-memory, serialized to disk) |
| Encryption | CryptoKit AES-256-GCM |
| Hashing | CryptoKit `Insecure.SHA1` (HIBP k-anonymity) |
| Keychain | Security framework |
| Notifications | UserNotifications |
| PDF Export | WebKit `WKWebView.createPDF()` |
| Login Item | ServiceManagement `SMAppService` |
| Project Gen | XcodeGen |

## Project Structure

```
Canary/
├── Canary/                                  # Xcode app target
│   ├── CanaryApp.swift                      # @main, MenuBarExtra entry point
│   ├── Info.plist                           # LSUIElement = YES
│   └── Canary.entitlements                  # Sandbox, network, keychain
├── CanaryPackage/                           # Local SPM package
│   ├── Package.swift
│   ├── Sources/
│   │   ├── CanaryEngine/
│   │   │   ├── API/
│   │   │   │   ├── HIBPClient.swift         # HIBP v3 email, paste, password checks
│   │   │   │   ├── HIBPModels.swift         # BreachModel, PasteModel
│   │   │   │   └── RateLimiter.swift        # Actor-based token bucket
│   │   │   ├── Crypto/
│   │   │   │   ├── DatabaseEncryption.swift # AES-256-GCM encrypt/decrypt
│   │   │   │   └── PasswordHasher.swift     # SHA-1 with plaintext zeroing
│   │   │   ├── DNS/
│   │   │   │   ├── DNSModels.swift          # DNSRecord, DNSBaseline, DNSDiff
│   │   │   │   └── DNSMonitor.swift         # dnssd + NWConnection resolution
│   │   │   ├── Export/
│   │   │   │   └── PDFReportGenerator.swift # HTML → WKWebView → PDF
│   │   │   ├── Keychain/
│   │   │   │   └── KeychainManager.swift    # Security framework wrapper
│   │   │   ├── Notifications/
│   │   │   │   └── NotificationManager.swift
│   │   │   ├── Scheduler/
│   │   │   │   └── ScanScheduler.swift      # Configurable interval loop
│   │   │   ├── Storage/
│   │   │   │   ├── DatabaseManager.swift    # Encrypted SQLite lifecycle
│   │   │   │   ├── Models.swift             # MonitoredAsset, Finding, enums
│   │   │   │   └── Schema.swift             # CREATE TABLE definitions
│   │   │   └── Engine.swift                 # @Observable orchestrator
│   │   └── CanaryUI/
│   │       ├── Assets/
│   │       │   ├── AddDomainView.swift
│   │       │   ├── AddEmailView.swift
│   │       │   ├── AddPasswordView.swift
│   │       │   └── AssetListView.swift
│   │       ├── Dashboard/
│   │       │   ├── AssetSummaryCard.swift
│   │       │   ├── DashboardView.swift
│   │       │   └── StatusBadge.swift
│   │       ├── Settings/
│   │       │   ├── APIKeySettingView.swift
│   │       │   ├── NotificationSettingsView.swift
│   │       │   └── SettingsView.swift
│   │       ├── Shared/
│   │       │   └── Theme.swift
│   │       └── Timeline/
│   │           ├── TimelineRow.swift
│   │           └── TimelineView.swift
│   └── Tests/
│       └── CanaryEngineTests/
│           ├── DatabaseManagerTests.swift
│           ├── HIBPClientTests.swift
│           ├── XposedOrNotClientTests.swift
│           ├── CSVImporterTests.swift
│           └── PasswordHasherTests.swift
├── project.yml                              # XcodeGen spec
└── .gitignore
```

## Distribution

Canary is deploy-ready as a directly-distributed (non-MAS) macOS app. The repo
builds and signs ad-hoc out of the box; shipping to other Macs needs an Apple
Developer ID and notarization.

1. **Build Release**
   ```bash
   xcodegen generate
   xcodebuild -project Canary.xcodeproj -scheme Canary -configuration Release \
     -derivedDataPath build/Release \
     CODE_SIGN_IDENTITY="Developer ID Application: <Your Name> (TEAMID)" \
     CODE_SIGN_STYLE=Manual build
   ```
2. **Notarize**
   ```bash
   ditto -c -k --keepParent build/Release/Build/Products/Release/Canary.app Canary.zip
   xcrun notarytool submit Canary.zip --apple-id <id> --team-id <TEAMID> \
     --password <app-specific-password> --wait
   xcrun stapler staple build/Release/Build/Products/Release/Canary.app
   ```
3. **Package** — wrap the `.app` in a DMG (e.g. `create-dmg`) or attach it to a
   GitHub Release.

For the **Mac App Store** instead: re-enable `com.apple.security.app-sandbox` and
add `keychain-access-groups` + `com.apple.security.network.client` in
`Canary/Canary.entitlements`, then archive and upload via Xcode Organizer or
`xcodebuild -exportArchive`.

> Notarization and store submission require Mark's Apple Developer account; the
> ad-hoc build above runs locally without it.

## License

MIT License &copy; 2026 Mark Santos

---

<div align="center">

Built with :yellow_heart: by [NoSleepLab](https://nosleeplab.com)

</div>
