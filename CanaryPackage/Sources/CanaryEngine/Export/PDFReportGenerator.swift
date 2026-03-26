import Foundation
import WebKit

@MainActor
public final class PDFReportGenerator {
    public init() {}

    public func generateReport(assets: [MonitoredAsset], findings: [Finding]) async throws -> Data {
        let html = buildHTML(assets: assets, findings: findings)
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        webView.loadHTMLString(html, baseURL: nil)

        // Wait for content to load
        try await Task.sleep(for: .seconds(1))

        let config = WKPDFConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: 612, height: 792)

        return try await webView.pdf(configuration: config)
    }

    private func buildHTML(assets: [MonitoredAsset], findings: [Finding]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let riskScore = computeRiskScore(findings: findings)
        let criticalCount = findings.filter { $0.severity == .critical }.count
        let highCount = findings.filter { $0.severity == .high }.count
        let mediumCount = findings.filter { $0.severity == .medium }.count
        let lowCount = findings.filter { $0.severity == .low }.count
        let exposedCount = assets.filter { $0.status == .exposed }.count

        var html = """
            <!DOCTYPE html>
            <html><head><style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: -apple-system, Helvetica, Arial, sans-serif; padding: 40px; color: #1a1a1a; line-height: 1.5; }

            .header { background: linear-gradient(135deg, #1a1a2e, #16213e); color: white; padding: 24px 32px; border-radius: 12px; margin-bottom: 24px; }
            .header h1 { font-size: 24px; margin-bottom: 4px; }
            .header .date { font-size: 12px; opacity: 0.7; }

            .summary-grid { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 12px; margin-bottom: 24px; }
            .summary-card { background: #f8f9fa; border-radius: 8px; padding: 16px; text-align: center; }
            .summary-card .value { font-size: 28px; font-weight: 700; }
            .summary-card .label { font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px; }

            .risk-score { display: flex; align-items: center; gap: 16px; padding: 20px; background: #f8f9fa; border-radius: 8px; margin-bottom: 24px; }
            .risk-meter { width: 100%; height: 8px; background: #e0e0e0; border-radius: 4px; overflow: hidden; }
            .risk-fill { height: 100%; border-radius: 4px; transition: width 0.5s; }

            .severity-bars { display: flex; gap: 8px; align-items: flex-end; height: 60px; margin-bottom: 24px; padding: 16px; background: #f8f9fa; border-radius: 8px; }
            .sev-bar { flex: 1; border-radius: 4px 4px 0 0; min-height: 4px; text-align: center; }
            .sev-bar .count { font-size: 11px; font-weight: 600; margin-bottom: 4px; }
            .sev-bar .bar { border-radius: 4px; }
            .sev-label { font-size: 10px; color: #666; margin-top: 4px; }

            h2 { font-size: 16px; color: #333; margin: 24px 0 12px; padding-bottom: 8px; border-bottom: 2px solid #007AFF; }

            .asset-cards { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 16px; }
            .asset-card { background: #f8f9fa; border-radius: 8px; padding: 12px; border-left: 3px solid #ccc; }
            .asset-card.safe { border-left-color: #34C759; }
            .asset-card.exposed { border-left-color: #FF3B30; }
            .asset-card .name { font-weight: 600; font-size: 13px; }
            .asset-card .meta { font-size: 11px; color: #666; margin-top: 4px; }
            .asset-card .status { font-size: 11px; font-weight: 600; margin-top: 4px; }
            .status-safe { color: #34C759; }
            .status-exposed { color: #FF3B30; }
            .status-unknown { color: #8E8E93; }

            .finding-item { padding: 10px 12px; border-left: 3px solid #ccc; margin-bottom: 8px; background: #fafafa; border-radius: 0 6px 6px 0; }
            .finding-item.critical { border-left-color: #FF3B30; }
            .finding-item.high { border-left-color: #FF9500; }
            .finding-item.medium { border-left-color: #FFCC00; }
            .finding-item.low { border-left-color: #007AFF; }
            .finding-title { font-weight: 600; font-size: 13px; }
            .finding-meta { font-size: 11px; color: #666; margin-top: 2px; }
            .finding-tags { margin-top: 6px; }
            .tag { display: inline-block; font-size: 10px; background: #e8e8ed; padding: 2px 6px; border-radius: 4px; margin: 2px 2px 0 0; }

            .checklist { margin-top: 12px; }
            .checklist-item { padding: 6px 0; font-size: 12px; border-bottom: 1px solid #f0f0f0; }
            .checklist-item::before { content: "☐ "; }

            .footer { margin-top: 32px; padding-top: 16px; border-top: 1px solid #e0e0e0; font-size: 11px; color: #999; text-align: center; }

            @media print { body { padding: 20px; } .header { break-inside: avoid; } h2 { break-after: avoid; } .finding-item { break-inside: avoid; } }
            </style></head><body>
            """

        // Header
        html += """
            <div class="header">
                <h1>🐦 Canary Security Report</h1>
                <div class="date">Generated \(dateFormatter.string(from: Date()))</div>
            </div>
            """

        // Summary Grid
        html += """
            <div class="summary-grid">
                <div class="summary-card">
                    <div class="value">\(assets.count)</div>
                    <div class="label">Assets Monitored</div>
                </div>
                <div class="summary-card">
                    <div class="value">\(findings.count)</div>
                    <div class="label">Total Findings</div>
                </div>
                <div class="summary-card">
                    <div class="value" style="color: \(exposedCount > 0 ? "#FF3B30" : "#34C759")">\(exposedCount)</div>
                    <div class="label">Exposed Assets</div>
                </div>
                <div class="summary-card">
                    <div class="value" style="color: \(riskColor(riskScore))">\(riskScore)</div>
                    <div class="label">Risk Score</div>
                </div>
            </div>
            """

        // Risk Meter
        html += """
            <div class="risk-score">
                <div style="min-width: 80px;">
                    <div style="font-size: 12px; font-weight: 600;">Risk Level</div>
                    <div style="font-size: 11px; color: \(riskColor(riskScore)); font-weight: 600;">\(riskLabel(riskScore))</div>
                </div>
                <div class="risk-meter">
                    <div class="risk-fill" style="width: \(riskScore)%; background: \(riskColor(riskScore));"></div>
                </div>
            </div>
            """

        // Severity Breakdown
        let maxSev = max(criticalCount, highCount, mediumCount, lowCount, 1)
        html += """
            <div class="severity-bars">
                <div class="sev-bar" style="flex: 1;">
                    <div class="count" style="color: #FF3B30;">\(criticalCount)</div>
                    <div class="bar" style="height: \(max(4, criticalCount * 40 / maxSev))px; background: #FF3B30;"></div>
                    <div class="sev-label">Critical</div>
                </div>
                <div class="sev-bar" style="flex: 1;">
                    <div class="count" style="color: #FF9500;">\(highCount)</div>
                    <div class="bar" style="height: \(max(4, highCount * 40 / maxSev))px; background: #FF9500;"></div>
                    <div class="sev-label">High</div>
                </div>
                <div class="sev-bar" style="flex: 1;">
                    <div class="count" style="color: #FFCC00;">\(mediumCount)</div>
                    <div class="bar" style="height: \(max(4, mediumCount * 40 / maxSev))px; background: #FFCC00;"></div>
                    <div class="sev-label">Medium</div>
                </div>
                <div class="sev-bar" style="flex: 1;">
                    <div class="count" style="color: #007AFF;">\(lowCount)</div>
                    <div class="bar" style="height: \(max(4, lowCount * 40 / maxSev))px; background: #007AFF;"></div>
                    <div class="sev-label">Low</div>
                </div>
            </div>
            """

        // Asset Cards
        html += "<h2>Monitored Assets (\(assets.count))</h2>"
        html += "<div class=\"asset-cards\">"
        for asset in assets {
            let lastChecked = asset.lastChecked.map { dateFormatter.string(from: $0) } ?? "Never"
            html += """
                <div class="asset-card \(asset.status.rawValue)">
                    <div class="name">\(escapeHTML(asset.label))</div>
                    <div class="meta">\(asset.kind.rawValue.capitalized) · \(asset.findingCount) findings · Checked: \(lastChecked)</div>
                    <div class="status status-\(asset.status.rawValue)">\(asset.status.rawValue.uppercased())</div>
                </div>
                """
        }
        html += "</div>"

        // Findings
        if !findings.isEmpty {
            html += "<h2>Findings (\(findings.count))</h2>"
            for finding in findings {
                let meta = finding.metadata
                var tagsHTML = ""
                if let classes = meta?.dataClasses, !classes.isEmpty {
                    tagsHTML = "<div class=\"finding-tags\">" + classes.map { "<span class=\"tag\">\(escapeHTML($0))</span>" }.joined() + "</div>"
                }
                html += """
                    <div class="finding-item \(finding.severity.rawValue)">
                        <div class="finding-title">\(escapeHTML(finding.title))</div>
                        <div class="finding-meta">\(finding.source.rawValue.capitalized) · \(finding.severity.rawValue.capitalized) · \(dateFormatter.string(from: finding.date))</div>
                        \(tagsHTML)
                    </div>
                    """
            }
        }

        // Remediation Checklist
        let remediationItems = buildRemediationChecklist(findings: findings)
        if !remediationItems.isEmpty {
            html += "<h2>Remediation Checklist</h2>"
            html += "<div class=\"checklist\">"
            for item in remediationItems {
                html += "<div class=\"checklist-item\">\(escapeHTML(item))</div>"
            }
            html += "</div>"
        }

        // Footer
        html += """
            <div class="footer">Report generated by Canary — macOS Breach Monitor · \(dateFormatter.string(from: Date()))</div>
            </body></html>
            """

        return html
    }

    private func computeRiskScore(findings: [Finding]) -> Int {
        var score = 0
        for finding in findings {
            switch finding.severity {
            case .critical: score += 40
            case .high: score += 25
            case .medium: score += 10
            case .low: score += 3
            }
        }
        return min(score, 100)
    }

    private func riskColor(_ score: Int) -> String {
        if score >= 70 { return "#FF3B30" }
        if score >= 40 { return "#FF9500" }
        if score >= 15 { return "#FFCC00" }
        return "#34C759"
    }

    private func riskLabel(_ score: Int) -> String {
        if score >= 70 { return "Critical" }
        if score >= 40 { return "High" }
        if score >= 15 { return "Moderate" }
        return "Low"
    }

    private func buildRemediationChecklist(findings: [Finding]) -> [String] {
        var items: [String] = []
        var seenDomains: Set<String> = []

        for finding in findings {
            switch finding.source {
            case .breach:
                if let meta = finding.metadata, let domain = meta.domain, !domain.isEmpty, !seenDomains.contains(domain) {
                    seenDomains.insert(domain)
                    items.append("Change your password at \(domain)")
                }
            case .passwordExposure:
                items.append("Stop using compromised password: \(finding.title)")
            case .dnsChange:
                items.append("Verify DNS records are correct: \(finding.title)")
            case .paste:
                items.append("Review paste exposure: \(finding.title)")
            }
        }
        return items
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
