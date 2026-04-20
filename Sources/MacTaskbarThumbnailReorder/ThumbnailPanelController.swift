import AppKit

// MARK: - Pasteboard type used for intra-collection drag-and-drop

private extension NSPasteboard.PasteboardType {
    static let thumbnailReorderItem = NSPasteboard.PasteboardType("com.mac-taskbar-thumbnail-reorder.item")
}

// MARK: - ThumbnailPanelController

/// Manages the floating panel that displays window thumbnails for the current app.
///
/// The panel appears above the Dock and supports:
/// - Drag-and-drop reordering of thumbnails
/// - Single-click to switch to a window
/// - ESC / click-outside / close button to dismiss
final class ThumbnailPanelController: NSObject {

    // MARK: - State

    private var panel: NSPanel?
    private var collectionView: NSCollectionView!
    private var scrollView: NSScrollView!
    private var appIconView: NSImageView!
    private var appNameLabel: NSTextField!
    private var hintLabel: NSTextField!
    private var closeButton: NSButton!

    private var items: [WindowItem] = []
    private weak var currentApp: NSRunningApplication?
    private weak var previousApp: NSRunningApplication?

    // MARK: - Layout Constants

    private let itemWidth: CGFloat  = 200
    private let itemHeight: CGFloat = 160
    private let headerHeight: CGFloat = 32
    private let panelPadding: CGFloat = 12
    private let maxVisibleItems: Int = 5

    private var panelHeight: CGFloat { itemHeight + headerHeight + panelPadding * 2 }
    private var itemSpacing: CGFloat { 8 }

    // MARK: - Public API

