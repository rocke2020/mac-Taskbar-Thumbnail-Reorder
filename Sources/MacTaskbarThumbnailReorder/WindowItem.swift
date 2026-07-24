import AppKit
import CoreGraphics

/// Represents a single macOS window that can be shown as a thumbnail.
struct WindowItem: Hashable {
    /// Core Graphics window ID – stable across frames.
    let windowID: CGWindowID

    /// PID of the owning process.
    let pid: pid_t

    /// Window title (may be empty for some windows).
    let title: String

    /// Localized process name (e.g. "Safari", "Finder").
    let ownerName: String

    /// Thumbnail image captured from the window, or nil when Screen Recording
    /// permission has not been granted.
    var image: NSImage?

    // MARK: Hashable / Equatable

    static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
        lhs.windowID == rhs.windowID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }
}
