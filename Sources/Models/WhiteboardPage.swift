import Foundation
import CoreGraphics

public struct WhiteboardPage: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var strokes: [Stroke]
    public var embeddedPDFs: [EmbeddedPDF]
    public var pattern: String
    public var panOffsetX: CGFloat
    public var panOffsetY: CGFloat
    public var zoomScale: CGFloat

    public init(
        id: UUID = UUID(),
        name: String = "Page 1",
        strokes: [Stroke] = [],
        embeddedPDFs: [EmbeddedPDF] = [],
        pattern: String = "dots",
        panOffset: CGPoint = .zero,
        zoomScale: CGFloat = 1.0
    ) {
        self.id = id
        self.name = name
        self.strokes = strokes
        self.embeddedPDFs = embeddedPDFs
        self.pattern = pattern
        self.panOffsetX = panOffset.x
        self.panOffsetY = panOffset.y
        self.zoomScale = zoomScale
    }

    public var panOffset: CGPoint {
        get { CGPoint(x: panOffsetX, y: panOffsetY) }
        set {
            panOffsetX = newValue.x
            panOffsetY = newValue.y
        }
    }
}
