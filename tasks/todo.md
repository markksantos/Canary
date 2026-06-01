# Canary — macOS Menu Bar Breach Monitor

## Phase 1: Scaffold + HIBP Email/Password Checks

### Step 1.0 — Project Scaffold
- [x] Create Xcode project with macOS App target (SwiftUI lifecycle)
- [x] Configure Info.plist: LSUIElement = YES
- [x] Configure entitlements: sandbox, network.client, keychain
- [x] Create local SPM package CanaryPackage with CanaryEngine + CanaryUI targets
- [x] Add local package dependency in Xcode project
- [x] Create .gitignore (Swift/Xcode)
- [x] Minimal CanaryApp.swift with MenuBarExtra showing placeholder
- [x] Verify: Build succeeds (0 warnings), menu bar icon, no Dock icon

### Step 1.1 — Keychain + Crypto
- [x] KeychainManager.swift — Security framework wrapper
- [x] PasswordHasher.swift — SHA-1 via CryptoKit.Insecure.SHA1
- [x] DatabaseEncryption.swift — AES-256-GCM encrypt/decrypt
- [x] Unit tests for password hasher (5 tests, all passing)

### Step 1.2 — Storage Layer
- [x] Schema.swift — CREATE TABLE SQL (5 tables)
- [x] Models.swift — MonitoredAsset, Finding, enums/structs
- [x] DatabaseManager.swift — encrypted SQLite lifecycle (serialize/deserialize)
- [x] CRUD operations (add/remove/update assets, save/query findings, settings, DNS baselines)
- [x] Unit tests: round-trip, findings, remove, update, settings (5 tests, all passing)

### Step 1.3 — HIBP API Client
- [x] HIBPModels.swift — BreachModel, PasteModel matching HIBP v3 JSON
- [x] RateLimiter.swift — actor-based token bucket (~9 req/sec)
- [x] HIBPClient.swift — email, paste, password checks with k-anonymity
- [x] Unit tests with mock URLProtocol (5 tests, all passing)

### Step 1.4 — Engine Orchestrator
- [x] Engine.swift — @Observable composing all services
- [x] runFullScan(), scanState, overallStatus, assets, recentFindings
- [x] ScanScheduler.swift — configurable interval (1h, 6h, 12h, 24h)

### Step 1.5 — Dashboard UI
- [x] Theme.swift — colors, spacing, fonts, status helpers
- [x] DashboardView.swift — main popover with tabs (Assets/Timeline/Settings)
- [x] AssetSummaryCard.swift — per-asset card with status, last check, finding count
- [x] StatusBadge.swift — colored circle indicator
- [x] AddEmailView.swift — email validation sheet
- [x] AddPasswordView.swift — SecureField, hash on submit, k-anonymity disclosure
- [x] AddDomainView.swift — domain input with validation
- [x] AssetListView.swift — list with context menu delete
- [x] SettingsView.swift — API key, notifications, frequency, launch at login, PDF export
- [x] Wire Engine into MenuBarExtra via .environment()
- [x] Menu bar icon changes based on status (bird/bird.fill/spinner)

### Step 1.6 — Verification
- [x] xcodebuild succeeds with 0 warnings
- [x] swift test passes (15/15 tests)
- [x] LSUIElement = YES confirmed
- [ ] Manual test: add breached email, check, see results

## Phase 2: DNS Monitoring + Timeline (IMPLEMENTED)
- [x] DNSModels.swift — DNSRecord, DNSBaseline, DNSDiff
- [x] DNSMonitor.swift — NWConnection + dnssd for A/MX/NS/TXT queries
- [x] Schema includes dns_baselines table
- [x] DNS checks integrated into Engine.runFullScan()
- [x] AddDomainView.swift — domain input with validation
- [x] TimelineView.swift — chronological findings grouped by date
- [x] TimelineRow.swift — expandable finding detail

## Phase 3: Alerts + Reporting (IMPLEMENTED)
- [x] NotificationManager.swift — UNUserNotificationCenter with 3 categories
- [x] NotificationSettingsView.swift — per-type toggles
- [x] PDFReportGenerator.swift — HTML→WKWebView→PDF
- [x] Export button in Settings
- [x] ScanScheduler with frequency picker (1h/6h/12h/24h)
- [x] Launch at login via SMAppService
- [ ] Manual verification of notifications and PDF export

## Build Status (2026-05-31)
- SPM build: PASS (0 warnings — fixed Swift 6 Sendable closure-capture warning)
- Xcode build: PASS (0 warnings, ad-hoc signed `Canary.app` produced)
- App launch: PASS (boots as LSUIElement menu-bar app, no crash, no stderr)
- Tests: 22/22 passing (added XposedOrNot + CSVImporter suites; fixed test isolation)

## Post-1.0 hardening (2026-05-31)
- [x] Fixed XposedOrNot client (was hitting the wrong endpoint → always 0 breaches)
- [x] Fixed test isolation (parallel DB tests shared the real on-disk store)
- [x] De-sandboxed for direct distribution; documented MAS re-sandboxing
- [x] Added LICENSE (MIT) and CHANGELOG.md, tagged v1.0.0
- [ ] HIBP email/paste checks unverified end-to-end (needs Mark's paid HIBP key)
- [ ] DNS MX/NS/TXT values are shown as raw wire bytes (change-detection works;
      full record decoding is a future enhancement)
- [ ] App icon (AppIcon asset is referenced but no .icns/asset catalog present)
