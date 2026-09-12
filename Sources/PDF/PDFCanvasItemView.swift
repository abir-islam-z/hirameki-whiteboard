import AppKit
import PDFKit

public protocol PDFCanvasItemDelegate: AnyObject {
    func pdfItemDidUpdateFrame(_ item: EmbeddedPDF)
    func pdfItemDidRequestDelete(_ item: EmbeddedPDF)
    func pdfItemCurrentZoomScale() -> CGFloat
}

public final class PDFCanvasItemView: NSView {
    public var embeddedPDF: EmbeddedPDF
    public weak var delegate: PDFCanvasItemDelegate?

    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var pageLabel: NSTextField!
    private var prevPageButton: NSButton!
    private var nextPageButton: NSButton!
    private var deleteButton: NSButton!

    private var isDragging: Bool = false
    private var dragStartMouse: CGPoint = .zero
    private var dragStartOrigin: CGPoint = .zero

    public init(embeddedPDF: EmbeddedPDF) {
        self.embeddedPDF = embeddedPDF
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 34))
        setupViews()
        updatePaginationUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 17
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.18, alpha: 0.90).cgColor
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        layer?.borderWidth = 1.0
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -3)

        // 1. PDF File Icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 8, width: 18, height: 18))
        iconView.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "PDF")
        iconView.contentTintColor = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        addSubview(iconView)

        // 2. Title Label
        titleLabel = NSTextField(labelWithString: embeddedPDF.title)
        titleLabel.font = .systemFont(ofSize: 11.5, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 32, y: 7, width: 130, height: 20)
        titleLabel.cell?.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        // 3. Page Controls Capsule
        prevPageButton = NSButton(title: "‹", target: self, action: #selector(goToPrevPage))
        prevPageButton.bezelStyle = .texturedRounded
        prevPageButton.isBordered = false
        prevPageButton.font = .systemFont(ofSize: 15, weight: .bold)
        prevPageButton.contentTintColor = .white
        prevPageButton.frame = NSRect(x: 168, y: 5, width: 20, height: 24)
        addSubview(prevPageButton)

        pageLabel = NSTextField(labelWithString: "1 / 1")
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        pageLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
        pageLabel.alignment = .center
        pageLabel.frame = NSRect(x: 188, y: 7, width: 50, height: 20)
        addSubview(pageLabel)

        nextPageButton = NSButton(title: "›", target: self, action: #selector(goToNextPage))
        nextPageButton.bezelStyle = .texturedRounded
        nextPageButton.isBordered = false
        nextPageButton.font = .systemFont(ofSize: 15, weight: .bold)
        nextPageButton.contentTintColor = .white
        nextPageButton.frame = NSRect(x: 238, y: 5, width: 20, height: 24)
        addSubview(nextPageButton)

        // Separator
        let sep = NSBox(frame: NSRect(x: 264, y: 8, width: 1, height: 18))
        sep.boxType = .custom
        sep.borderWidth = 0
        sep.fillColor = NSColor(white: 1.0, alpha: 0.20)
        addSubview(sep)

        // 4. Delete Button
        deleteButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove PDF") ?? NSImage(),
            target: self,
            action: #selector(deletePDF)
        )
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.isBordered = false
        deleteButton.contentTintColor = NSColor(white: 0.70, alpha: 1.0)
        deleteButton.frame = NSRect(x: 271, y: 7, width: 20, height: 20)
        addSubview(deleteButton)
    }

    public func updatePaginationUI() {
        let current = embeddedPDF.currentPage + 1
        let total = max(1, embeddedPDF.pageCount)
        pageLabel.stringValue = "\(current) / \(total)"
        prevPageButton.isEnabled = current > 1
        nextPageButton.isEnabled = current < total
        prevPageButton.alphaValue = current > 1 ? 1.0 : 0.35
        nextPageButton.alphaValue = current < total ? 1.0 : 0.35
    }

    @objc private func goToPrevPage() {
        if embeddedPDF.currentPage > 0 {
            embeddedPDF.currentPage -= 1
            updatePaginationUI()
            delegate?.pdfItemDidUpdateFrame(embeddedPDF)
        }
    }

    @objc private func goToNextPage() {
        if embeddedPDF.currentPage < embeddedPDF.pageCount - 1 {
            embeddedPDF.currentPage += 1
            updatePaginationUI()
            delegate?.pdfItemDidUpdateFrame(embeddedPDF)
        }
    }

    @objc private func deletePDF() {
        delegate?.pdfItemDidRequestDelete(embeddedPDF)
    }

    // Drag capsule to move PDF on infinite canvas.
    // We must not intercept clicks that land on interactive controls (buttons),
    // otherwise their target-action never fires.
    public override func mouseDown(with event: NSEvent) {
        let localPt = convert(event.locationInWindow, from: nil)
        let interactiveViews: [NSView] = [prevPageButton, nextPageButton, deleteButton]
        let hitControl = interactiveViews.contains { btn in btn.frame.contains(localPt) }
        if hitControl {
            // Let AppKit route normally so the button target-action fires
            super.mouseDown(with: event)
            return
        }
        isDragging = true
        dragStartMouse = event.locationInWindow
        dragStartOrigin = embeddedPDF.origin
    }

    public override func mouseDragged(with event: NSEvent) {
        if isDragging {
            let zoom = delegate?.pdfItemCurrentZoomScale() ?? 1.0
            let deltaX = (event.locationInWindow.x - dragStartMouse.x) / zoom
            let deltaY = (event.locationInWindow.y - dragStartMouse.y) / zoom
            embeddedPDF.origin = CGPoint(x: dragStartOrigin.x + deltaX, y: dragStartOrigin.y + deltaY)
            delegate?.pdfItemDidUpdateFrame(embeddedPDF)
            return
        }
        super.mouseDragged(with: event)
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
        super.mouseUp(with: event)
    }
}

