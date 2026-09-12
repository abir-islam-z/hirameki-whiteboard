import AppKit
import PDFKit

public protocol PDFCanvasItemDelegate: AnyObject {
    func pdfItemDidUpdateFrame(_ item: EmbeddedPDF)
    func pdfItemDidRequestDelete(_ item: EmbeddedPDF)
}

public final class PDFCanvasItemView: NSView {
    public var embeddedPDF: EmbeddedPDF
    public weak var delegate: PDFCanvasItemDelegate?

    public private(set) var pdfView: PDFView!
    private var headerBar: NSView!
    private var titleLabel: NSTextField!
    private var pageLabel: NSTextField!
    private var prevPageButton: NSButton!
    private var nextPageButton: NSButton!
    private var deleteButton: NSButton!

    private var isSelected: Bool = false
    private var isDragging: Bool = false
    private var dragStartMouse: CGPoint = .zero
    private var dragStartOrigin: CGPoint = .zero

    public init(embeddedPDF: EmbeddedPDF) {
        self.embeddedPDF = embeddedPDF
        super.init(frame: embeddedPDF.frame)
        setupViews()
        loadPDF()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        layer?.borderColor = NSColor(white: 0.8, alpha: 1.0).cgColor
        layer?.borderWidth = 1.0

        // 1. Header Bar (for moving, pagination & actions)
        headerBar = NSView(frame: NSRect(x: 0, y: bounds.height - 36, width: bounds.width, height: 36))
        headerBar.wantsLayer = true
        headerBar.layer?.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.98, alpha: 1.0).cgColor
        headerBar.autoresizingMask = [.width, .minYMargin]
        addSubview(headerBar)

        // Title
        titleLabel = NSTextField(labelWithString: embeddedPDF.title)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 10, y: 8, width: 220, height: 20)
        titleLabel.cell?.lineBreakMode = .byTruncatingTail
        headerBar.addSubview(titleLabel)

        // Page Label
        pageLabel = NSTextField(labelWithString: "1 / 1")
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        pageLabel.textColor = .secondaryLabelColor
        pageLabel.alignment = .center
        pageLabel.frame = NSRect(x: bounds.width - 160, y: 8, width: 60, height: 20)
        pageLabel.autoresizingMask = [.minXMargin]
        headerBar.addSubview(pageLabel)

        // Previous Page Button
        prevPageButton = NSButton(title: "‹", target: self, action: #selector(goToPrevPage))
        prevPageButton.bezelStyle = .texturedRounded
        prevPageButton.font = .systemFont(ofSize: 14, weight: .bold)
        prevPageButton.frame = NSRect(x: bounds.width - 96, y: 6, width: 24, height: 24)
        prevPageButton.autoresizingMask = [.minXMargin]
        headerBar.addSubview(prevPageButton)

        // Next Page Button
        nextPageButton = NSButton(title: "›", target: self, action: #selector(goToNextPage))
        nextPageButton.bezelStyle = .texturedRounded
        nextPageButton.font = .systemFont(ofSize: 14, weight: .bold)
        nextPageButton.frame = NSRect(x: bounds.width - 68, y: 6, width: 24, height: 24)
        nextPageButton.autoresizingMask = [.minXMargin]
        headerBar.addSubview(nextPageButton)

        // Delete Button
        deleteButton = NSButton(image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove PDF") ?? NSImage(), target: self, action: #selector(deletePDF))
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.isBordered = false
        deleteButton.contentTintColor = .secondaryLabelColor
        deleteButton.frame = NSRect(x: bounds.width - 34, y: 6, width: 24, height: 24)
        deleteButton.autoresizingMask = [.minXMargin]
        headerBar.addSubview(deleteButton)

        // 2. Native PDFKit View
        let pdfFrame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 36)
        pdfView = PDFView(frame: pdfFrame)
        pdfView.autoresizingMask = [.width, .height]
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor = .white
        addSubview(pdfView)

        NotificationCenter.default.addObserver(self, selector: #selector(pdfPageChanged), name: .PDFViewPageChanged, object: pdfView)
    }

    private func loadPDF() {
        if let doc = embeddedPDF.makePDFDocument() {
            pdfView.document = doc
            embeddedPDF.pageCount = doc.pageCount
            if embeddedPDF.currentPage < doc.pageCount, let page = doc.page(at: embeddedPDF.currentPage) {
                pdfView.go(to: page)
            }
            updatePaginationUI()
        }
    }

    private func updatePaginationUI() {
        guard let doc = pdfView.document else { return }
        let current = doc.index(for: pdfView.currentPage ?? doc.page(at: 0)!) + 1
        let total = max(1, doc.pageCount)
        pageLabel.stringValue = "\(current) / \(total)"
        prevPageButton.isEnabled = current > 1
        nextPageButton.isEnabled = current < total
    }

    @objc private func goToPrevPage() {
        if pdfView.canGoToPreviousPage {
            pdfView.goToPreviousPage(nil)
            if let page = pdfView.currentPage, let doc = pdfView.document {
                embeddedPDF.currentPage = doc.index(for: page)
                delegate?.pdfItemDidUpdateFrame(embeddedPDF)
            }
        }
    }

    @objc private func goToNextPage() {
        if pdfView.canGoToNextPage {
            pdfView.goToNextPage(nil)
            if let page = pdfView.currentPage, let doc = pdfView.document {
                embeddedPDF.currentPage = doc.index(for: page)
                delegate?.pdfItemDidUpdateFrame(embeddedPDF)
            }
        }
    }

    @objc private func deletePDF() {
        delegate?.pdfItemDidRequestDelete(embeddedPDF)
    }

    @objc private func pdfPageChanged() {
        updatePaginationUI()
    }

    // Drag header to move PDF on infinite canvas
    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if headerBar.frame.contains(loc) {
            isDragging = true
            dragStartMouse = event.locationInWindow
            dragStartOrigin = embeddedPDF.origin
            return
        }
        super.mouseDown(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        if isDragging {
            let deltaX = event.locationInWindow.x - dragStartMouse.x
            let deltaY = event.locationInWindow.y - dragStartMouse.y
            embeddedPDF.origin = CGPoint(x: dragStartOrigin.x + deltaX, y: dragStartOrigin.y + deltaY)
            frame = embeddedPDF.frame
            delegate?.pdfItemDidUpdateFrame(embeddedPDF)
            return
        }
        super.mouseDragged(with: event)
    }

    public override func mouseUp(with event: NSEvent) {
        isDragging = false
        super.mouseUp(with: event)
    }

    public func setSelected(_ selected: Bool) {
        self.isSelected = selected
        layer?.borderColor = selected ? NSColor.systemBlue.cgColor : NSColor(white: 0.8, alpha: 1.0).cgColor
        layer?.borderWidth = selected ? 2.5 : 1.0
    }
}
