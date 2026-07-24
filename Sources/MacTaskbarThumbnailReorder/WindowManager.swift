import AppKit
import ApplicationServices
import CoreGraphics

/// Handles window discovery, screenshot capture, reorder persistence, and window focusing.
final class WindowManager {

    static let shared = WindowManager()
    private init() {}

    // MARK: - UserDefaults key prefix for saved order

    private static let orderKeyPrefix = "windowOrder."

    // MARK: - Window Discovery

    /// Returns an ordered list of ``WindowItem``s for the given running application.
    /// The order is restored from the last saved preference when available.
    func getWindows(for app: NSRunningApplication) -> [WindowItem] {
        let pid = app.processIdentifier
        guard pid != -1 else { return [] }

        // Fetch all on-screen windows (layer 0 = normal windows).
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var items: [WindowItem] = []
        for info in raw {
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                ownerPID == pid,
                let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,                             // normal window layer only
                let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                let width = boundsDict["Width"], width > 50,
                let height = boundsDict["Height"], height > 50
            else { continue }

            let title = info[kCGWindowName as String] as? String ?? ""
            let ownerName = info[kCGWindowOwnerName as String] as? String ?? app.localizedName ?? ""
            let thumbnail = captureWindow(windowID: windowID)

            items.append(WindowItem(
                windowID: windowID,
                pid: pid,
                title: title,
                ownerName: ownerName,
                image: thumbnail
            ))
        }

        return applyStoredOrder(items, for: app)
    }

    // MARK: - Screenshot

    /// Captures a window thumbnail. Returns nil when Screen Recording permission has
    /// not been granted – the caller should show a placeholder image instead.
    private func captureWindow(windowID: CGWindowID) -> NSImage? {
        let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        )
        guard let cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Window Focus

    /// Brings the app to the foreground and raises the specific window via the
    /// Accessibility API, first matching by screen position then falling back to title.
    func focusWindow(_ item: WindowItem) {
        guard let runningApp = NSRunningApplication(processIdentifier: item.pid) else { return }
        runningApp.activate(options: .activateIgnoringOtherApps)

        // Give the app a moment to activate before raising the window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.raiseAXWindow(for: item)
        }
    }

    private func raiseAXWindow(for item: WindowItem) {
        let axApp = AXUIElementCreateApplication(item.pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return }

        // Prefer matching by on-screen position (more reliable than title for multi-window apps).
        if let bounds = cgWindowBounds(for: item.windowID) {
            for axWindow in axWindows {
                if let pos = axWindowPosition(axWindow),
                   abs(pos.x - bounds.origin.x) < 10,
                   abs(pos.y - bounds.origin.y) < 10 {
                    AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    return
                }
            }
        }

        // Fallback: match by title.
        for axWindow in axWindows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            if (titleRef as? String) == item.title {
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                return
            }
        }
    }

    // MARK: - Order Persistence

    /// Saves the current window order (by title) for the given app's bundle identifier.
    func saveOrder(_ items: [WindowItem], for app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        let key = Self.orderKeyPrefix + bundleID
        let titles = items.map { $0.title }
        UserDefaults.standard.set(titles, forKey: key)
    }

    /// Re-orders *items* to match the last saved order for the given app, appending
    /// any newly discovered windows at the end.
    private func applyStoredOrder(_ items: [WindowItem], for app: NSRunningApplication) -> [WindowItem] {
        guard let bundleID = app.bundleIdentifier,
              let savedTitles = UserDefaults.standard.stringArray(forKey: Self.orderKeyPrefix + bundleID) else {
            return items
        }

        var remaining = items
        var ordered: [WindowItem] = []

        for title in savedTitles {
            if let idx = remaining.firstIndex(where: { $0.title == title }) {
                ordered.append(remaining.remove(at: idx))
            }
        }
        ordered.append(contentsOf: remaining) // append newly opened windows
        return ordered
    }

    // MARK: - Helpers

    private func cgWindowBounds(for windowID: CGWindowID) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let boundsDict = info.first?[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        return CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
    }

    private func axWindowPosition(_ element: AXUIElement) -> CGPoint? {
        var posRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
              let posRef else { return nil }
        // AXValue is a Core Foundation type; bridge it via unsafeBitCast.
        let axValue = unsafeBitCast(posRef, to: AXValue.self)
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }
}
