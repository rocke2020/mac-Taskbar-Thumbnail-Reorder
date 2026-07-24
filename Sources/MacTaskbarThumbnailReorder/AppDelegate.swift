import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var thumbnailController: ThumbnailPanelController?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// The app that was frontmost *before* the panel appeared, so we can restore
    /// focus when the user dismisses without choosing a window.
    private weak var previousFrontmostApp: NSRunningApplication?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestAccessibilityPermission()
        setupGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor  { NSEvent.removeMonitor(monitor) }
    }

    // MARK: - Status-bar item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Thumbnail Reorder")
        button.toolTip = "mac Taskbar Thumbnail Reorder\nClick to show windows for the current app\nShortcut: ⌃` (Control + Backtick)"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu()
        } else {
            triggerThumbnailPanel()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window Thumbnails  ⌃`", action: #selector(triggerThumbnailPanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "About mac Taskbar Thumbnail Reorder", action: #selector(showAbout), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
            .target = self
        statusItem?.popUpMenu(menu)
    }

    // MARK: - Global Hotkey  (Control + `)

    /// Registers a global event monitor for the ⌃` (Control + Backtick) shortcut.
    /// Key code 50 = backtick on US keyboard layouts.
    private func setupGlobalHotkey() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.control),
                  event.keyCode == 50 else { return }
            DispatchQueue.main.async { self?.triggerThumbnailPanel() }
        }

        // Also capture when our own panel is key (local monitor).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // ESC → dismiss the panel.
            if event.keyCode == 53 {
                self?.thumbnailController?.hide(restorePreviousApp: true)
                return nil
            }
            // ⌃` → retrigger (refresh).
            if event.modifierFlags.contains(.control), event.keyCode == 50 {
                DispatchQueue.main.async { self?.triggerThumbnailPanel() }
                return nil
            }
            return event
        }
    }

    // MARK: - Show Panel

    @objc func triggerThumbnailPanel() {
        // Capture the true frontmost app *before* our panel steals focus.
        let frontmost = NSWorkspace.shared.frontmostApplication

        // Ignore if the frontmost app is us (already showing the panel).
        guard frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }

        previousFrontmostApp = frontmost

        if thumbnailController == nil {
            thumbnailController = ThumbnailPanelController()
        }

        if let thumbnailController, thumbnailController.isVisible {
            // Toggle off.
            thumbnailController.hide(restorePreviousApp: true)
            return
        }

        guard let app = frontmost else { return }
        thumbnailController?.show(for: app, previousApp: previousFrontmostApp)
    }

    // MARK: - Actions

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(self)
    }

    @objc private func quitApp() {
        NSApp.terminate(self)
    }

    // MARK: - Permissions

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            showPermissionAlert(
                title: "Accessibility Permission Required",
                message: "mac Taskbar Thumbnail Reorder needs Accessibility access to switch between windows.\n\nPlease grant access in System Settings → Privacy & Security → Accessibility."
            )
        }

        // Trigger Screen Recording permission dialog by making an innocuous CGWindowList call.
        _ = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)
    }

    private func showPermissionAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }
}
