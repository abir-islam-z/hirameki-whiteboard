import AppKit

public protocol ImageCanvasItemDelegate: AnyObject {
    func imageItemDidUpdateFrame(_ item: EmbeddedImage)
    func imageItemDidRequestDelete(_ item: EmbeddedImage)
    func imageItemCurrentZoomScale() -> CGFloat
}

public final class ImageCanvasItemView: NSView {
    public var embeddedImage: EmbeddedImage
    public weak var delegate: ImageCanvasItemDelegate?

    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var deleteButton: NSButton!

    private var isDragging: Bool = false
    private var dragStartMouse: CGPoint = .zero
    private var dragStartOrigin: CGPoint = .zero

    public init(embeddedImage: EmbeddedImage) {
        self.embeddedImage = embeddedImage
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 32))
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.18, alpha: 0.90).cgColor
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        layer?.borderWidth = 1.0
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -3)

        // 1. Photo Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 7, width: 18, height: 18))
        iconView.image = NSImage(systemSymbolName: "photo.fill", accessibilityDescription: "Image")
        iconView.contentTintColor = NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)
        addSubview(iconView)

        // 2. Title Label
        titleLabel = NSTextField(labelWithString: embeddedImage.title)
        titleLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 32, y: 6, width: 150, height: 20)
        titleLabel.cell?.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        // 3. Delete Button
        deleteButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove Image") ?? NSImage(),
            target: self,
            action: #selector(deleteImage)
        )
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.isBordered = false
        deleteButton.contentTintColor = NSColor(white: 0.70, alpha: 1.0)
        deleteButton.frame = NSRect(x: 190, y: 6, width: 20, height: 20)
        addSubview(deleteButton)
    }

    @objc private func deleteImage() {
        delegate?.imageItemDidRequestDelete(embeddedImage)
    }

    // Drag capsule to move Image on infinite canvas
    public override func mouseDown(with event: NSEvent) {
        isDragging = true
        dragStartMouse = event.locationInWindow
        dragStartOrigin = embeddedImage.origin
        window?.makeFirstResponder(self)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentMouse = event.locationInWindow
        let deltaScreenX = currentMouse.x - dragStartMouse.x
        let deltaScreenY = currentMouse.y - dragStartMouse.y
        let zoom = delegate?.imageItemCurrentZoomScale() ?? 1.0

        let deltaCanvasX = deltaScreenX / zoom
        let deltaCanvasY = deltaScreenY / zoom

        embeddedImage.origin = CGPoint(
            x: dragStartOrigin.x + deltaCanvasX,
            y: dragStartOrigin.y + deltaCanvasY
        )
        delegate?.imageItemDidUpdateFrame(embeddedImage)
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }
}
