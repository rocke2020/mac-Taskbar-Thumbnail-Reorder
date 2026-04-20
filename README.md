# mac Taskbar Thumbnail Reorder

A macOS background utility that shows draggable window thumbnails for the frontmost application — similar to the [Windhawk taskbar-thumbnail-reorder mod](https://windhawk.net/mods/taskbar-thumbnail-reorder) for Windows.

![mac Taskbar Thumbnail Reorder demo](docs/demo.gif)

## Features

| Feature | Description |
|---------|-------------|
| **Window Thumbnails** | Live screenshots of every open window for the active app |
| **Drag to Reorder** | Drag-and-drop thumbnails to arrange them in your preferred order |
| **Persistent Order** | The custom order is saved per-app and restored next time |
| **Fast Switch** | Click any thumbnail to instantly bring that window to the front |
| **Menu Bar Icon** | Runs silently in the background with a menu-bar icon |
| **Global Shortcut** | Press **⌃`** (Control + Backtick) from any app to show the panel |

## Requirements

- macOS 12 Monterey or later
- Xcode 14+ **or** Swift 5.9+ toolchain

### Permissions

The app requests two macOS permissions on first launch:

| Permission | Purpose |
|------------|---------|
| **Accessibility** | Required to raise a specific window via the Accessibility API |
| **Screen Recording** | Required to capture window thumbnails |

Both are granted in **System Settings → Privacy & Security**.

## Building

### With Swift Package Manager (command line)

```bash
git clone https://github.com/rocke2020/mac-Taskbar-Thumbnail-Reorder.git
cd mac-Taskbar-Thumbnail-Reorder
swift build -c release
```

The compiled binary will be at `.build/release/MacTaskbarThumbnailReorder`.  
Run it directly or wrap it in an `.app` bundle (see below).

### With Xcode

```bash
open Package.swift   # Opens the project in Xcode
```

Then **Product → Archive** to create a distributable `.app`.

### Creating a standalone .app bundle

```bash
# Build release binary
swift build -c release

# Create bundle structure
mkdir -p MacTaskbarThumbnailReorder.app/Contents/MacOS
cp .build/release/MacTaskbarThumbnailReorder \
   MacTaskbarThumbnailReorder.app/Contents/MacOS/

# Minimal Info.plist (background agent, no Dock icon)
cat > MacTaskbarThumbnailReorder.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleIdentifier</key>
    <string>com.rocke2020.mac-taskbar-thumbnail-reorder</string>
    <key>CFBundleName</key>
    <string>mac Taskbar Thumbnail Reorder</string>
    <key>CFBundleExecutable</key>
    <string>MacTaskbarThumbnailReorder</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict></plist>
EOF
```

## Usage

1. Launch the app — a **⊞** icon appears in the menu bar.
2. Switch to any app that has multiple windows open.
3. Press **⌃`** (Control + Backtick) **or** click the menu-bar icon.
4. A thumbnail panel slides up just above the Dock showing all windows.
5. **Click** a thumbnail to switch to that window.
6. **Drag** thumbnails left or right to reorder them — the order is saved automatically.
7. Press **⎋** (Escape) or click the **✕** button to dismiss.

> **Tip:** Right-click the menu-bar icon for additional options including Quit.

## Architecture

```
Sources/MacTaskbarThumbnailReorder/
├── main.swift                       # NSApplication entry point (background agent)
├── AppDelegate.swift                # Menu-bar icon, global hotkey (⌃`), permissions
├── WindowItem.swift                 # Data model for a single window
├── WindowManager.swift              # CGWindowList discovery, screenshot capture,
│                                    # Accessibility-based focus, order persistence
├── ThumbnailPanelController.swift   # Floating NSPanel with NSCollectionView,
│                                    # drag-and-drop reorder, selection handling
└── ThumbnailCollectionViewItem.swift# Individual thumbnail cell with hover effects
```

### Key technologies

- **CGWindowListCopyWindowInfo** — enumerate all on-screen windows for a process
- **CGWindowListCreateImage** — capture a live screenshot of each window
- **AXUIElement / Accessibility API** — raise a specific window to the front
- **NSCollectionView** — horizontal scrollable grid with built-in drag-and-drop
- **UserDefaults** — persist the custom window order per app bundle ID
- **NSEvent global monitor** — register the system-wide ⌃` keyboard shortcut

## Privacy & Security

- The app captures window content only when the panel is explicitly triggered by the user.
- No data is sent anywhere — everything stays on-device.
- Window order preferences are stored only in `~/Library/Preferences` via `UserDefaults`.

## License

[MIT](LICENSE) © 2026 Rocke Dong
