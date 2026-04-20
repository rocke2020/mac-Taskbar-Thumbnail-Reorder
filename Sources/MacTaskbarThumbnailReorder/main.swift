import AppKit

// Run as a background "agent" app (no Dock icon, menu-bar only).
NSApplication.shared.setActivationPolicy(.accessory)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
