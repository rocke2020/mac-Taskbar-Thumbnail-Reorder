import AppKit

/// NSCollectionViewItem that shows a single window thumbnail with its title.
/// Supports hover highlighting and selected-state highlighting.
final class ThumbnailCollectionViewItem: NSCollectionViewItem {

    // MARK: - Subviews

    private let container = NSView()
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let placeholderLabel = NSTextField(labelWithString: "🔒 No Preview\n(Screen Recording\npermission needed)")

    // MARK: - View Loading

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 150))
        setupSubviews()
        setupTrackingArea()
    }

    // MARK: - Configuration

    /// Populates the view with data from a ``WindowItem``.
    func configure(with item: WindowItem) {
        if let img = item.image {
            imageView.image = img
            imageView.isHidden = false
            placeholderLabel.isHidden = true
        } else {
            imageView.isHidden = true
            placeholderLabel.isHidden = false
        }

        let displayTitle = item.title.isEmpty ? item.ownerName : item.title
        titleLabel.stringValue = displayTitle
        titleLabel.toolTip = displayTitle
    }

    // MARK: - Appearance

    override var isSelected: Bool {
        didSet { updateContainerBackground() }
    }

    private var isHovered = false

    private func updateContainerBackground() {
        container.layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.withAlphaComponent(0.55).cgColor
            : (isHovered
                ? NSColor.white.withAlphaComponent(0.25).cgColor
                : NSColor.white.withAlphaComponent(0.12).cgColor)
    }

    // MARK: - Mouse Tracking

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateContainerBackground()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateContainerBackground()
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: view.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(trackingArea)
    }

    // MARK: - Layout

    private func setupSubviews() {
        // Container – rounded rectangle with translucent fill
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        // Thumbnail image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 4
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)

        // Placeholder for missing screenshot permission
        placeholderLabel.alignment = .center
        placeholderLabel.textColor = NSColor.secondaryLabelColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 10)
        placeholderLabel.isHidden = true
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(placeholderLabel)

        // Title label
        titleLabel.textColor = .white
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // Container fills most of the cell
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),

            // Image fills the top portion of the container
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            imageView.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -4),

            // Placeholder overlays the image area
            placeholderLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),

            // Title label at the bottom
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            titleLabel.heightAnchor.constraint(equalToConstant: 18)
        ])

        updateContainerBackground()
    }
}
