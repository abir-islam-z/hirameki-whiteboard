import Foundation
import AppKit

public struct EmbeddedImage: Identifiable, Codable {
    public var id: UUID
    public var title: String
    public var imageData: Data
    public var originX: CGFloat
    public var originY: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(
        id: UUID = UUID(),
        title: String = "Image",
        imageData: Data,
        origin: CGPoint = CGPoint(x: 100, y: 100),
        width: CGFloat = 400,
        height: CGFloat = 300
    ) {
        self.id = id
        self.title = title
        self.imageData = imageData
        self.originX = origin.x
        self.originY = origin.y
        self.width = width
        self.height = height
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

    public func makeImage() -> NSImage? {
        NSImage(data: imageData)
    }

    public func makeCGImage() -> CGImage? {
        guard let image = makeImage() else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
