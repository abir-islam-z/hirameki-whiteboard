import AppKit
import UniformTypeIdentifiers
import PDFKit
import SwiftUI

public protocol WhiteboardCanvasDelegate: AnyObject {
    func canvasDidUpdateDocument(_ doc: WhiteboardDocument)
    func canvasDidRequestNewPage()
    func canvasDidRequestInsertPDF()
    func canvasDidRequestInsertImage()
    func canvasDidRequestSave()
    func canvasDidRequestSaveAs()
    func canvasDidRequestOpen()
    func canvasDidRequestExportPDF()
    func canvasDidRequestNewBoard()
}

public enum ResizeHandle: String, CaseIterable, Equatable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

private enum TransformMode: Equatable {
    case none
    case moving
    case resizing(handle: ResizeHandle, anchor: CGPoint, initialBounds: CGRect)
    case movingPDF(initialOrigin: CGPoint)
    case movingImage(initialOrigin: CGPoint)
}

public final class WhiteboardCanvasView: NSView, PDFCanvasItemDelegate, ImageCanvasItemDelegate, NSTextFieldDelegate, FreeformWhiteboardActionDelegate {
    public var document: WhiteboardDocument
    public weak var canvasDelegate: WhiteboardCanvasDelegate?

    public let freeformState = FreeformWhiteboardState()

    public var activeTool: Tool = .select {
        didSet {
            freeformState.activeTool = activeTool
            window?.invalidateCursorRects(for: self)
            if activeTool != .select {
                clearSelection()
            }
            switch activeTool {
            case .pen:
                self.activeWidth = self.penWidth
            case .highlighter:
                self.activeWidth = self.markerWidth
            case .laser:
                self.activeWidth = self.laserWidth
            case .rect, .circle, .arrow, .line:
                self.activeWidth = self.shapeWidth
            default:
                break
            }
            freeformState.activeWidth = self.activeWidth
        }
    }
    public var activeColor: NSColor = .black {
        didSet {
            freeformState.activeColor = Color(activeColor)
        }
    }
    public var activeWidth: CGFloat = 4.0 {
        didSet {
            freeformState.activeWidth = activeWidth
        }
    }
    public var penWidth: CGFloat = 4.0
    public var markerWidth: CGFloat = 18.0
    public var shapeWidth: CGFloat = 3.0
    public var laserWidth: CGFloat = 6.0
    public var eraserType: EraserType = .object {
        didSet {
            freeformState.eraserType = eraserType
        }
    }

