import AppKit
import PDFKit

public protocol PDFCanvasItemDelegate: AnyObject {
    func pdfItemDidUpdateFrame(_ item: EmbeddedPDF)
    func pdfItemDidRequestDelete(_ item: EmbeddedPDF)
    func pdfItemCurrentZoomScale() -> CGFloat
}

// MARK: - PDFCanvasItemView
// A frosted-glass bottom-inset overlay that sits *inside* the PDF's rendered rect.
// The canvas positions it via layoutPDFItem(); this view itself has no drag logic.
public final class PDFCanvasItemView: NSView {
    public var embeddedPDF: EmbeddedPDF
    public weak var delegate: PDFCanvasItemDelegate?

    private var blurView: NSVisualEffectView!
    private var iconView: NSImageView!
    private var titleLabel: NSTextField!
    private var pageLabel: NSTextField!
    private var prevPageButton: NSButton!
    private var nextPageButton: NSButton!
    private var deleteButton: NSButton!

    // Fixed bar height in screen points (independent of zoom)
    public static let barHeight: CGFloat = 34

    public init(embeddedPDF: EmbeddedPDF) {
        self.embeddedPDF = embeddedPDF
        super.init(frame: .zero)
        setupViews()
        updatePaginationUI()
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
        // Subtle border over the blur
        blurView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.18).cgColor
        blurView.layer?.borderWidth = 0.75
        addSubview(blurView)

        // Drop shadow on the container (not the blur view, so it shows outside masksToBounds)
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.22
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -2)

        // 1. PDF icon
        iconView = NSImageView(frame: NSRect(x: 10, y: 8, width: 16, height: 16))
        iconView.image = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "PDF")
        iconView.contentTintColor = NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.38, alpha: 1.0)
        addSubview(iconView)

        // 2. Title
        titleLabel = NSTextField(labelWithString: embeddedPDF.title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = NSColor.labelColor
        titleLabel.frame = NSRect(x: 30, y: 7, width: 110, height: 20)
        titleLabel.cell?.lineBreakMode = .byTruncatingMiddle
        addSubview(titleLabel)

        // 3. ‹ page N/M › controls — right-aligned group
        prevPageButton = NSButton(title: "‹", target: self, action: #selector(goToPrevPage))
        prevPageButton.bezelStyle = .texturedRounded
        prevPageButton.isBordered = false
        prevPageButton.font = .systemFont(ofSize: 14, weight: .bold)
        prevPageButton.contentTintColor = NSColor.labelColor
        addSubview(prevPageButton)

        pageLabel = NSTextField(labelWithString: "1 / 1")
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        pageLabel.textColor = NSColor.secondaryLabelColor
        pageLabel.alignment = .center
        addSubview(pageLabel)

        nextPageButton = NSButton(title: "›", target: self, action: #selector(goToNextPage))
        nextPageButton.bezelStyle = .texturedRounded
        nextPageButton.isBordered = false
        nextPageButton.font = .systemFont(ofSize: 14, weight: .bold)
        nextPageButton.contentTintColor = NSColor.labelColor
        addSubview(nextPageButton)

        // Thin separator
        let sep = NSBox()
        sep.boxType = .custom
        sep.borderWidth = 0
        sep.fillColor = NSColor(white: 0.5, alpha: 0.25)
        addSubview(sep)
        self.sep = sep

        // 4. Delete button
        deleteButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill",
                           accessibilityDescription: "Remove PDF") ?? NSImage(),
            target: self,
            action: #selector(deletePDF)
        )
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.isBordered = false
        deleteButton.contentTintColor = NSColor.tertiaryLabelColor
        addSubview(deleteButton)
    }

    // Separator stored weakly to avoid extra ivar declarations
    private weak var sep: NSBox?

    // MARK: - Layout — called by canvas after frame is set
    public override func layout() {
        super.layout()
        let h = bounds.height        // == barHeight typically
        let w = bounds.width

        blurView.frame = bounds

        // Fixed left section: icon + title
        iconView.frame = NSRect(x: 10, y: (h - 16) / 2, width: 16, height: 16)
        let titleX: CGFloat = 30
        let titleMaxW: CGFloat = max(0, w - 190)
        titleLabel.frame = NSRect(x: titleX, y: (h - 18) / 2, width: titleMaxW, height: 18)

        // Right section (from right): delete | sep | › pageLabel ‹
        let delW: CGFloat = 22
        let delX = w - delW - 8
        deleteButton.frame = NSRect(x: delX, y: (h - 20) / 2, width: delW, height: 20)

        let sepX = delX - 9
        sep?.frame = NSRect(x: sepX, y: 7, width: 1, height: h - 14)

        let arrowW: CGFloat = 18
        let pageLabelW: CGFloat = 44
        let navGroupW = arrowW + pageLabelW + arrowW + 2
        let navGroupX = sepX - navGroupW - 6

        nextPageButton.frame = NSRect(x: navGroupX + arrowW + pageLabelW + 2, y: (h - 22) / 2, width: arrowW, height: 22)
        pageLabel.frame = NSRect(x: navGroupX + arrowW, y: (h - 18) / 2, width: pageLabelW, height: 18)
        prevPageButton.frame = NSRect(x: navGroupX, y: (h - 22) / 2, width: arrowW, height: 22)
    }

    // MARK: - Pagination
    public func updatePaginationUI() {
        let current = embeddedPDF.currentPage + 1
        let total = max(1, embeddedPDF.pageCount)
        pageLabel.stringValue = "\(current)/\(total)"
        let hasPrev = current > 1
        let hasNext = current < total
        prevPageButton.isEnabled = hasPrev
        nextPageButton.isEnabled = hasNext
        prevPageButton.alphaValue = hasPrev ? 1.0 : 0.3
        nextPageButton.alphaValue = hasNext ? 1.0 : 0.3
        // Hide page controls entirely for single-page PDFs
        let show = total > 1
        prevPageButton.isHidden = !show
        nextPageButton.isHidden = !show
        pageLabel.isHidden = !show
    }

    @objc private func goToPrevPage() {
        guard embeddedPDF.currentPage > 0 else { return }
        embeddedPDF.currentPage -= 1
        updatePaginationUI()
        delegate?.pdfItemDidUpdateFrame(embeddedPDF)
    }

    @objc private func goToNextPage() {
        guard embeddedPDF.currentPage < embeddedPDF.pageCount - 1 else { return }
        embeddedPDF.currentPage += 1
        updatePaginationUI()
        delegate?.pdfItemDidUpdateFrame(embeddedPDF)
    }

    @objc private func deletePDF() {
        delegate?.pdfItemDidRequestDelete(embeddedPDF)
    }

    // MARK: - Hit testing: pass non-button clicks through to the canvas
    // The canvas handles dragging the PDF via the select tool.
    // We only intercept clicks that land on the interactive buttons.
    public override func mouseDown(with event: NSEvent) {
        let localPt = convert(event.locationInWindow, from: nil)
        let controls: [NSView] = [prevPageButton, nextPageButton, deleteButton]
        if controls.contains(where: { $0.frame.contains(localPt) }) {
            super.mouseDown(with: event)
        }
        // Otherwise: let the event fall through to the canvas below
    }

    // Pass scroll/right-click through
    public override func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }
}
