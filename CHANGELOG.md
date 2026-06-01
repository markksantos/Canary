# Changelog

All notable changes to Canary are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-05-31

First public release. A native macOS menu-bar app that monitors emails,
passwords, and domains against known data breaches.

### Added
- HIBP v3 breach + paste checks (requires a HIBP API key) and free
  XposedOrNot email breach checks, with cross-provider de-duplication.
- Password auditing via HIBP k-anonymity (SHA-1 prefix only; no key required).
- DNS surveillance (A/MX/NS/TXT) with baseline diffing and change alerts.
- Encrypted storage: in-memory SQLite serialized to disk as an AES-256-GCM blob
  with a Keychain-managed key.
- Menu-bar UI (`MenuBarExtra`, `.window` style) with dashboard, timeline,
  per-asset detail, settings, and a three-step onboarding flow.
- CSV import for 1Password / Bitwarden / Safari / generic exports.
- macOS notifications (breach / paste / DNS) with per-type toggles.
- PDF security report export (risk score, severity breakdown, remediation
  checklist) via WebKit.
- Scheduled scans (1h / 6h / 12h / 24h) and launch-at-login via SMAppService.
- Keyboard shortcuts and a status-bar right-click menu.

### Fixed
- XposedOrNot integration now queries `/breach-analytics` (the endpoint that
  returns detailed per-breach data) instead of `/check-email`, which only
  returned breach names and caused every email to report zero breaches.
- `xposed_data` is parsed as a semicolon-delimited list (was comma).
- Removed a Swift 6 `Sendable` closure-capture warning in the scan scheduler.
- The encrypted store is quarantined and rebuilt instead of crash-looping when
  it cannot be decrypted (e.g. lost Keychain key after reinstall).
- PDF-export failures are now surfaced to the user instead of being swallowed.

### Distribution
- Ships unsandboxed for direct (DMG / GitHub Releases) distribution; see the
  README for the Mac App Store re-sandboxing path.
