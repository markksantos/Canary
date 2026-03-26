import SwiftUI
import CanaryEngine
import CanaryUI

@main
struct CanaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var engine = Engine()

    var body: some Scene {
        MenuBarExtra {
            Group {
                if engine.onboardingCompleted {
                    DashboardView()
                } else {
                    OnboardingView()
                }
            }
            .environment(engine)
            .task {
                appDelegate.onTerminate = { [engine] in engine.shutdown() }
                await engine.start()
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: menuBarIcon)
                    .symbolRenderingMode(.hierarchical)
                if engine.newFindingsCount > 0 {
                    Text("\(engine.newFindingsCount)")
                        .font(.caption2.bold())
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        Theme.menuBarIconName(
            hasExposure: engine.overallStatus == .exposed,
            isScanning: engine.isScanning
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var onTerminate: (() -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var rightClickMonitor: Any?
    private var statusButton: NSStatusBarButton?

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerGlobalHotkey()

        // Defer status button discovery to let SwiftUI set up the MenuBarExtra
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setupRightClickMenu()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = rightClickMonitor { NSEvent.removeMonitor(monitor) }
        onTerminate?()
    }

    // MARK: - Right-Click Menu

    private func setupRightClickMenu() {
        // Find the NSStatusBarButton created by SwiftUI's MenuBarExtra
        for window in NSApp.windows {
            let windowClass = String(describing: type(of: window))
            if windowClass.contains("NSStatusBarWindow") {
                if let button = window.contentView?.subviews.compactMap({ $0 as? NSStatusBarButton }).first {
                    statusButton = button
                    break
                }
            }
        }

        // Monitor for right-clicks on the status bar area
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseUp]) { [weak self] event in
            guard let self = self, let button = self.statusButton else { return event }

            // Check if the click is within the status bar button
            let locationInButton = button.convert(event.locationInWindow, from: nil)
            if button.bounds.contains(locationInButton) {
                self.showContextMenu(from: button)
                return nil
            }
            return event
        }
    }

    private func showContextMenu(from button: NSView) {
        let menu = NSMenu()

        let scanItem = NSMenuItem(title: "Check Now", action: #selector(menuScan), keyEquivalent: "r")
        scanItem.keyEquivalentModifierMask = .command
        scanItem.target = self
        menu.addItem(scanItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Canary", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        menu.addItem(quitItem)

        // Position the menu below the status bar button
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func menuScan() {
        // Open the popover first, then the scan will be visible
        statusButton?.performClick(nil)
    }

    @objc private func menuSettings() {
        statusButton?.performClick(nil)
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Global Hotkey

    private func registerGlobalHotkey() {
        // Cmd+Shift+C to toggle popover
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleHotkey(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleHotkey(event) == true { return nil }
            return event
        }
    }

    @discardableResult
    private func handleHotkey(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains([.command, .shift]),
              event.charactersIgnoringModifiers?.lowercased() == "c" else {
            return false
        }
        toggleMenuBarPopover()
        return true
    }

    private func toggleMenuBarPopover() {
        if let button = statusButton {
            button.performClick(nil)
            return
        }
        // Fallback: search for the button
        for window in NSApp.windows {
            let windowClass = String(describing: type(of: window))
            if windowClass.contains("NSStatusBarWindow") {
                if let button = window.contentView?.subviews.compactMap({ $0 as? NSControl }).first {
                    button.performClick(nil)
                    return
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
