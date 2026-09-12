import AppKit
import UniformTypeIdentifiers
import PDFKit

public protocol WhiteboardCanvasDelegate: AnyObject {
    func canvasDidUpdateDocument(_ doc: WhiteboardDocument)
    func canvasDidRequestNewPage()
    func canvasDidRequestInsertPDF()
}

public final class WhiteboardCanvasView: NSView, PDFCanvasItemDelegate, NSTextFieldDelegate {
    public var document: WhiteboardDocument
    public weak var canvasDelegate: WhiteboardCanvasDelegate?

    public var onToolChanged: ((Tool) -> Void)?
    public var onZoomChanged: ((CGFloat) -> Void)?

    public var activeTool: Tool = .pen {
        didSet {
            window?.invalidateCursorRects(for: self)
            if activeTool != .select {
                clearSelection()
            }
            onToolChanged?(activeTool)
        }
    }
    public var activeColor: NSColor = .black
    public var activeWidth: CGFloat = 4.0

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
            updateTransform()
            needsDisplay = true
            onZoomChanged?(zoomScale)
        }
    }

    // Drawing State
    private var currentStroke: Stroke?
    private var redoStack: [Stroke] = []
    public var selectedStrokeIndex: Int?

    // Spacebar Pan State
    private var isSpacebarPanActive: Bool = false
    private var toolBeforeSpacebarPan: Tool = .select
    private var isDraggingPan: Bool = false
    private var dragPanStartMouse: CGPoint = .zero
    private var dragPanStartOffset: CGPoint = .zero

    // Child PDF item views
    private var pdfItemViews: [UUID: PDFCanvasItemView] = [:]

    // Text Editing
    private var activeTextField: NSTextField?
    private var editingStrokeIndex: Int?

    public init(frame: NSRect, document: WhiteboardDocument = WhiteboardDocument()) {
        self.document = document
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        registerForDraggedTypes([.fileURL])
        loadCurrentPage()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Multi-Page Switching
    public func switchToPage(at index: Int) {
        saveCurrentPageState()
        document.activePageIndex = max(0, min(index, document.pages.count - 1))
        loadCurrentPage()
        canvasDelegate?.canvasDidUpdateDocument(document)
    }

    private func saveCurrentPageState() {
        var page = document.activePage
        page.panOffset = panOffset
        page.zoomScale = zoomScale
        document.activePage = page
    }

    public func loadCurrentPage() {
        // Clear old PDF item views from canvas
        for (_, view) in pdfItemViews {
            view.removeFromSuperview()
        }
        pdfItemViews.removeAll()

        let page = document.activePage
        self.panOffset = page.panOffset
        self.zoomScale = page.zoomScale == 0 ? 1.0 : page.zoomScale
        self.redoStack.removeAll()
        self.selectedStrokeIndex = nil

        // Add PDF item views for this page
        for pdf in page.embeddedPDFs {
            addPDFItemView(pdf)
        }

        updateTransform()
        needsDisplay = true
    }

    private func addPDFItemView(_ pdf: EmbeddedPDF) {
        let itemView = PDFCanvasItemView(embeddedPDF: pdf)
        itemView.delegate = self
        pdfItemViews[pdf.id] = itemView
        addSubview(itemView)
        layoutPDFItem(itemView)
    }

    private func layoutPDFItem(_ view: PDFCanvasItemView) {
        let p = view.embeddedPDF.origin
        let screenX = (p.x * zoomScale) + panOffset.x
        let screenY = (p.y * zoomScale) + panOffset.y
        let screenW = view.embeddedPDF.width * zoomScale
        let screenH = view.embeddedPDF.height * zoomScale
        view.frame = NSRect(x: screenX, y: screenY, width: screenW, height: screenH)
    }

    private func updateTransform() {
        for (_, view) in pdfItemViews {
            layoutPDFItem(view)
        }
    }

    // MARK: - PDFCanvasItemDelegate
    public func pdfItemDidUpdateFrame(_ item: EmbeddedPDF) {
        if let idx = document.activePage.embeddedPDFs.firstIndex(where: { $0.id == item.id }) {
            document.activePage.embeddedPDFs[idx] = item
            canvasDelegate?.canvasDidUpdateDocument(document)
        }
    }

    public func pdfItemDidRequestDelete(_ item: EmbeddedPDF) {
        if let idx = document.activePage.embeddedPDFs.firstIndex(where: { $0.id == item.id }) {
            document.activePage.embeddedPDFs.remove(at: idx)
            pdfItemViews[item.id]?.removeFromSuperview()
            pdfItemViews.removeValue(forKey: item.id)
            canvasDelegate?.canvasDidUpdateDocument(document)
            needsDisplay = true
        }
    }

    // MARK: - Insert PDF File
    public func insertPDF(url: URL, at canvasPoint: CGPoint? = nil) {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let doc = PDFDocument(data: data) else { return }

        let targetPoint = canvasPoint ?? canvasPointFromScreen(CGPoint(x: bounds.midX, y: bounds.midY))
        let initialWidth: CGFloat = 650
        let pageBox = doc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        let aspect = pageBox.height / max(1, pageBox.width)
        let initialHeight = initialWidth * aspect

        let emb = EmbeddedPDF(
            title: url.lastPathComponent,
            pdfData: data,
            origin: CGPoint(x: targetPoint.x - initialWidth / 2, y: targetPoint.y - initialHeight / 2),
            width: initialWidth,
            height: initialHeight,
            currentPage: 0,
            pageCount: doc.pageCount
        )

        document.activePage.embeddedPDFs.append(emb)
        addPDFItemView(emb)
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
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

        // Background
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(bounds)

        // Subtle Pattern (Dots)
        if document.activePage.pattern == "dots" {
            drawDotsPattern(in: ctx)
        }

        ctx.saveGState()
        // Apply Canvas Camera Transformation
        ctx.translateBy(x: panOffset.x, y: panOffset.y)
        ctx.scaleBy(x: zoomScale, y: zoomScale)

        // Draw Completed Strokes
        for (idx, stroke) in document.activePage.strokes.enumerated() {
            drawStroke(stroke, in: ctx, isSelected: idx == selectedStrokeIndex)
        }

        // Draw Live In-Progress Stroke
        if let stroke = currentStroke {
            drawStroke(stroke, in: ctx, isSelected: false)
        }

        ctx.restoreGState()
    }

    private func drawDotsPattern(in ctx: CGContext) {
        let dotSpacing: CGFloat = 28.0 * zoomScale
        guard dotSpacing >= 12 else { return }

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

            let size = max(16, (stroke.fontSize ?? 20.0))
            let font: NSFont = (stroke.isBold == true) ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: stroke.tool == .note ? NSColor.black : color
            ]
            let inset: CGFloat = stroke.tool == .note ? 14.0 : 0.0
            (text as NSString).draw(at: CGPoint(x: p.x + inset, y: p.y + inset), withAttributes: attrs)

            if isSelected {
                drawSelectionBoundingBox(stroke.bounds, in: ctx)
            }
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

        if isSelected {
            drawSelectionBoundingBox(stroke.bounds, in: ctx)
        }

        ctx.restoreGState()
    }

    private func drawSelectionBoundingBox(_ box: CGRect, in ctx: CGContext) {
        let pad: CGFloat = 6.0
        let selRect = box.insetBy(dx: -pad, dy: -pad)
        ctx.setStrokeColor(NSColor.systemBlue.cgColor)
        ctx.setLineWidth(1.5 / zoomScale)
        ctx.setLineDash(phase: 0, lengths: [4 / zoomScale, 4 / zoomScale])
        ctx.stroke(selRect)
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
            handleSelectMouseDown(at: canvasPt)
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

        // Start drawing stroke
        let pt = StrokePoint(x: canvasPt.x, y: canvasPt.y, pressure: CGFloat(event.pressure))
        currentStroke = Stroke(
            tool: activeTool,
            points: [pt],
            colorHex: activeColor.hexString,
            width: activeWidth / (activeTool == .highlighter ? 1.0 : zoomScale)
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

        if activeTool == .eraser {
            eraseAt(canvasPt)
            return
        }

        guard var stroke = currentStroke else { return }

        let pt = StrokePoint(x: canvasPt.x, y: canvasPt.y, pressure: CGFloat(event.pressure))
        if stroke.tool.isShape {
            // Live Shape preview (start point and current drag point)
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

        if let stroke = currentStroke {
            document.activePage.strokes.append(stroke)
            redoStack.removeAll()
            currentStroke = nil
            canvasDelegate?.canvasDidUpdateDocument(document)
            needsDisplay = true
        }
    }

    private func handleSelectMouseDown(at canvasPt: CGPoint) {
        for (idx, stroke) in document.activePage.strokes.enumerated().reversed() {
            if stroke.hitTest(canvasPt, tolerance: 10.0) {
                selectedStrokeIndex = idx
                needsDisplay = true
                return
            }
        }
        clearSelection()
    }

    public func clearSelection() {
        selectedStrokeIndex = nil
        needsDisplay = true
    }

    private func eraseAt(_ pt: CGPoint) {
        var didErase = false
        document.activePage.strokes.removeAll { stroke in
            if stroke.hitTest(pt, tolerance: 16.0) {
                didErase = true
                return true
            }
            return false
        }
        if didErase {
            canvasDelegate?.canvasDidUpdateDocument(document)
            needsDisplay = true
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
        field.backgroundColor = isNote ? NSColor(hex: "#FFF382") : .white
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

    public func commitActiveTextEditor() {
        guard let field = activeTextField, let idx = editingStrokeIndex else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            document.activePage.strokes.remove(at: idx)
        } else {
            document.activePage.strokes[idx].text = text
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
            // Zoom via pinch / cmd-scroll
            let zoomDelta = event.deltaY * 0.015
            let newScale = zoomScale + zoomDelta
            let mousePt = convert(event.locationInWindow, from: nil)
            zoomTo(scale: newScale, centeredAt: mousePt)
            return
        }

        // Two-finger pan
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

    // MARK: - Undo / Redo / Clear
    public func undo() {
        commitActiveTextEditor()
        guard !document.activePage.strokes.isEmpty else { return }
        let stroke = document.activePage.strokes.removeLast()
        redoStack.append(stroke)
        canvasDelegate?.canvasDidUpdateDocument(document)
        needsDisplay = true
    }

    public func redo() {
        commitActiveTextEditor()
        guard !redoStack.isEmpty else { return }
        let stroke = redoStack.removeLast()
        document.activePage.strokes.append(stroke)
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

    // Drag and Drop PDF support
    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let pasteboard = sender.draggingPasteboard.propertyList(forType: .fileURL) as? String,
           let url = URL(string: pasteboard),
           url.pathExtension.lowercased() == "pdf" {
            return .copy
        }
        return []
    }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls where url.pathExtension.lowercased() == "pdf" {
                let loc = convert(sender.draggingLocation, from: nil)
                insertPDF(url: url, at: canvasPointFromScreen(loc))
                return true
            }
        }
        return false
    }

    // MARK: - Keyboard Handling
    public override var acceptsFirstResponder: Bool { true }

    public override func keyDown(with event: NSEvent) {
        // If editing text, let the text field handle it
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

        // Delete / Backspace key
        if event.keyCode == 51 || event.keyCode == 117 {
            if let idx = selectedStrokeIndex, idx < document.activePage.strokes.count {
                document.activePage.strokes.remove(at: idx)
                selectedStrokeIndex = nil
                canvasDelegate?.canvasDidUpdateDocument(document)
                needsDisplay = true
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
        case "p": activeTool = .pen
        case "m": activeTool = .highlighter
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
}
