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

- **Breach Monitoring** — Check emails against known data breaches via the HIBP v3 API
- **Paste Detection** — Discover if your email addresses have appeared in public pastes
- **Password Auditing** — Verify passwords against breach databases using k-anonymity (SHA-1 prefix only, plaintext never leaves your machine)
- **DNS Surveillance** — Track A, MX, NS, and TXT record changes for your domains with automatic baseline diffing
- **Encrypted Storage** — In-memory SQLite database serialized to disk as an AES-256-GCM encrypted blob with Keychain-managed keys
- **Menu Bar Native** — Lives in your menu bar with a window-style popover, no Dock icon
- **Breach Timeline** — Chronological, expandable feed of all findings grouped by date
- **macOS Notifications** — Alerts for new breaches, pastes, and DNS changes with per-type toggles
- **PDF Reports** — Export a formatted security report of all assets and findings
- **Scheduled Scans** — Configurable 1h / 6h / 12h / 24h automatic scanning
- **Launch at Login** — One-click toggle via SMAppService
- **Zero Dependencies** — Pure Apple frameworks only, no third-party Swift packages

## Getting Started

### Prerequisites

- macOS 14 Sonoma or later
- Xcode 15+ with Swift 5.10+
- [HIBP API key](https://haveibeenpwned.com/API/Key) (required for email/paste checks, free for password checks)

### Installation

```bash
git clone https://github.com/markksantos/Canary.git
cd Canary
swift build
swift run
```

Or open `Canary.xcodeproj` in Xcode for the full app bundle experience with code signing.

### Permissions

Canary requires the following entitlements when sandboxed:

| Permission | Reason |
|---|---|
| Network Client | HIBP API requests and DNS resolution |
| Keychain Access | Storing the encryption key and API key |

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
│           └── PasswordHasherTests.swift
├── project.yml                              # XcodeGen spec
└── .gitignore
```

## License

MIT License &copy; 2026 Mark Santos

---

<div align="center">

Built with :yellow_heart: by [NoSleepLab](https://nosleeplab.com)

</div>
