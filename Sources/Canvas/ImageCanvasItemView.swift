import AppKit

public protocol ImageCanvasItemDelegate: AnyObject {
    func imageItemDidUpdateFrame(_ item: EmbeddedImage)
    func imageItemDidRequestDelete(_ item: EmbeddedImage)
    func imageItemCurrentZoomScale() -> CGFloat
}

// MARK: - ImageCanvasItemView
// A frosted-glass bottom-inset overlay that sits *inside* the image's rendered rect.
// The canvas positions it via layoutImageItem(); this view has no drag logic.
public final class ImageCanvasItemView: NSView {
    public var embeddedImage: EmbeddedImage
    public weak var delegate: ImageCanvasItemDelegate?

    private var blurView: NSVisualEffectView!
    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var deleteButton: NSButton!

    // Fixed bar height in screen points (independent of zoom)
    public static let barHeight: CGFloat = 34

    public init(embeddedImage: EmbeddedImage) {
        self.embeddedImage = embeddedImage
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Frosted-glass backdrop
        blurView = NSVisualEffectView(frame: bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.material = .hudWindow
        blurView.blendingMode = .withinWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = 10
        blurView.layer?.masksToBounds = true
        blurView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        blurView.layer?.borderWidth = 0.75
        addSubview(blurView)

        // Drop shadow on container
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        // 1. Photo icon
        iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: "Image")
        iconView.contentTintColor = NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)
        addSubview(iconView)

        // 2. Title
        titleLabel = NSTextField(labelWithString: embeddedImage.title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.cell?.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        // 3. Delete button
        deleteButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill",
                           accessibilityDescription: "Remove Image") ?? NSImage(),
            target: self,
            action: #selector(deleteImage)
        )
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.isBordered = false
        deleteButton.contentTintColor = NSColor.tertiaryLabelColor
        addSubview(deleteButton)
    }

    // MARK: - Layout
    public override func layout() {
        super.layout()
        let h = bounds.height
        let w = bounds.width

        blurView.frame = bounds

        let iconSize: CGFloat = 16
        iconView.frame = NSRect(x: 10, y: (h - iconSize) / 2, width: iconSize, height: iconSize)

        let delW: CGFloat = 22
        let delX = w - delW - 8
        deleteButton.frame = NSRect(x: delX, y: (h - 20) / 2, width: delW, height: 20)

        let titleX: CGFloat = 30
        let titleW = max(0, delX - titleX - 6)
        titleLabel.frame = NSRect(x: titleX, y: (h - 18) / 2, width: titleW, height: 18)
    }

    @objc private func deleteImage() {
        delegate?.imageItemDidRequestDelete(embeddedImage)
    }

    // Only intercept clicks on the delete button; let everything else pass to canvas
    public override func mouseDown(with event: NSEvent) {
        let localPt = convert(event.locationInWindow, from: nil)
        if deleteButton.frame.contains(localPt) {
            super.mouseDown(with: event)
        }
    }

    public override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}