    // Canvas Transformation
    public var panOffset: CGPoint = .zero {
        didSet {
            updateTransform()
            needsDisplay = true
        }
    }
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            zoomScale = max(0.1, min(5.0, zoomScale))
            freeformState.zoomScale = zoomScale
            updateTransform()
            needsDisplay = true
        }
    }

    // Drawing State
    private var currentStroke: Stroke?
    private var redoStack: [Stroke] = []
    public var selectedStrokeIndex: Int?
    public var selectedPDFIndex: Int?
    public var selectedImageIndex: Int?

    // Interactive Transformation
    private var transformMode: TransformMode = .none
    private var initialStrokePoints: [StrokePoint] = []
    private var dragStartPos: CGPoint = .zero
    private var hasMovedSignificantly: Bool = false

    // Spacebar Pan State
    private var isSpacebarPanActive: Bool = false
    private var toolBeforeSpacebarPan: Tool = .select
    private var isDraggingPan: Bool = false
    private var dragPanStartMouse: CGPoint = .zero
    private var dragPanStartOffset: CGPoint = .zero

    // Laser fading & Disappearing Ink
    private var laserStrokes: [(stroke: Stroke, fadeStartTime: TimeInterval)] = []
    private var laserDisplayTimer: Timer?

    // Child PDF & Image item views
    private var pdfItemViews: [UUID: PDFCanvasItemView] = [:]
    private var imageItemViews: [UUID: ImageCanvasItemView] = [:]

    // Text Editing
    private var activeTextField: NSTextField?
    private var editingStrokeIndex: Int?

    // Floating UI Hosting Views
    private var freeformBottomLeftHost: NSHostingView<FreeformWhiteboardBottomLeftBar>?
    private var pageBarHost: NSHostingView<PageNavigationBar>?
    // Observable proxy: updated after every page switch so SwiftUI re-renders the nav bar
    private let documentProxy = DocumentProxy()

    public init(frame: NSRect, document: WhiteboardDocument = WhiteboardDocument()) {
        self.document = document
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        registerForDraggedTypes([.fileURL])

        setupFloatingBars()
        loadCurrentPage()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Floating UI Setup & Layout
    private func setupFloatingBars() {
        freeformState.documentTitle = document.title
        freeformState.activeTool = activeTool
        freeformState.activeColor = Color(activeColor)
        freeformState.activeWidth = activeWidth
        freeformState.penWidth = penWidth
        freeformState.markerWidth = markerWidth
        freeformState.shapeWidth = shapeWidth
        freeformState.laserWidth = laserWidth
        freeformState.zoomScale = zoomScale
        freeformState.eraserType = eraserType
        freeformState.pattern = document.activePage.pattern
        freeformState.boardOpacity = 1.0

        // 1. Bottom-Left Zoom & Undo/Redo capsule
        let blView = FreeformWhiteboardBottomLeftBar(state: freeformState, delegate: self)
        let blHost = NSHostingView(rootView: blView)
        blHost.autoresizingMask = []
        blHost.wantsLayer = true
        blHost.layer?.zPosition = 1000
        addSubview(blHost)
        self.freeformBottomLeftHost = blHost

        // 2. Multi-Page Navigation Bar
        // Use documentProxy (ObservableObject) so page switches trigger SwiftUI re-renders.
        documentProxy.document = document
        let pageView = PageNavigationBar(
            proxy: documentProxy,
            onSelectPage: { [weak self] idx in self?.switchToPage(at: idx) },
            onAddPage: { [weak self] in self?.addNewPage() },
            onDuplicatePage: { [weak self] idx in self?.duplicatePage(at: idx) },
            onDeletePage: { [weak self] idx in self?.deletePage(at: idx) },
            onRenamePage: { [weak self] idx, name in self?.renamePage(at: idx, to: name) },
            onZoomIn: { [weak self] in self?.zoomIn() },
            onZoomOut: { [weak self] in self?.zoomOut() },
            onResetZoom: { [weak self] in self?.resetZoom() },
            currentZoom: zoomScale
        )
        let pHost = NSHostingView(rootView: pageView)
        pHost.autoresizingMask = []
        pHost.wantsLayer = true
        pHost.layer?.zPosition = 1000
        addSubview(pHost)
        self.pageBarHost = pHost

        layoutFloatingBars()
    }

    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutFloatingBars()
    }

    private func layoutFloatingBars() {
        let padX: CGFloat = 20
        let padY: CGFloat = 20

        if let bl = freeformBottomLeftHost {
            let size = bl.fittingSize
            let w = max(260, size.width)
            let h = max(34, size.height)
            bl.frame = NSRect(x: padX, y: padY, width: w, height: h)
        }

        if let pHost = pageBarHost {
            let size = pHost.fittingSize
            let w = max(260, size.width)
            let h = max(34, size.height)
            let blWidth = freeformBottomLeftHost?.frame.width ?? 260
            pHost.frame = NSRect(x: padX + blWidth + 12, y: padY, width: w, height: h)
        }
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        if let hit = super.hitTest(point), hit != self {
            return hit
        }
        return self
    }

    // MARK: - Multi-Page Switching
    public func switchToPage(at index: Int) {
        commitActiveTextEditor()
        clearSelection()
        saveCurrentPageState()
        document.activePageIndex = max(0, min(index, document.pages.count - 1))
        loadCurrentPage()
        documentProxy.document = document   // sync → triggers SwiftUI re-render of nav bar
        canvasDelegate?.canvasDidUpdateDocument(document)
    }

    public func addNewPage() {
        commitActiveTextEditor()
        clearSelection()
        let newIndex = document.addPage()
        switchToPage(at: newIndex)
    }

    public func duplicatePage(at index: Int) {
        commitActiveTextEditor()
        clearSelection()
        let newIndex = document.duplicatePage(at: index)
        switchToPage(at: newIndex)
    }

    public func deletePage(at index: Int) {
        commitActiveTextEditor()
        clearSelection()
        document.deletePage(at: index)
        loadCurrentPage()
        documentProxy.document = document   // sync → triggers SwiftUI re-render of nav bar
        canvasDelegate?.canvasDidUpdateDocument(document)
    }

    public func renamePage(at index: Int, to newName: String) {
        document.renamePage(at: index, to: newName)
        documentProxy.document = document   // sync → triggers SwiftUI re-render of nav bar
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    private func saveCurrentPageState() {
        var page = document.activePage
        page.panOffset = panOffset
        page.zoomScale = zoomScale
        document.activePage = page
    }

    public func loadCurrentPage() {
        for (_, view) in pdfItemViews {
            view.removeFromSuperview()
        }
        pdfItemViews.removeAll()

        for (_, view) in imageItemViews {
            view.removeFromSuperview()
        }
        imageItemViews.removeAll()

        let page = document.activePage
        self.panOffset = page.panOffset
        self.zoomScale = page.zoomScale == 0 ? 1.0 : page.zoomScale
        self.freeformState.zoomScale = self.zoomScale
        self.freeformState.pattern = page.pattern
        self.redoStack.removeAll()
        self.selectedStrokeIndex = nil
        self.selectedPDFIndex = nil
        self.selectedImageIndex = nil

        for pdf in page.embeddedPDFs {
            addPDFItemView(pdf)
        }

        for img in page.embeddedImages {
            addImageItemView(img)
        }

        updateTransform()
        needsDisplay = true
    }

    private func addPDFItemView(_ pdf: EmbeddedPDF) {
        let itemView = PDFCanvasItemView(embeddedPDF: pdf)
        itemView.delegate = self
        pdfItemViews[pdf.id] = itemView
        if let bl = freeformBottomLeftHost {
            addSubview(itemView, positioned: .below, relativeTo: bl)
        } else {
            addSubview(itemView)
        }
        layoutPDFItem(itemView)
    }

    private func addImageItemView(_ image: EmbeddedImage) {
        let itemView = ImageCanvasItemView(embeddedImage: image)
        itemView.delegate = self
        imageItemViews[image.id] = itemView
        if let bl = freeformBottomLeftHost {
            addSubview(itemView, positioned: .below, relativeTo: bl)
        } else {
            addSubview(itemView)
        }
        layoutImageItem(itemView)
    }

    private func layoutPDFItem(_ view: PDFCanvasItemView) {
        let p = view.embeddedPDF.origin
        let screenX = (p.x * zoomScale) + panOffset.x
        let screenY = (p.y * zoomScale) + panOffset.y
        let screenW = view.embeddedPDF.width * zoomScale
        let screenH = view.embeddedPDF.height * zoomScale
        let pillW: CGFloat = 300
        let pillH: CGFloat = 34
        let pillX = screenX + (screenW - pillW) / 2.0
        let pillY = screenY + screenH + 8
        view.frame = NSRect(x: pillX, y: pillY, width: pillW, height: pillH)
    }

    private func layoutImageItem(_ view: ImageCanvasItemView) {
        let p = view.embeddedImage.origin
        let screenX = (p.x * zoomScale) + panOffset.x
        let screenY = (p.y * zoomScale) + panOffset.y
        let screenW = view.embeddedImage.width * zoomScale
        let screenH = view.embeddedImage.height * zoomScale
        let pillW: CGFloat = 220
        let pillH: CGFloat = 32
        let pillX = screenX + (screenW - pillW) / 2.0
        let pillY = screenY + screenH + 8
        view.frame = NSRect(x: pillX, y: pillY, width: pillW, height: pillH)
    }

    private func updateTransform() {
        for (_, view) in pdfItemViews {
            layoutPDFItem(view)
        }
        for (_, view) in imageItemViews {
            layoutImageItem(view)
        }
    }

    // MARK: - PDFCanvasItemDelegate
    public func pdfItemDidUpdateFrame(_ item: EmbeddedPDF) {
        if let idx = document.activePage.embeddedPDFs.firstIndex(where: { $0.id == item.id }) {
            document.activePage.embeddedPDFs[idx] = item
            canvasDelegate?.canvasDidUpdateDocument(document)
            updateTransform()
            needsDisplay = true
        }
    }

    public func pdfItemDidRequestDelete(_ item: EmbeddedPDF) {
        if let idx = document.activePage.embeddedPDFs.firstIndex(where: { $0.id == item.id }) {
            document.activePage.embeddedPDFs.remove(at: idx)
            pdfItemViews[item.id]?.removeFromSuperview()
            pdfItemViews.removeValue(forKey: item.id)
            if selectedPDFIndex == idx {
                selectedPDFIndex = nil
            }
            canvasDelegate?.canvasDidUpdateDocument(document)
            needsDisplay = true
        }
    }

    public func pdfItemCurrentZoomScale() -> CGFloat {
        return zoomScale
    }

    // MARK: - ImageCanvasItemDelegate
    public func imageItemDidUpdateFrame(_ item: EmbeddedImage) {
        if let idx = document.activePage.embeddedImages.firstIndex(where: { $0.id == item.id }) {
            document.activePage.embeddedImages[idx] = item
            canvasDelegate?.canvasDidUpdateDocument(document)
            updateTransform()
            needsDisplay = true
        }
    }

    public func imageItemDidRequestDelete(_ item: EmbeddedImage) {
        if let idx = document.activePage.embeddedImages.firstIndex(where: { $0.id == item.id }) {
            document.activePage.embeddedImages.remove(at: idx)
            imageItemViews[item.id]?.removeFromSuperview()
            imageItemViews.removeValue(forKey: item.id)
            if selectedImageIndex == idx {
                selectedImageIndex = nil
            }
            canvasDelegate?.canvasDidUpdateDocument(document)
            needsDisplay = true
        }
    }

    public func imageItemCurrentZoomScale() -> CGFloat {
        return zoomScale
    }

    // MARK: - Insert PDF File
    public func insertPDF(url: URL, at canvasPoint: CGPoint? = nil) {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let doc = PDFDocument(data: data) else { return }

        let pageBox = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let aspect = pageBox.height / max(1, pageBox.width)

        let maxW = min(560.0, max(380.0, bounds.width * 0.50))
        let maxH = min(max(300.0, bounds.height - 190.0), maxW * aspect)
        let finalW = maxH / aspect
        let finalH = maxH

        let targetPoint = canvasPoint ?? canvasPointFromScreen(CGPoint(x: bounds.midX, y: (bounds.height - 40.0) / 2.0))

        let emb = EmbeddedPDF(
            title: url.lastPathComponent,
            pdfData: data,
            origin: CGPoint(x: targetPoint.x - finalW / 2.0, y: targetPoint.y - finalH / 2.0),
            width: finalW,
            height: finalH,
            currentPage: 0,
            pageCount: doc.pageCount
        )

        document.activePage.embeddedPDFs.append(emb)
        addPDFItemView(emb)
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    // MARK: - Insert Image Attachment
    public func insertImage(data: Data, title: String = "Image", at canvasPoint: CGPoint? = nil) {
        guard let img = NSImage(data: data) else { return }

        let rep = img.representations.first
        let pixelW = CGFloat(rep?.pixelsWide ?? Int(img.size.width))
        let pixelH = CGFloat(rep?.pixelsHigh ?? Int(img.size.height))
        let aspect = max(1.0, pixelH) / max(1.0, pixelW)

        let maxW = min(600.0, max(300.0, bounds.width * 0.50))
        let maxH = min(max(250.0, bounds.height - 180.0), maxW * aspect)
        let finalW = maxH / aspect
        let finalH = maxH

        let targetPoint = canvasPoint ?? canvasPointFromScreen(CGPoint(x: bounds.midX, y: (bounds.height - 40.0) / 2.0))

        let emb = EmbeddedImage(
            title: title,
            imageData: data,
            origin: CGPoint(x: targetPoint.x - finalW / 2.0, y: targetPoint.y - finalH / 2.0),
            width: finalW,
            height: finalH
        )

        document.activePage.embeddedImages.append(emb)
        addImageItemView(emb)
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    public func insertImage(url: URL, at canvasPoint: CGPoint? = nil) {
        guard let data = try? Data(contentsOf: url) else { return }
        insertImage(data: data, title: url.lastPathComponent, at: canvasPoint)
    }

    // MARK: - Coordinate Mapping
    public func canvasPointFromScreen(_ screenPt: CGPoint) -> CGPoint {
        let x = (screenPt.x - panOffset.x) / zoomScale
        let y = (screenPt.y - panOffset.y) / zoomScale
        return CGPoint(x: x, y: y)
    }

    public func screenPointFromCanvas(_ canvasPt: CGPoint) -> CGPoint {
        let x = (canvasPt.x * zoomScale) + panOffset.x
        let y = (canvasPt.y * zoomScale) + panOffset.y
        return CGPoint(x: x, y: y)
    }

    // MARK: - Drawing & Rendering
    public override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background with Opacity
        let bgOpacity = freeformState.boardOpacity
        ctx.setFillColor(NSColor.white.withAlphaComponent(bgOpacity).cgColor)
        ctx.fill(bounds)

        // Subtle Pattern
        let pattern = freeformState.pattern
        if pattern == "dots" {
            drawDotsPattern(in: ctx)
        } else if pattern == "grid" {
            drawGridPattern(in: ctx)
        }

        ctx.saveGState()
        // Apply Canvas Camera Transformation
        ctx.translateBy(x: panOffset.x, y: panOffset.y)
        ctx.scaleBy(x: zoomScale, y: zoomScale)

        // Draw Embedded Images & PDFs directly on canvas (rasterized attachments, zero scrollbars)
        drawEmbeddedImages(in: ctx)
        drawEmbeddedPDFs(in: ctx)

        // Draw Completed Page Strokes (annotations, highlighters, shapes, notes)
        for (idx, stroke) in document.activePage.strokes.enumerated() {
            if idx == editingStrokeIndex { continue }
            drawStroke(stroke, in: ctx, isSelected: idx == selectedStrokeIndex)
        }

        // Draw Live In-Progress Stroke
        if let stroke = currentStroke {
            drawStroke(stroke, in: ctx, isSelected: false)
        }

        // Draw Selection Bounding Box with 8 Handles and Delete Button
        if activeTool == .select, let selIdx = selectedStrokeIndex, selIdx < document.activePage.strokes.count, selIdx != editingStrokeIndex {
            drawSelectionBoundingBox(for: selIdx, in: ctx)
        }

        // Draw Vanishing Laser Strokes
        let now = Date().timeIntervalSince1970
        for item in laserStrokes {
            let elapsed = now - item.fadeStartTime
            let progress = min(1.0, max(0.0, elapsed / 2.2))
            let alpha = pow(1.0 - progress, 1.25)
            if alpha > 0.005 {
                var faded = item.stroke
                faded.opacity = CGFloat(alpha)
                drawLaserStroke(faded, in: ctx)
            }
        }

        ctx.restoreGState()
    }

    private func drawDotsPattern(in ctx: CGContext) {
        let dotSpacing: CGFloat = 28.0 * zoomScale
        guard dotSpacing >= 10 else { return }

        ctx.setFillColor(NSColor(white: 0.85, alpha: 1.0).cgColor)
        let startX = panOffset.x.truncatingRemainder(dividingBy: dotSpacing)
        let startY = panOffset.y.truncatingRemainder(dividingBy: dotSpacing)

        var x = startX
        while x < bounds.width {
            var y = startY
            while y < bounds.height {
                ctx.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                y += dotSpacing
            }
            x += dotSpacing
        }
    }

    private func drawGridPattern(in ctx: CGContext) {
        let gridSpacing: CGFloat = 32.0 * zoomScale
        guard gridSpacing >= 12 else { return }

        ctx.setStrokeColor(NSColor(white: 0.90, alpha: 1.0).cgColor)
        ctx.setLineWidth(1.0)

        let startX = panOffset.x.truncatingRemainder(dividingBy: gridSpacing)
        let startY = panOffset.y.truncatingRemainder(dividingBy: gridSpacing)

        var x = startX
        while x < bounds.width {
            ctx.strokeLineSegments(between: [CGPoint(x: x, y: 0), CGPoint(x: x, y: bounds.height)])
            x += gridSpacing
        }

        var y = startY
        while y < bounds.height {
            ctx.strokeLineSegments(between: [CGPoint(x: 0, y: y), CGPoint(x: bounds.width, y: y)])
            y += gridSpacing
        }
    }

    private func drawEmbeddedImages(in ctx: CGContext) {
        for (iIdx, emb) in document.activePage.embeddedImages.enumerated() {
            let imgRect = CGRect(x: emb.originX, y: emb.originY, width: emb.width, height: emb.height)
            let cornerRadius: CGFloat = 6.0

            // 1. Soft realistic drop shadow under image
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: -3.5 / zoomScale),
                blur: 12.0 / zoomScale,
                color: NSColor.black.withAlphaComponent(0.18).cgColor
            )
            ctx.setFillColor(NSColor.white.cgColor)
            let shadowPath = CGPath(roundedRect: imgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(shadowPath)
            ctx.fillPath()
            ctx.restoreGState()

            // 2. Render rasterized image directly into graphics context
            ctx.saveGState()
            let clipPath = CGPath(roundedRect: imgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(clipPath)
            ctx.clip()

            if let img = emb.makeImage() {
                var proposedRect = CGRect(origin: .zero, size: img.size)
                if let cgImg = img.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
                    ctx.draw(cgImg, in: imgRect)
                } else {
                    img.draw(in: imgRect)
                }
            }
            ctx.restoreGState()

            // 3. Crisp subtle photo border
            ctx.saveGState()
            ctx.setStrokeColor(NSColor(white: 0.85, alpha: 0.85).cgColor)
            ctx.setLineWidth(1.0 / zoomScale)
            let borderPath = CGPath(roundedRect: imgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(borderPath)
            ctx.strokePath()
            ctx.restoreGState()

            // 4. Selection Highlight if selected with .select tool
            if activeTool == .select && selectedImageIndex == iIdx {
                ctx.saveGState()
                ctx.setStrokeColor(NSColor.systemBlue.cgColor)
                ctx.setLineWidth(2.5 / zoomScale)
                let selPath = CGPath(roundedRect: imgRect.insetBy(dx: -2 / zoomScale, dy: -2 / zoomScale), cornerWidth: cornerRadius + 2, cornerHeight: cornerRadius + 2, transform: nil)
                ctx.addPath(selPath)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
    }

    private func drawEmbeddedPDFs(in ctx: CGContext) {
        for (pIdx, emb) in document.activePage.embeddedPDFs.enumerated() {
            let pdfRect = CGRect(x: emb.originX, y: emb.originY, width: emb.width, height: emb.height)
            let cornerRadius: CGFloat = 4.0

            // 1. Soft realistic drop shadow under PDF paper sheet
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: 0, height: -4.0 / zoomScale),
                blur: 14.0 / zoomScale,
                color: NSColor.black.withAlphaComponent(0.16).cgColor
            )
            ctx.setFillColor(NSColor.white.cgColor)
            let shadowPath = CGPath(roundedRect: pdfRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(shadowPath)
            ctx.fillPath()
            ctx.restoreGState()

            // 2. Render crisp vector PDF Page directly into graphics context
            ctx.saveGState()
            let clipPath = CGPath(roundedRect: pdfRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(clipPath)
            ctx.clip()

            // White paper sheet background
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(pdfRect)

            if let doc = emb.makePDFDocument(), let pdfPage = doc.page(at: emb.currentPage) {
                ctx.saveGState()
                let pageBox = pdfPage.bounds(for: .mediaBox)
                ctx.translateBy(x: emb.originX, y: emb.originY)
                let scaleX = emb.width / max(1, pageBox.width)
                let scaleY = emb.height / max(1, pageBox.height)
                ctx.scaleBy(x: scaleX, y: scaleY)
                ctx.translateBy(x: -pageBox.origin.x, y: -pageBox.origin.y)
                pdfPage.draw(with: .mediaBox, to: ctx)
                ctx.restoreGState()
            }
            ctx.restoreGState()

            // 3. Crisp subtle paper border
            ctx.saveGState()
            ctx.setStrokeColor(NSColor(white: 0.85, alpha: 1.0).cgColor)
            ctx.setLineWidth(1.0 / zoomScale)
            let borderPath = CGPath(roundedRect: pdfRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.addPath(borderPath)
            ctx.strokePath()
            ctx.restoreGState()

            // 4. Selection Highlight if selected with .select tool
            if activeTool == .select && selectedPDFIndex == pIdx {
                ctx.saveGState()
                ctx.setStrokeColor(NSColor.systemBlue.cgColor)
                ctx.setLineWidth(2.5 / zoomScale)
                let selPath = CGPath(roundedRect: pdfRect.insetBy(dx: -2 / zoomScale, dy: -2 / zoomScale), cornerWidth: cornerRadius + 2, cornerHeight: cornerRadius + 2, transform: nil)
                ctx.addPath(selPath)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
    }

    private func drawStroke(_ stroke: Stroke, in ctx: CGContext, isSelected: Bool) {
        guard !stroke.points.isEmpty else { return }
        ctx.saveGState()

        let color = stroke.nsColor.withAlphaComponent(stroke.opacity)
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(stroke.width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        if stroke.tool == .highlighter {
            ctx.setBlendMode(.multiply)
            ctx.setAlpha(0.35)
        }

        if stroke.tool == .text || stroke.tool == .note, let text = stroke.text {
            let p = stroke.points[0].cgPoint
            if stroke.tool == .note {
                let noteRect = stroke.bounds
                let noteBg = NSColor(hex: stroke.noteBgColorHex ?? "#FFF382") ?? NSColor.yellow
                ctx.setFillColor(noteBg.cgColor)
                let notePath = CGPath(roundedRect: noteRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                ctx.addPath(notePath)
                ctx.fillPath()

                ctx.setStrokeColor(noteBg.shadow(withLevel: 0.15)?.cgColor ?? NSColor.orange.cgColor)
                ctx.setLineWidth(1.0)
                ctx.strokePath()
            }

            let size = max(14, (stroke.fontSize ?? 18.0))
            let font: NSFont = (stroke.isBold == true) ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: stroke.tool == .note ? NSColor.black : color
            ]
            let inset: CGFloat = stroke.tool == .note ? 14.0 : 0.0
            (text as NSString).draw(at: CGPoint(x: p.x + inset, y: p.y + inset), withAttributes: attrs)

            ctx.restoreGState()
            return
        }

        if stroke.points.count == 1 {
            let p = stroke.points[0].cgPoint
            let r = stroke.width / 2.0
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        } else {
            let path = CGMutablePath()
            path.move(to: stroke.points[0].cgPoint)
            for i in 1..<stroke.points.count {
                path.addLine(to: stroke.points[i].cgPoint)
            }
            ctx.addPath(path)
            ctx.strokePath()
        }

        ctx.restoreGState()
    }

    private func drawLaserStroke(_ stroke: Stroke, in ctx: CGContext) {
        guard stroke.points.count >= 2 else { return }
        ctx.saveGState()

        let baseColor = stroke.nsColor.withAlphaComponent(stroke.opacity)
        ctx.setStrokeColor(baseColor.cgColor)
        ctx.setLineWidth(stroke.width * 1.5)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setShadow(offset: .zero, blur: 8.0, color: baseColor.cgColor)

        let path = CGMutablePath()
        path.move(to: stroke.points[0].cgPoint)
        for i in 1..<stroke.points.count {
            path.addLine(to: stroke.points[i].cgPoint)
        }
        ctx.addPath(path)
        ctx.strokePath()

        // Inner bright core
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(stroke.opacity).cgColor)
        ctx.setLineWidth(max(2.0, stroke.width * 0.5))
        ctx.addPath(path)
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Selection Bounding Box & 8 Handles
    private func drawSelectionBoundingBox(for index: Int, in ctx: CGContext) {
        guard index < document.activePage.strokes.count else { return }
        let stroke = document.activePage.strokes[index]
        let b = stroke.bounds
        guard b.width > 0 && b.height > 0 else { return }

        ctx.saveGState()
        let pad: CGFloat = 6.0
        let selRect = b.insetBy(dx: -pad, dy: -pad)

        if stroke.tool == .text || stroke.tool == .note {
            // Freeform solid outline
            ctx.setLineDash(phase: 0, lengths: [])
            ctx.setStrokeColor(NSColor.systemBlue.cgColor)
            ctx.setLineWidth(1.5 / zoomScale)
            let path = CGPath(roundedRect: selRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.addPath(path)
            ctx.strokePath()

            ctx.setFillColor(NSColor.systemBlue.withAlphaComponent(0.04).cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        } else {
            // Dashed selection box
            ctx.setStrokeColor(NSColor.systemBlue.cgColor)
            ctx.setLineWidth(1.5 / zoomScale)
            let dash: [CGFloat] = [5 / zoomScale, 3 / zoomScale]
            ctx.setLineDash(phase: 0, lengths: dash)
            ctx.stroke(selRect)
        }

        // Draw 8 circular resize handles
        let handleRadius: CGFloat = 4.5 / zoomScale
        let handleDiameter = handleRadius * 2

        ctx.setLineDash(phase: 0, lengths: [])
        for handle in ResizeHandle.allCases {
            let r = handleRect(for: handle, in: selRect, diameter: handleDiameter)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: r)
            ctx.setStrokeColor(NSColor.systemBlue.cgColor)
            ctx.setLineWidth(1.5 / zoomScale)
            ctx.strokeEllipse(in: r)
        }

        // Draw Delete Pill Button above top-right corner
        let delSize: CGFloat = 20.0 / zoomScale
        let delRect = CGRect(x: selRect.maxX - delSize / 2, y: selRect.maxY + 6 / zoomScale, width: delSize, height: delSize)
        ctx.setFillColor(NSColor.systemRed.cgColor)
        ctx.fillEllipse(in: delRect)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5 / zoomScale)
        let crossInset: CGFloat = 5.0 / zoomScale
        ctx.strokeLineSegments(between: [
            CGPoint(x: delRect.minX + crossInset, y: delRect.minY + crossInset),
            CGPoint(x: delRect.maxX - crossInset, y: delRect.maxY - crossInset)
        ])
        ctx.strokeLineSegments(between: [
            CGPoint(x: delRect.minX + crossInset, y: delRect.maxY - crossInset),
            CGPoint(x: delRect.maxX - crossInset, y: delRect.minY + crossInset)
        ])

        ctx.restoreGState()
    }

    private func handleRect(for handle: ResizeHandle, in rect: CGRect, diameter: CGFloat) -> CGRect {
        let r = diameter / 2.0
        let pt: CGPoint
        switch handle {
        case .topLeft: pt = CGPoint(x: rect.minX, y: rect.maxY)
        case .top: pt = CGPoint(x: rect.midX, y: rect.maxY)
        case .topRight: pt = CGPoint(x: rect.maxX, y: rect.maxY)
        case .right: pt = CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomRight: pt = CGPoint(x: rect.maxX, y: rect.minY)
        case .bottom: pt = CGPoint(x: rect.midX, y: rect.minY)
        case .bottomLeft: pt = CGPoint(x: rect.minX, y: rect.minY)
        case .left: pt = CGPoint(x: rect.minX, y: rect.midY)
        }
        return CGRect(x: pt.x - r, y: pt.y - r, width: diameter, height: diameter)
    }

    private func deleteButtonRect(for selRect: CGRect) -> CGRect {
        let delSize: CGFloat = 20.0 / zoomScale
        return CGRect(x: selRect.maxX - delSize / 2, y: selRect.maxY + 6 / zoomScale, width: delSize, height: delSize)
    }

    // MARK: - Mouse Events
    public override func mouseDown(with event: NSEvent) {
        commitActiveTextEditor()
        let screenPt = convert(event.locationInWindow, from: nil)
        let canvasPt = canvasPointFromScreen(screenPt)

        if activeTool == .hand || isSpacebarPanActive || event.buttonNumber == 2 {
            isDraggingPan = true
            dragPanStartMouse = screenPt
            dragPanStartOffset = panOffset
            return
        }

        if activeTool == .select {
            handleSelectMouseDown(at: canvasPt, clickCount: event.clickCount)
            return
        }

        if activeTool == .eraser {
            eraseAt(canvasPt)
            return
        }

        if activeTool == .text {
            startTextEditor(at: canvasPt, isNote: false)
            return
        }

        if activeTool == .note {
            startTextEditor(at: canvasPt, isNote: true)
            return
        }

        // Start drawing stroke or laser
        let pt = StrokePoint(x: canvasPt.x, y: canvasPt.y, pressure: CGFloat(event.pressure))
        let width = activeWidth / zoomScale
        currentStroke = Stroke(
            tool: activeTool,
            points: [pt],
            colorHex: activeColor.hexString,
            width: width
        )
        needsDisplay = true
    }

    public override func mouseDragged(with event: NSEvent) {
        let screenPt = convert(event.locationInWindow, from: nil)
        let canvasPt = canvasPointFromScreen(screenPt)

        if isDraggingPan {
            panOffset = CGPoint(
                x: dragPanStartOffset.x + (screenPt.x - dragPanStartMouse.x),
                y: dragPanStartOffset.y + (screenPt.y - dragPanStartMouse.y)
            )
            return
        }

        if activeTool == .select {
            if case .movingPDF(let initOrigin) = transformMode, let pIdx = selectedPDFIndex, pIdx < document.activePage.embeddedPDFs.count {
                let deltaX = canvasPt.x - dragStartPos.x
                let deltaY = canvasPt.y - dragStartPos.y
                document.activePage.embeddedPDFs[pIdx].origin = CGPoint(x: initOrigin.x + deltaX, y: initOrigin.y + deltaY)
                updateTransform()
                hasMovedSignificantly = true
                needsDisplay = true
                return
            }

            if case .movingImage(let initOrigin) = transformMode, let iIdx = selectedImageIndex, iIdx < document.activePage.embeddedImages.count {
                let deltaX = canvasPt.x - dragStartPos.x
                let deltaY = canvasPt.y - dragStartPos.y
                document.activePage.embeddedImages[iIdx].origin = CGPoint(x: initOrigin.x + deltaX, y: initOrigin.y + deltaY)
                updateTransform()
                hasMovedSignificantly = true
                needsDisplay = true
                return
            }

            if let selIdx = selectedStrokeIndex, selIdx < document.activePage.strokes.count {
                switch transformMode {
            case .moving:
                let deltaX = canvasPt.x - dragStartPos.x
                let deltaY = canvasPt.y - dragStartPos.y
                for i in 0..<document.activePage.strokes[selIdx].points.count {
                    if i < initialStrokePoints.count {
                        document.activePage.strokes[selIdx].points[i].x = initialStrokePoints[i].x + deltaX
                        document.activePage.strokes[selIdx].points[i].y = initialStrokePoints[i].y + deltaY
                    }
                }
                hasMovedSignificantly = true
                needsDisplay = true
                return

            case .resizing(let handle, let anchor, let initBounds):
                let initW = max(1.0, initBounds.width)
                let initH = max(1.0, initBounds.height)
                var newW: CGFloat = initW
                var newH: CGFloat = initH

                switch handle {
                case .right: newW = max(10.0, canvasPt.x - anchor.x)
                case .left: newW = max(10.0, anchor.x - canvasPt.x)
                case .top: newH = max(10.0, canvasPt.y - anchor.y)
                case .bottom: newH = max(10.0, anchor.y - canvasPt.y)
                case .topRight:
                    newW = max(10.0, canvasPt.x - anchor.x)
                    newH = max(10.0, canvasPt.y - anchor.y)
                case .topLeft:
                    newW = max(10.0, anchor.x - canvasPt.x)
                    newH = max(10.0, canvasPt.y - anchor.y)
                case .bottomRight:
                    newW = max(10.0, canvasPt.x - anchor.x)
                    newH = max(10.0, anchor.y - canvasPt.y)
                case .bottomLeft:
                    newW = max(10.0, anchor.x - canvasPt.x)
                    newH = max(10.0, anchor.y - canvasPt.y)
                }

                let scaleX = newW / initW
                let scaleY = newH / initH

                for i in 0..<document.activePage.strokes[selIdx].points.count {
                    if i < initialStrokePoints.count {
                        let initPt = initialStrokePoints[i]
                        document.activePage.strokes[selIdx].points[i].x = anchor.x + (initPt.x - anchor.x) * scaleX
                        document.activePage.strokes[selIdx].points[i].y = anchor.y + (initPt.y - anchor.y) * scaleY
                    }
                }
                hasMovedSignificantly = true
                needsDisplay = true
                return

            case .none, .movingPDF, .movingImage:
                break
            }
        }
    }

        if activeTool == .eraser {
            eraseAt(canvasPt)
            return
        }

        guard var stroke = currentStroke else { return }

        let pt = StrokePoint(x: canvasPt.x, y: canvasPt.y, pressure: CGFloat(event.pressure))
        if stroke.tool.isShape {
            let start = stroke.points[0].cgPoint
            let end = canvasPt
            stroke.points = makeShapePoints(tool: stroke.tool, start: start, end: end)
        } else {
            stroke.points.append(pt)
        }
        currentStroke = stroke
        needsDisplay = true
    }

    public override func mouseUp(with event: NSEvent) {
        if isDraggingPan {
            isDraggingPan = false
            return
        }

        if transformMode != .none {
            transformMode = .none
            if hasMovedSignificantly {
                canvasDelegate?.canvasDidUpdateDocument(document)
            }
            hasMovedSignificantly = false
            needsDisplay = true
            return
        }

        if let stroke = currentStroke {
            if stroke.tool == .laser {
                laserStrokes.append((stroke: stroke, fadeStartTime: Date().timeIntervalSince1970))
                currentStroke = nil
                startLaserFadeLoop()
            } else {
                document.activePage.strokes.append(stroke)
                redoStack.removeAll()
                currentStroke = nil
                canvasDelegate?.canvasDidUpdateDocument(document)
            }
            needsDisplay = true
        }
    }

    private func handleSelectMouseDown(at canvasPt: CGPoint, clickCount: Int) {
        // 1. If stroke is already selected, check delete button or resize handles first
        if let selIdx = selectedStrokeIndex, selIdx < document.activePage.strokes.count {
            let stroke = document.activePage.strokes[selIdx]
            let selRect = stroke.bounds.insetBy(dx: -6.0, dy: -6.0)

            // A. Check Delete Button
            let delRect = deleteButtonRect(for: selRect)
            if delRect.contains(canvasPt) {
                document.activePage.strokes.remove(at: selIdx)
                selectedStrokeIndex = nil
                canvasDelegate?.canvasDidUpdateDocument(document)
                needsDisplay = true
                return
            }

            // B. Check 8 Resize Handles
            let handleDiam: CGFloat = 9.0 / zoomScale
            for handle in ResizeHandle.allCases {
                let hr = handleRect(for: handle, in: selRect, diameter: handleDiam)
                if hr.contains(canvasPt) {
                    let anchor: CGPoint
                    switch handle {
                    case .topLeft: anchor = CGPoint(x: selRect.maxX, y: selRect.minY)
                    case .top: anchor = CGPoint(x: selRect.midX, y: selRect.minY)
                    case .topRight: anchor = CGPoint(x: selRect.minX, y: selRect.minY)
                    case .right: anchor = CGPoint(x: selRect.minX, y: selRect.midY)
                    case .bottomRight: anchor = CGPoint(x: selRect.minX, y: selRect.maxY)
                    case .bottom: anchor = CGPoint(x: selRect.midX, y: selRect.maxY)
                    case .bottomLeft: anchor = CGPoint(x: selRect.maxX, y: selRect.maxY)
                    case .left: anchor = CGPoint(x: selRect.maxX, y: selRect.midY)
                    }

                    transformMode = .resizing(handle: handle, anchor: anchor, initialBounds: stroke.bounds)
                    initialStrokePoints = stroke.points
                    dragStartPos = canvasPt
                    hasMovedSignificantly = false
                    return
                }
            }

            // C. Check interior moving
            if selRect.contains(canvasPt) {
                if clickCount == 2 && (stroke.tool == .text || stroke.tool == .note) {
                    startTextEditor(for: stroke, at: selIdx)
                    return
                }
                transformMode = .moving
                initialStrokePoints = stroke.points
                dragStartPos = canvasPt
                hasMovedSignificantly = false
                return
            }
        }

        // 2. Click on any stroke to select it
        for (idx, stroke) in document.activePage.strokes.enumerated().reversed() {
            if stroke.hitTest(canvasPt, tolerance: 12.0) {
                selectedStrokeIndex = idx
                selectedPDFIndex = nil
                if clickCount == 2 && (stroke.tool == .text || stroke.tool == .note) {
                    startTextEditor(for: stroke, at: idx)
                    return
                }
                transformMode = .moving
                initialStrokePoints = stroke.points
                dragStartPos = canvasPt
                hasMovedSignificantly = false
                needsDisplay = true
                return
            }
        }

        // 3. Click on any Image to select or drag it
        for (iIdx, emb) in document.activePage.embeddedImages.enumerated().reversed() {
            let imgRect = CGRect(x: emb.originX, y: emb.originY, width: emb.width, height: emb.height)
            if imgRect.contains(canvasPt) {
                selectedImageIndex = iIdx
                selectedPDFIndex = nil
                selectedStrokeIndex = nil
                transformMode = .movingImage(initialOrigin: emb.origin)
                dragStartPos = canvasPt
                hasMovedSignificantly = false
                needsDisplay = true
                return
            }
        }

        // 4. Click on any PDF to select or drag it
        for (pIdx, emb) in document.activePage.embeddedPDFs.enumerated().reversed() {
            let pdfRect = CGRect(x: emb.originX, y: emb.originY, width: emb.width, height: emb.height)
            if pdfRect.contains(canvasPt) {
                selectedPDFIndex = pIdx
                selectedImageIndex = nil
                selectedStrokeIndex = nil
                transformMode = .movingPDF(initialOrigin: emb.origin)
                dragStartPos = canvasPt
                hasMovedSignificantly = false
                needsDisplay = true
                return
            }
        }

        // 5. Clicked empty space
        clearSelection()
    }

    public func clearSelection() {
        selectedStrokeIndex = nil
        selectedPDFIndex = nil
        selectedImageIndex = nil
        transformMode = .none
        needsDisplay = true
    }

    private func eraseAt(_ pt: CGPoint) {
        var didErase = false
        if eraserType == .object {
            document.activePage.strokes.removeAll { stroke in
                if stroke.hitTest(pt, tolerance: 16.0) {
                    didErase = true
                    return true
                }
                return false
            }
        } else {
            // Stroke / Pixel Eraser
            for i in 0..<document.activePage.strokes.count {
                let stroke = document.activePage.strokes[i]
                if stroke.hitTest(pt, tolerance: 12.0) {
                    let filtered = stroke.points.filter { hypot($0.x - pt.x, $0.y - pt.y) > 14.0 }
                    if filtered.count != stroke.points.count {
                        document.activePage.strokes[i].points = filtered
                        didErase = true
                    }
                }
            }
            document.activePage.strokes.removeAll { $0.points.isEmpty }
        }

        if didErase {
            canvasDelegate?.canvasDidUpdateDocument(document)
            needsDisplay = true
        }
    }

    // MARK: - Laser Fade Animation Loop
    private func startLaserFadeLoop() {
        guard laserDisplayTimer == nil else { return }
        laserDisplayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let now = Date().timeIntervalSince1970
            self.laserStrokes.removeAll { now - $0.fadeStartTime >= 2.2 }
            self.needsDisplay = true
            if self.laserStrokes.isEmpty {
                timer.invalidate()
                self.laserDisplayTimer = nil
            }
        }
    }

    // MARK: - Shapes Generation
    private func makeShapePoints(tool: Tool, start: CGPoint, end: CGPoint) -> [StrokePoint] {
        let rect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        switch tool {
        case .line:
            return [StrokePoint(x: start.x, y: start.y), StrokePoint(x: end.x, y: end.y)]

        case .arrow:
            var pts = [StrokePoint(x: start.x, y: start.y), StrokePoint(x: end.x, y: end.y)]
            let angle = atan2(end.y - start.y, end.x - start.x)
            let headLen: CGFloat = 20.0
            let p1 = CGPoint(x: end.x - headLen * cos(angle - .pi / 6), y: end.y - headLen * sin(angle - .pi / 6))
            let p2 = CGPoint(x: end.x - headLen * cos(angle + .pi / 6), y: end.y - headLen * sin(angle + .pi / 6))
            pts.append(StrokePoint(x: p1.x, y: p1.y))
            pts.append(StrokePoint(x: end.x, y: end.y))
            pts.append(StrokePoint(x: p2.x, y: p2.y))
            return pts

        case .rect, .square:
            let r = tool == .square ? CGRect(x: rect.origin.x, y: rect.origin.y, width: min(rect.width, rect.height), height: min(rect.width, rect.height)) : rect
            return [
                StrokePoint(x: r.minX, y: r.minY),
                StrokePoint(x: r.maxX, y: r.minY),
                StrokePoint(x: r.maxX, y: r.maxY),
                StrokePoint(x: r.minX, y: r.maxY),
                StrokePoint(x: r.minX, y: r.minY)
            ]

        case .circle:
            var pts: [StrokePoint] = []
            let count = 48
            let rx = rect.width / 2.0
            let ry = rect.height / 2.0
            let cx = rect.midX
            let cy = rect.midY
            for i in 0...count {
                let theta = (CGFloat(i) / CGFloat(count)) * 2 * .pi
                pts.append(StrokePoint(x: cx + rx * cos(theta), y: cy + ry * sin(theta)))
            }
            return pts

        case .triangle:
            return [
                StrokePoint(x: rect.midX, y: rect.maxY),
                StrokePoint(x: rect.maxX, y: rect.minY),
                StrokePoint(x: rect.minX, y: rect.minY),
                StrokePoint(x: rect.midX, y: rect.maxY)
            ]

        case .diamond:
            return [
                StrokePoint(x: rect.midX, y: rect.minY),
                StrokePoint(x: rect.maxX, y: rect.midY),
                StrokePoint(x: rect.midX, y: rect.maxY),
                StrokePoint(x: rect.minX, y: rect.midY),
                StrokePoint(x: rect.midX, y: rect.minY)
            ]

        case .star:
            var pts: [StrokePoint] = []
            let points = 5
            let rOuter = max(rect.width, rect.height) / 2.0
            let rInner = rOuter * 0.45
            let cx = rect.midX
            let cy = rect.midY
            for i in 0..<(points * 2) {
                let r = i % 2 == 0 ? rOuter : rInner
                let angle = (CGFloat(i) / CGFloat(points * 2)) * 2 * .pi - .pi / 2
                pts.append(StrokePoint(x: cx + r * cos(angle), y: cy + r * sin(angle)))
            }
            if let first = pts.first { pts.append(first) }
            return pts

        default:
            return [StrokePoint(x: start.x, y: start.y), StrokePoint(x: end.x, y: end.y)]
        }
    }

    // MARK: - Text & Sticky Notes Editor
    private func startTextEditor(at canvasPt: CGPoint, initialText: String = "", isNote: Bool = false) {
        commitActiveTextEditor()

        let screenPt = screenPointFromCanvas(canvasPt)
        let field = NSTextField(frame: NSRect(x: screenPt.x, y: screenPt.y, width: isNote ? 180 : 220, height: isNote ? 140 : 36))
        field.stringValue = initialText
        field.isBordered = !isNote
        field.font = .systemFont(ofSize: 18)
        field.backgroundColor = isNote ? (NSColor(hex: "#FFF382") ?? .yellow) : .white
        field.delegate = self
        addSubview(field)
        field.becomeFirstResponder()
        self.activeTextField = field

        if editingStrokeIndex == nil {
            let newStroke = Stroke(
                tool: isNote ? .note : .text,
                points: [StrokePoint(x: canvasPt.x, y: canvasPt.y)],
                colorHex: activeColor.hexString,
                text: "",
                fontSize: 18,
                isStickyNote: isNote,
                noteBgColorHex: isNote ? "#FFF382" : nil
            )
            document.activePage.strokes.append(newStroke)
            editingStrokeIndex = document.activePage.strokes.count - 1
        }
    }

    private func startTextEditor(for stroke: Stroke, at index: Int) {
        commitActiveTextEditor()
        editingStrokeIndex = index
        let p = stroke.points[0].cgPoint
        startTextEditor(at: p, initialText: stroke.text ?? "", isNote: stroke.tool == .note)
    }

    public func commitActiveTextEditor() {
        guard let field = activeTextField, let idx = editingStrokeIndex else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            document.activePage.strokes.remove(at: idx)
            selectedStrokeIndex = nil
        } else {
            document.activePage.strokes[idx].text = text
            selectedStrokeIndex = idx
        }
        field.removeFromSuperview()
        activeTextField = nil
        editingStrokeIndex = nil
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    // MARK: - Trackpad & Scroll Gestures
    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let zoomDelta = event.deltaY * 0.015
            let newScale = zoomScale + zoomDelta
            let mousePt = convert(event.locationInWindow, from: nil)
            zoomTo(scale: newScale, centeredAt: mousePt)
            return
        }

        panOffset = CGPoint(x: panOffset.x + event.scrollingDeltaX, y: panOffset.y - event.scrollingDeltaY)
    }

    public override func magnify(with event: NSEvent) {
        let mousePt = convert(event.locationInWindow, from: nil)
        zoomTo(scale: zoomScale * (1.0 + event.magnification), centeredAt: mousePt)
    }

    public func zoomTo(scale: CGFloat, centeredAt screenPt: CGPoint) {
        let oldScale = zoomScale
        let targetScale = max(0.1, min(5.0, scale))
        guard targetScale != oldScale else { return }

        let canvasPt = canvasPointFromScreen(screenPt)
        zoomScale = targetScale
        panOffset = CGPoint(
            x: screenPt.x - (canvasPt.x * targetScale),
            y: screenPt.y - (canvasPt.y * targetScale)
        )
    }

    public func zoomIn() {
        zoomTo(scale: zoomScale * 1.25, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    public func zoomOut() {
        zoomTo(scale: zoomScale / 1.25, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    public func resetZoom() {
        zoomTo(scale: 1.0, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    public func zoomToFit() {
        guard !document.activePage.strokes.isEmpty else {
            resetZoom()
            return
        }
        var unionBounds = document.activePage.strokes[0].bounds
        for s in document.activePage.strokes.dropFirst() {
            unionBounds = unionBounds.union(s.bounds)
        }
        let pad: CGFloat = 80.0
        let targetW = max(100.0, unionBounds.width + pad * 2)
        let targetH = max(100.0, unionBounds.height + pad * 2)
        let scaleX = bounds.width / targetW
        let scaleY = bounds.height / targetH
        let newScale = max(0.25, min(2.0, min(scaleX, scaleY)))
        zoomScale = newScale
        panOffset = CGPoint(
            x: bounds.midX - unionBounds.midX * newScale,
            y: bounds.midY - unionBounds.midY * newScale
        )
    }

    // MARK: - Undo / Redo / Clear
    public func undo() {
        commitActiveTextEditor()
        guard !document.activePage.strokes.isEmpty else { return }
        let stroke = document.activePage.strokes.removeLast()
        redoStack.append(stroke)
        selectedStrokeIndex = nil
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    public func redo() {
        commitActiveTextEditor()
        guard !redoStack.isEmpty else { return }
        let stroke = redoStack.removeLast()
        document.activePage.strokes.append(stroke)
        selectedStrokeIndex = nil
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    public func clearAll() {
        commitActiveTextEditor()
        document.activePage.strokes.removeAll()
        redoStack.removeAll()
        selectedStrokeIndex = nil
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    // Drag and Drop PDF & Image support
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let pasteboard = sender.draggingPasteboard.propertyList(forType: .fileURL) as? String,
           let url = URL(string: pasteboard) {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" || ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic", "bmp"].contains(ext) {
                return .copy
            }
        }
        if sender.draggingPasteboard.canReadObject(forClasses: [NSImage.self], options: nil) {
            return .copy
        }
        return []
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let loc = convert(sender.draggingLocation, from: nil)
        let canvasPt = canvasPointFromScreen(loc)

        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ext == "pdf" {
                    insertPDF(url: url, at: canvasPt)
                    return true
                } else if ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic", "bmp"].contains(ext) {
                    insertImage(url: url, at: canvasPt)
                    return true
                }
            }
        }

        if let images = sender.draggingPasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let img = images.first,
           let tiffData = img.tiffRepresentation {
            insertImage(data: tiffData, title: "Dropped Image", at: canvasPt)
            return true
        }

        return false
    }

    // MARK: - Clipboard Paste
    @discardableResult
    public func pasteImageFromClipboard() -> Bool {
        let pb = NSPasteboard.general
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if ext == "pdf" {
                    insertPDF(url: url)
                    return true
                } else if ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic", "bmp"].contains(ext) {
                    insertImage(url: url)
                    return true
                }
            }
        }
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let img = images.first,
           let tiffData = img.tiffRepresentation {
            insertImage(data: tiffData, title: "Pasted Image")
            return true
        }
        return false
    }

    @objc public func paste(_ sender: Any?) {
        pasteImageFromClipboard()
    }

    // MARK: - Keyboard Handling
    public override var acceptsFirstResponder: Bool { true }

    public override func keyDown(with event: NSEvent) {
        if activeTextField != nil {
            super.keyDown(with: event)
            return
        }

        // Spacebar hold for pan
        if event.keyCode == 49 && !isSpacebarPanActive {
            isSpacebarPanActive = true
            toolBeforeSpacebarPan = activeTool
            activeTool = .hand
            NSCursor.openHand.set()
            return
        }

        // Command+V Paste
        if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "v" || event.characters == "v") {
            if pasteImageFromClipboard() {
                return
            }
        }

        // Delete / Backspace key
        if event.keyCode == 51 || event.keyCode == 117 {
            if let idx = selectedStrokeIndex, idx < document.activePage.strokes.count {
                document.activePage.strokes.remove(at: idx)
                selectedStrokeIndex = nil
                canvasDelegate?.canvasDidUpdateDocument(document)
                needsDisplay = true
                return
            }
            if let iIdx = selectedImageIndex, iIdx < document.activePage.embeddedImages.count {
                let emb = document.activePage.embeddedImages[iIdx]
                imageItemDidRequestDelete(emb)
                selectedImageIndex = nil
                return
            }
            if let pIdx = selectedPDFIndex, pIdx < document.activePage.embeddedPDFs.count {
                let emb = document.activePage.embeddedPDFs[pIdx]
                pdfItemDidRequestDelete(emb)
                selectedPDFIndex = nil
                return
            }
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(), !event.modifierFlags.contains(.command) else {
            super.keyDown(with: event)
            return
        }

        switch chars {
        case "v": activeTool = .select
        case "h": activeTool = .hand
        case "m": activeTool = .highlighter
        case "p": activeTool = .pen
        case "d": activeTool = .laser
        case "e": activeTool = .eraser
        case "t": activeTool = .text
        case "n": activeTool = .note
        case "r": activeTool = .rect
        case "c": activeTool = .circle
        case "a": activeTool = .arrow
        case "l": activeTool = .line
        default:
            super.keyDown(with: event)
        }
    }

    public override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 && isSpacebarPanActive {
            isSpacebarPanActive = false
            activeTool = toolBeforeSpacebarPan
            window?.invalidateCursorRects(for: self)
            return
        }
        super.keyUp(with: event)
    }

    public override func resetCursorRects() {
        super.resetCursorRects()
        let cursor: NSCursor
        switch activeTool {
        case .select: cursor = .arrow
        case .hand: cursor = isDraggingPan ? .closedHand : .openHand
        case .pen, .highlighter, .laser: cursor = .crosshair
        case .eraser: cursor = .disappearingItem
        case .text: cursor = .iBeam
        case .note: cursor = .pointingHand
        default: cursor = .crosshair
        }
        addCursorRect(bounds, cursor: cursor)
    }

    // MARK: - FreeformWhiteboardActionDelegate
    public func freeformDidSelectTool(_ tool: Tool) {
        self.activeTool = tool
        self.freeformState.activeTool = tool
        window?.invalidateCursorRects(for: self)
    }

    public func freeformDidChangeColor(_ color: NSColor) {
        self.activeColor = color
        self.freeformState.activeColor = Color(color)
        if let idx = selectedStrokeIndex, idx < document.activePage.strokes.count {
            document.activePage.strokes[idx].colorHex = color.hexString
            needsDisplay = true
        }
    }

    public func freeformDidChangeWidth(_ width: CGFloat) {
        self.activeWidth = width
        self.freeformState.activeWidth = width
        switch activeTool {
        case .pen:
            self.penWidth = width
            self.freeformState.penWidth = width
        case .highlighter:
            self.markerWidth = width
            self.freeformState.markerWidth = width
        case .laser:
            self.laserWidth = width
            self.freeformState.laserWidth = width
        case .rect, .circle, .arrow, .line:
            self.shapeWidth = width
            self.freeformState.shapeWidth = width
        default:
            break
        }
        if let idx = selectedStrokeIndex, idx < document.activePage.strokes.count {
            document.activePage.strokes[idx].width = width
            needsDisplay = true
        }
    }

    public func freeformDidRequestNewBoard() {
        canvasDelegate?.canvasDidRequestNewBoard()
    }

    public func freeformDidRequestOpenBoard() {
        canvasDelegate?.canvasDidRequestOpen()
    }

    public func freeformDidRequestSaveBoard() {
        canvasDelegate?.canvasDidRequestSave()
    }

    public func freeformDidRequestSaveBoardAs() {
        canvasDelegate?.canvasDidRequestSaveAs()
    }

    public func freeformDidRequestExportPDF() {
        canvasDelegate?.canvasDidRequestExportPDF()
    }

    public func freeformDidRequestInsertPDF() {
        canvasDelegate?.canvasDidRequestInsertPDF()
    }

    public func freeformDidRequestInsertImage() {
        canvasDelegate?.canvasDidRequestInsertImage()
    }

    public func freeformDidRequestRename(to newTitle: String) {
        document.title = newTitle
        freeformState.documentTitle = newTitle
        canvasDelegate?.canvasDidUpdateDocument(document)
    }

    public func freeformDidRequestUndo() {
        undo()
    }

    public func freeformDidRequestRedo() {
        redo()
    }

    public func freeformDidRequestClear() {
        clearAll()
    }

    public func freeformDidChangeEraserType(_ type: EraserType) {
        self.eraserType = type
        self.freeformState.eraserType = type
    }

    public func freeformDidChangePattern(_ pattern: String) {
        self.freeformState.pattern = pattern
        self.document.activePage.pattern = pattern
        needsDisplay = true
    }

    public func freeformDidChangeOpacity(_ opacity: CGFloat) {
        self.freeformState.boardOpacity = opacity
        needsDisplay = true
    }

    public func freeformDidZoomIn() {
        zoomIn()
    }

    public func freeformDidZoomOut() {
        zoomOut()
    }

    public func freeformDidResetZoom() {
        resetZoom()
    }

    public func freeformDidSetZoom(_ scale: CGFloat) {
        zoomTo(scale: scale, centeredAt: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    public func freeformDidZoomToFit() {
        zoomToFit()
    }
}
