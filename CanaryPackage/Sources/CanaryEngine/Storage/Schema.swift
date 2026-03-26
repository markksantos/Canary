import Foundation

public enum Schema {
    public static let version = 1

    public static let createTables = """
        CREATE TABLE IF NOT EXISTS monitored_assets (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            value TEXT NOT NULL,
            label TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'unknown',
            last_checked TEXT,
            finding_count INTEGER NOT NULL DEFAULT 0,
            date_added TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS findings (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            source TEXT NOT NULL,
            title TEXT NOT NULL,
            detail TEXT NOT NULL,
            date TEXT NOT NULL,
            severity TEXT NOT NULL DEFAULT 'medium',
            FOREIGN KEY (asset_id) REFERENCES monitored_assets(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS scan_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at TEXT NOT NULL,
            completed_at TEXT,
            assets_scanned INTEGER NOT NULL DEFAULT 0,
            findings_count INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL DEFAULT 'running'
        );

        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS dns_baselines (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            record_type TEXT NOT NULL,
            records TEXT NOT NULL,
            captured_at TEXT NOT NULL,
            FOREIGN KEY (asset_id) REFERENCES monitored_assets(id) ON DELETE CASCADE
        );

        CREATE UNIQUE INDEX IF NOT EXISTS idx_assets_kind_value ON monitored_assets(kind, value);
        """
}
