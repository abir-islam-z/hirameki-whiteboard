import Foundation
import AppKit
import PDFKit

public struct EmbeddedPDF: Identifiable, Codable {
    public var id: UUID
    public var title: String
    public var pdfData: Data
    public var originX: CGFloat
    public var originY: CGFloat
    public var width: CGFloat
    public var height: CGFloat
    public var currentPage: Int
    public var pageCount: Int

    public init(
        id: UUID = UUID(),
        title: String = "Document.pdf",
        pdfData: Data,
        origin: CGPoint = CGPoint(x: 100, y: 100),
        width: CGFloat = 600,
        height: CGFloat = 800,
        currentPage: Int = 0,
        pageCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.pdfData = pdfData
        self.originX = origin.x
        self.originY = origin.y
        self.width = width
        self.height = height
        self.currentPage = currentPage
        self.pageCount = pageCount
    }

    public var origin: CGPoint {
        get { CGPoint(x: originX, y: originY) }
        set {
            originX = newValue.x
            originY = newValue.y
        }
    }

    public var frame: CGRect {
        get { CGRect(x: originX, y: originY, width: width, height: height) }
        set {
            originX = newValue.origin.x
            originY = newValue.origin.y
            width = newValue.width
            height = newValue.height
        }
    }

    public func makePDFDocument() -> PDFDocument? {
        PDFDocument(data: pdfData)
    }
}
