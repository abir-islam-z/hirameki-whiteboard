import Foundation
import CoreGraphics

public struct WhiteboardPage: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var strokes: [Stroke]
    public var embeddedPDFs: [EmbeddedPDF]
    public var embeddedImages: [EmbeddedImage]
    public var pattern: String
    public var panOffsetX: CGFloat
    public var panOffsetY: CGFloat
    public var zoomScale: CGFloat

    public init(
        id: UUID = UUID(),
        name: String = "Page 1",
        strokes: [Stroke] = [],
        embeddedPDFs: [EmbeddedPDF] = [],
        embeddedImages: [EmbeddedImage] = [],
        pattern: String = "dots",
        panOffset: CGPoint = .zero,
        zoomScale: CGFloat = 1.0
    ) {
        self.id = id
        self.name = name
        self.strokes = strokes
        self.embeddedPDFs = embeddedPDFs
        self.embeddedImages = embeddedImages
        self.pattern = pattern
        self.panOffsetX = panOffset.x
        self.panOffsetY = panOffset.y
        self.zoomScale = zoomScale
    }

    public enum CodingKeys: String, CodingKey {
        case id, name, strokes, embeddedPDFs, embeddedImages, pattern, panOffsetX, panOffsetY, zoomScale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Page 1"
        strokes = try container.decodeIfPresent([Stroke].self, forKey: .strokes) ?? []
        embeddedPDFs = try container.decodeIfPresent([EmbeddedPDF].self, forKey: .embeddedPDFs) ?? []
        embeddedImages = try container.decodeIfPresent([EmbeddedImage].self, forKey: .embeddedImages) ?? []
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern) ?? "dots"
        panOffsetX = try container.decodeIfPresent(CGFloat.self, forKey: .panOffsetX) ?? 0
        panOffsetY = try container.decodeIfPresent(CGFloat.self, forKey: .panOffsetY) ?? 0
        zoomScale = try container.decodeIfPresent(CGFloat.self, forKey: .zoomScale) ?? 1.0
    }

    public var panOffset: CGPoint {
        get { CGPoint(x: panOffsetX, y: panOffsetY) }
        set {
            panOffsetX = newValue.x
            panOffsetY = newValue.y
        }
    }
}
