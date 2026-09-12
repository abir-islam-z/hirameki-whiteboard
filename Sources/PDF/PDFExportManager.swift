import AppKit
import PDFKit

public final class PDFExportManager {
    public static let shared = PDFExportManager()

    /// Exports a WhiteboardPage into a vector PDF representation
    public func exportPageToPDF(page: WhiteboardPage) -> Data {
        // Compute bounding box containing all strokes and embedded PDFs
        var contentRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        var allBounds: [CGRect] = []
        for s in page.strokes {
            allBounds.append(s.bounds)
        }
        for pdf in page.embeddedPDFs {
            allBounds.append(pdf.frame)
        }

        if !allBounds.isEmpty {
            var minX = allBounds[0].minX
            var minY = allBounds[0].minY
            var maxX = allBounds[0].maxX
            var maxY = allBounds[0].maxY
            for b in allBounds {
                minX = min(minX, b.minX)
                minY = min(minY, b.minY)
                maxX = max(maxX, b.maxX)
                maxY = max(maxY, b.maxY)
            }
            contentRect = CGRect(x: minX - 40, y: minY - 40, width: max(800, maxX - minX + 80), height: max(600, maxY - minY + 80))
        }

        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return Data() }
        var mediaBox = contentRect
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }

        ctx.beginPage(mediaBox: &mediaBox)

        // Solid white background
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(contentRect)

        // 1. Draw Embedded PDFs first (background layer)
        for emb in page.embeddedPDFs {
            if let doc = emb.makePDFDocument(), let pdfPage = doc.page(at: emb.currentPage) {
                ctx.saveGState()
                ctx.translateBy(x: emb.originX, y: emb.originY)
                let pageBox = pdfPage.bounds(for: .mediaBox)
                let scaleX = emb.width / max(1, pageBox.width)
                let scaleY = emb.height / max(1, pageBox.height)
                ctx.scaleBy(x: scaleX, y: scaleY)
                pdfPage.draw(with: .mediaBox, to: ctx)
                ctx.restoreGState()
            }
        }

        // 2. Draw Vector Strokes, Shapes, and Text Notes (annotations layer)
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx

        for stroke in page.strokes {
            drawStroke(stroke, in: ctx)
        }

        ctx.endPage()
        ctx.closePDF()

        return pdfData as Data
    }

    private func drawStroke(_ stroke: Stroke, in ctx: CGContext) {
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
            ctx.setAlpha(0.4)
        }

        if stroke.tool == .text || stroke.tool == .note, let text = stroke.text {
            let p = stroke.points[0].cgPoint
            if stroke.tool == .note {
                let noteRect = stroke.bounds
                let noteBg = NSColor(hex: stroke.noteBgColorHex ?? "#FFF275") ?? NSColor.yellow
                ctx.setFillColor(noteBg.cgColor)
                let notePath = CGPath(roundedRect: noteRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
                ctx.addPath(notePath)
                ctx.fillPath()
            }

            let size = max(16, (stroke.fontSize ?? 20.0))
            let font: NSFont = (stroke.isBold == true) ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: stroke.tool == .note ? NSColor.black : color
            ]
            let textInset: CGFloat = stroke.tool == .note ? 14.0 : 0.0
            (text as NSString).draw(at: CGPoint(x: p.x + textInset, y: p.y + textInset), withAttributes: attrs)
            ctx.restoreGState()
            return
        }

        // Vector shapes & freehand strokes
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
            if stroke.tool.isShape && stroke.points.count >= 4 {
                ctx.addPath(path)
                ctx.strokePath()
            } else {
                ctx.addPath(path)
                ctx.strokePath()
            }
        }

        ctx.restoreGState()
    }
}