    /// Shows the thumbnail panel for *app*, remembering *previousApp* so focus
    /// can be restored if the user dismisses without picking a window.
    func show(for app: NSRunningApplication, previousApp: NSRunningApplication?) {
        self.previousApp = previousApp
        self.currentApp = app

        // Fetch windows on the main thread (CGWindowList requirement).
        let fetched = WindowManager.shared.getWindows(for: app)

        guard !fetched.isEmpty else {
            showNoWindowsNotice(appName: app.localizedName ?? app.bundleIdentifier ?? "Unknown")
            return
        }

        items = fetched
        buildPanelIfNeeded()
        updateHeader(app: app)
        layoutPanel()
        collectionView.reloadData()
        panel?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func hide(restorePreviousApp: Bool = false) {
        panel?.orderOut(nil)
        if restorePreviousApp {
            previousApp?.activate(options: .activateIgnoringOtherApps)
        }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    // MARK: - Panel Construction

    private func buildPanelIfNeeded() {
        guard panel == nil else { return }

        let dummyFrame = NSRect(x: 0, y: 0, width: 400, height: panelHeight)

        let newPanel = NSPanel(
            contentRect: dummyFrame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = true

        // Visual-effect backdrop (frosted glass)
        let backdrop = NSVisualEffectView(frame: newPanel.contentView!.bounds)
        backdrop.material = .hudWindow
        backdrop.state = .active
        backdrop.blendingMode = .behindWindow
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 14
        backdrop.layer?.masksToBounds = true
        backdrop.autoresizingMask = [.width, .height]
        newPanel.contentView?.addSubview(backdrop)

        buildHeader(in: backdrop)
        buildCollectionView(in: backdrop)

        self.panel = newPanel
    }

    private func buildHeader(in parent: NSView) {
        // App icon
        appIconView = NSImageView(frame: NSRect(x: panelPadding, y: panelHeight - headerHeight - panelPadding + 4, width: 20, height: 20))
        appIconView.imageScaling = .scaleProportionallyUpOrDown
        appIconView.autoresizingMask = [.maxXMargin, .minYMargin]
        parent.addSubview(appIconView)

        // App name label
        appNameLabel = NSTextField(labelWithString: "")
        appNameLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        appNameLabel.textColor = .secondaryLabelColor
        appNameLabel.frame = NSRect(x: panelPadding + 26, y: panelHeight - headerHeight - panelPadding + 6, width: 300, height: 16)
        appNameLabel.autoresizingMask = [.maxXMargin, .minYMargin]
        parent.addSubview(appNameLabel)

        // Keyboard shortcut hint
        hintLabel = NSTextField(labelWithString: "Click to switch  •  Drag to reorder  •  ⎋ to dismiss")
        hintLabel.font = NSFont.systemFont(ofSize: 10)
        hintLabel.textColor = NSColor.tertiaryLabelColor
        hintLabel.alignment = .right
        hintLabel.autoresizingMask = [.minXMargin, .minYMargin]
        parent.addSubview(hintLabel)

        // Close button
        closeButton = NSButton()
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeTapped)
        parent.addSubview(closeButton)
    }

    private func buildCollectionView(in parent: NSView) {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = NSSize(width: itemWidth, height: itemHeight)
        layout.minimumInteritemSpacing = itemSpacing
        layout.sectionInset = NSEdgeInsets(top: panelPadding, left: panelPadding,
                                            bottom: panelPadding, right: panelPadding)

        collectionView = NSCollectionView()
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = true
        collectionView.register(
            ThumbnailCollectionViewItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("ThumbnailItem")
        )
        collectionView.backgroundColors = [.clear]

        // Enable drag-and-drop reordering
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        collectionView.registerForDraggedTypes([.thumbnailReorderItem])

        scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.autoresizingMask = [.width, .height]
        parent.addSubview(scrollView)
    }

    // MARK: - Layout

    private func layoutPanel() {
        guard let panel else { return }
        guard let screen = NSScreen.main else { return }

        let visible = min(items.count, maxVisibleItems)
        let contentW = CGFloat(items.count) * (itemWidth + itemSpacing) + itemSpacing + panelPadding
        let panelW = min(
            CGFloat(visible) * (itemWidth + itemSpacing) + itemSpacing + panelPadding * 2,
            screen.visibleFrame.width - 40
        )

        let x = screen.visibleFrame.midX - panelW / 2
        let y = screen.visibleFrame.minY + 20        // just above the Dock
        panel.setFrame(NSRect(x: x, y: y, width: panelW, height: panelHeight), display: true)

        // Scroll view fills the bottom portion
        let svY: CGFloat = 0
        let svH = panelHeight - headerHeight - panelPadding
        scrollView.frame = NSRect(x: 0, y: svY, width: panelW, height: svH)

        // Content size of the collection view
        collectionView.setFrameSize(NSSize(width: max(contentW, panelW), height: svH))

        // Header items
        let headerY = panelHeight - headerHeight - panelPadding + 6
        appIconView.frame = NSRect(x: panelPadding, y: headerY, width: 20, height: 20)
        appNameLabel.frame = NSRect(x: panelPadding + 26, y: headerY + 2, width: 250, height: 16)

        let closeBtnSize: CGFloat = 20
        closeButton.frame = NSRect(x: panelW - panelPadding - closeBtnSize,
                                   y: headerY,
                                   width: closeBtnSize,
                                   height: closeBtnSize)
        hintLabel.frame = NSRect(x: panelPadding + 26 + 250 + 4,
                                 y: headerY + 2,
                                 width: panelW - (panelPadding + 26 + 250 + 4) - closeBtnSize - panelPadding * 2,
                                 height: 14)
    }

    private func updateHeader(app: NSRunningApplication) {
        appIconView.image = app.icon
        appNameLabel.stringValue = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        hide(restorePreviousApp: true)
    }

    // MARK: - No-windows feedback

    private func showNoWindowsNotice(appName: String) {
        let alert = NSAlert()
        alert.messageText = "No Windows Found"
        alert.informativeText = "\(appName) has no open windows to display."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSCollectionViewDataSource

extension ThumbnailPanelController: NSCollectionViewDataSource {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let base = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("ThumbnailItem"),
            for: indexPath
        )
        guard let cell = base as? ThumbnailCollectionViewItem else { return base }
        cell.configure(with: items[indexPath.item])
        return cell
    }
}

// MARK: - NSCollectionViewDelegate (selection + drag-and-drop)

extension ThumbnailPanelController: NSCollectionViewDelegate {

    // MARK: Selection → switch window

    func collectionView(_ collectionView: NSCollectionView,
                        didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let item = items[indexPath.item]
        hide()
        WindowManager.shared.focusWindow(item)
    }

    // MARK: Drag source

    func collectionView(_ collectionView: NSCollectionView,
                        canDragItemsAt indexPaths: Set<IndexPath>,
                        with event: NSEvent) -> Bool { true }

    func collectionView(_ collectionView: NSCollectionView,
                        pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        let pb = NSPasteboardItem()
        pb.setString(String(indexPath.item), forType: .thumbnailReorderItem)
        return pb
    }

    // MARK: Drag destination

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        proposedDropOperation.pointee = .before
        return .move
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard
            let pbItem = draggingInfo.draggingPasteboard.pasteboardItems?.first,
            let sourceStr = pbItem.string(forType: .thumbnailReorderItem),
            let sourceIndex = Int(sourceStr)
        else { return false }

        var destIndex = indexPath.item
        guard sourceIndex != destIndex else { return false }

        // Adjust destination index to account for the removal of the source item.
        let adjustedDest = sourceIndex < destIndex ? destIndex - 1 : destIndex

        // Update data.
        let moved = items.remove(at: sourceIndex)
        items.insert(moved, at: adjustedDest)

        // Persist the new order.
        if let app = currentApp {
            WindowManager.shared.saveOrder(items, for: app)
        }

        // Animate the visual move.
        collectionView.animator().moveItem(
            at: IndexPath(item: sourceIndex, section: 0),
            to: IndexPath(item: adjustedDest, section: 0)
        )
        return true
    }
}
