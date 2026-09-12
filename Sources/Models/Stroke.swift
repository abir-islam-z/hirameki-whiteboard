import AppKit
import CoreGraphics

public struct StrokePoint: Codable {
    public var x: CGFloat
    public var y: CGFloat
    public var pressure: CGFloat
    public var timestamp: TimeInterval

    public init(x: CGFloat, y: CGFloat, pressure: CGFloat = 1.0, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.x = x
        self.y = y
        self.pressure = pressure
        self.timestamp = timestamp
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

public struct Stroke: Identifiable, Codable {
    public var id: UUID
    public var tool: Tool
    public var points: [StrokePoint]
    public var colorHex: String
    public var width: CGFloat
    public var opacity: CGFloat
    public var text: String?
    public var fontSize: CGFloat?
    public var isBold: Bool?
    public var isStickyNote: Bool?
    public var noteBgColorHex: String?
    public var creationTime: TimeInterval

    public init(
        id: UUID = UUID(),
        tool: Tool = .pen,
        points: [StrokePoint] = [],
        colorHex: String = "#000000",
        width: CGFloat = 4.0,
        opacity: CGFloat = 1.0,
        text: String? = nil,
        fontSize: CGFloat? = nil,
        isBold: Bool? = nil,
        isStickyNote: Bool? = nil,
        noteBgColorHex: String? = nil,
        creationTime: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.tool = tool
        self.points = points
        self.colorHex = colorHex
        self.width = width
        self.opacity = opacity
        self.text = text
        self.fontSize = fontSize
        self.isBold = isBold
        self.isStickyNote = isStickyNote
        self.noteBgColorHex = noteBgColorHex
        self.creationTime = creationTime
    }

    public var nsColor: NSColor {
        NSColor(hex: colorHex) ?? .black
    }

    public var bounds: CGRect {
        if tool == .text || tool == .note, let text = text {
            let size = max(16, (fontSize ?? 20.0))
            let font: NSFont = (isBold == true) ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let rect = (text as NSString).boundingRect(
                with: NSSize(width: 320, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs
            )
            let p = points.first?.cgPoint ?? .zero
            let w = max(tool == .note ? 160 : 40, ceil(rect.width) + (tool == .note ? 32 : 16))
            let h = max(tool == .note ? 140 : 28, ceil(rect.height) + (tool == .note ? 32 : 10))
            return CGRect(x: p.x, y: p.y, width: w, height: h)
        }
        guard !points.isEmpty else { return .zero }
        if points.count == 1 {
            let p = points[0]
            let r = max(12.0, width)
            return CGRect(x: p.x - r, y: p.y - r, width: r * 2.0, height: r * 2.0)
        }
        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y
        for p in points {
            minX = min(minX, p.x)
            maxX = max(maxX, p.x)
            minY = min(minY, p.y)
            maxY = max(maxY, p.y)
        }
        let w = max(16.0, maxX - minX)
        let h = max(16.0, maxY - minY)
        return CGRect(x: minX, y: minY, width: w, height: h)
    }

    public func hitTest(_ pt: CGPoint, tolerance: CGFloat = 12.0) -> Bool {
        let b = bounds.insetBy(dx: -tolerance, dy: -tolerance)
        guard b.contains(pt) else { return false }

        if tool == .text || tool == .note { return true }

        if (tool == .line || tool == .arrow) && points.count >= 2 {
            let p0 = points[0].cgPoint
            let p1 = points[points.count - 1].cgPoint
            let dist = distanceToLineSegment(pt, p0, p1)
            return dist <= max(tolerance, width / 2.0 + 6.0)
        }

        return true
    }

    public mutating func translate(by delta: CGPoint) {
        for i in 0..<points.count {
            points[i].x += delta.x
            points[i].y += delta.y
        }
    }

    public mutating func scale(from anchor: CGPoint, scaleX: CGFloat, scaleY: CGFloat) {
        for i in 0..<points.count {
            points[i].x = anchor.x + (points[i].x - anchor.x) * scaleX
            points[i].y = anchor.y + (points[i].y - anchor.y) * scaleY
        }
    }
}

private func distanceToLineSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let lenSq = dx * dx + dy * dy
    if lenSq < 0.001 { return hypot(p.x - a.x, p.y - a.y) }
    let t = max(0.0, min(1.0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lenSq))
    let proj = CGPoint(x: a.x + t * dx, y: a.y + t * dy)
    return hypot(p.x - proj.x, p.y - proj.y)
}

extension NSColor {
    public convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b, a: CGFloat
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    public var hexString: String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
