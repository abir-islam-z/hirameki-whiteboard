import Foundation
import CoreGraphics

// MARK: - Detected Shape Model
public enum DetectedShape: Equatable {
    case line(start: CGPoint, end: CGPoint)
    case arrow(start: CGPoint, end: CGPoint)
    case doubleArrow(start: CGPoint, end: CGPoint)
    case twistedArrow(start: CGPoint, end: CGPoint, control: CGPoint)
    case rect(CGRect)
    case circle(center: CGPoint, radius: CGFloat)
    case ellipse(CGRect)
    case triangle(p1: CGPoint, p2: CGPoint, p3: CGPoint)
    case pentagon(CGRect)
    case hexagon(CGRect)
    case rhombus(CGRect)
    case parallelogram(CGRect)
    case cube(CGRect)
    case cylinder(CGRect)
    case star(CGRect)
    case capsule(CGRect)
    case speechBubble(CGRect)
    case mathPlus(CGRect)
    case mathMinus(CGRect)
    case mathMultiply(CGRect)
    case mathDivide(CGRect)
    case mathEquals(CGRect)

    public var name: String {
        switch self {
        case .line: return "Line"
        case .arrow: return "Arrow"
        case .doubleArrow: return "Double Arrow"
        case .twistedArrow: return "Twisted Arrow"
        case .rect: return "Rectangle"
        case .circle: return "Circle"
        case .ellipse: return "Ellipse"
        case .triangle: return "Triangle"
        case .pentagon: return "Pentagon"
        case .hexagon: return "Hexagon"
        case .rhombus: return "Rhombus"
        case .parallelogram: return "Parallelogram"
        case .cube: return "3D Cube"
        case .cylinder: return "3D Cylinder"
        case .star: return "Star"
        case .capsule: return "Capsule"
        case .speechBubble: return "Speech Bubble"
        case .mathPlus: return "Plus (+)"
        case .mathMinus: return "Minus (−)"
        case .mathMultiply: return "Multiply (×)"
        case .mathDivide: return "Divide (÷)"
        case .mathEquals: return "Equals (=)"
        }
    }

    public var systemImage: String {
        switch self {
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .doubleArrow: return "arrow.left.and.right"
        case .twistedArrow: return "arrow.triangle.turn.up.right.diamond"
        case .rect: return "rectangle"
        case .circle: return "circle"
        case .ellipse: return "oval"
        case .triangle: return "triangle"
        case .pentagon: return "pentagon"
        case .hexagon: return "hexagon"
        case .rhombus: return "diamond"
        case .parallelogram: return "skew"
        case .cube: return "cube"
        case .cylinder: return "cylinder"
        case .star: return "star"
        case .capsule: return "capsule"
        case .speechBubble: return "bubble.left"
        case .mathPlus: return "plus"
        case .mathMinus: return "minus"
        case .mathMultiply: return "multiply"
        case .mathDivide: return "divide"
        case .mathEquals: return "equal"
        }
    }

    public func createStroke(colorHex: String, width: CGFloat) -> Stroke {
        switch self {
        case .line(let start, let end):
            return Stroke(
                tool: .line,
                points: [StrokePoint(x: start.x, y: start.y), StrokePoint(x: end.x, y: end.y)],
                colorHex: colorHex,
                width: width
            )
        case .arrow(let start, let end):
            return Stroke(
                tool: .arrow,
                points: [StrokePoint(x: start.x, y: start.y), StrokePoint(x: end.x, y: end.y)],
                colorHex: colorHex,
                width: width
            )
        case .doubleArrow(let start, let end):
            return Stroke(
                tool: .doubleArrow,
                points: [StrokePoint(x: start.x, y: start.y), StrokePoint(x: end.x, y: end.y)],
                colorHex: colorHex,
                width: width
            )
        case .twistedArrow(let start, let end, let control):
            return Stroke(
                tool: .twistedArrow,
                points: [StrokePoint(x: start.x, y: start.y), StrokePoint(x: control.x, y: control.y), StrokePoint(x: end.x, y: end.y)],
                colorHex: colorHex,
                width: width
            )
        case .rect(let rect):
            return Stroke(
                tool: .rect,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .circle(let center, let radius):
            let r = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2.0, height: radius * 2.0)
            return Stroke(
                tool: .ellipse,
                points: [StrokePoint(x: r.minX, y: r.minY), StrokePoint(x: r.maxX, y: r.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .ellipse(let rect):
            return Stroke(
                tool: .ellipse,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .triangle(let p1, let p2, let p3):
            return Stroke(
                tool: .triangle,
                points: [
                    StrokePoint(x: p1.x, y: p1.y),
                    StrokePoint(x: p2.x, y: p2.y),
                    StrokePoint(x: p3.x, y: p3.y)
                ],
                colorHex: colorHex,
                width: width
            )
        case .pentagon(let rect):
            return Stroke(
                tool: .pentagon,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .hexagon(let rect):
            return Stroke(
                tool: .hexagon,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .rhombus(let rect):
            return Stroke(
                tool: .rhombus,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .parallelogram(let rect):
            return Stroke(
                tool: .parallelogram,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .cube(let rect):
            return Stroke(
                tool: .cube,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .cylinder(let rect):
            return Stroke(
                tool: .cylinder,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .star(let rect):
            return Stroke(
                tool: .star,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .capsule(let rect):
            return Stroke(
                tool: .capsule,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .speechBubble(let rect):
            return Stroke(
                tool: .speechBubble,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .mathPlus(let rect):
            return Stroke(
                tool: .mathPlus,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .mathMinus(let rect):
            return Stroke(
                tool: .mathMinus,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .mathMultiply(let rect):
            return Stroke(
                tool: .mathMultiply,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .mathDivide(let rect):
            return Stroke(
                tool: .mathDivide,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        case .mathEquals(let rect):
            return Stroke(
                tool: .mathEquals,
                points: [StrokePoint(x: rect.minX, y: rect.minY), StrokePoint(x: rect.maxX, y: rect.maxY)],
                colorHex: colorHex,
                width: width
            )
        }
    }
}

// MARK: - Scored Shape Candidate
public struct ScoredDetectedShape: Equatable {
    public let shape: DetectedShape
    public let confidence: Double

    public init(shape: DetectedShape, confidence: Double) {
        self.shape = shape
        self.confidence = confidence
    }
}

// MARK: - Multi-Stroke Candidate
public struct MultiStrokeCandidate: Equatable {
    public let shape: DetectedShape
    public let strokeIds: [UUID]
    public let confidence: Double

    public init(shape: DetectedShape, strokeIds: [UUID], confidence: Double) {
        self.shape = shape
        self.strokeIds = strokeIds
        self.confidence = confidence
    }
}

// MARK: - Smart Shape Recognition Engine
public struct ShapeDetector {

    /// Returns the single best detected geometric shape, or nil if no shape matches with sufficient confidence.
    public static func detect(from rawPoints: [CGPoint]) -> DetectedShape? {
        return detectCandidates(from: rawPoints, maxCandidates: 1).first
    }

    /// Analyzes a series of points from a freehand stroke and detects multiple close candidate geometric shapes,
    /// ranked by confidence score.
    public static func detectCandidates(from rawPoints: [CGPoint], maxCandidates: Int = 3) -> [DetectedShape] {
        guard rawPoints.count >= 5 else { return [] }

        // 1. Remove duplicate adjacent jitter points
        var points: [CGPoint] = []
        points.reserveCapacity(rawPoints.count)
        for p in rawPoints {
            if let last = points.last {
                if hypot(p.x - last.x, p.y - last.y) >= 1.5 {
                    points.append(p)
                }
            } else {
                points.append(p)
            }
        }
        guard points.count >= 4 else { return [] }

        // 2. Compute stroke metrics
        var totalLength: CGFloat = 0
        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y

        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            totalLength += hypot(p1.x - p0.x, p1.y - p0.y)
            minX = min(minX, p1.x)
            maxX = max(maxX, p1.x)
            minY = min(minY, p1.y)
            maxY = max(maxY, p1.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        let diag = hypot(width, height)

        guard totalLength >= 20, diag >= 12 else { return [] }

        let start = points[0]
        let end = points[points.count - 1]
        let endToEndDist = hypot(end.x - start.x, end.y - start.y)
        let maxDim = max(width, height)
        let isClosed = (endToEndDist / maxDim < 0.45) || (endToEndDist < 50.0 && totalLength > 60.0)

        var candidates: [ScoredDetectedShape] = []

        // 3. Open stroke checks (lines, arrows)
        if !isClosed || (endToEndDist / max(totalLength, 1.0) > 0.55) {
            if let doubleArrow = detectDoubleArrow(points: points, totalLength: totalLength, endToEndDist: endToEndDist) {
                candidates.append(doubleArrow)
            }
            if let twisted = detectTwistedArrow(points: points, totalLength: totalLength, endToEndDist: endToEndDist) {
                candidates.append(twisted)
            }
            if let arrow = detectArrow(points: points, totalLength: totalLength, endToEndDist: endToEndDist) {
                candidates.append(arrow)
            }
            if let line = detectLine(points: points, totalLength: totalLength, endToEndDist: endToEndDist, relaxed: false) {
                candidates.append(line)
            } else if let lineRelaxed = detectLine(points: points, totalLength: totalLength, endToEndDist: endToEndDist, relaxed: true) {
                candidates.append(lineRelaxed)
            }
            if width >= 14 && width / max(height, 1) >= 2.2 && abs(end.y - start.y) <= max(width * 0.28, 14) {
                let minusRect = CGRect(x: minX, y: minY, width: width, height: max(height, 10))
                candidates.append(ScoredDetectedShape(shape: .mathMinus(minusRect), confidence: 0.88))
            }
        }

        // 4. Closed Geometry Checks
        if isClosed || (endToEndDist / max(totalLength, 1.0) < 0.42) {
            let simplified = simplifyClosedPolygon(points, diag: diag)

            // Triangle
            if let triangle = detectTriangle(points: points, poly: simplified, minX: minX, minY: minY, width: width, height: height) {
                candidates.append(triangle)
            }

            // Rectangle / Square
            if let rect = detectRectangle(points: points, poly: simplified, minX: minX, minY: minY, width: width, height: height) {
                candidates.append(rect)
            }

            // Rhombus / Diamond
            if let rhombus = detectRhombus(points: points, poly: simplified, minX: minX, minY: minY, width: width, height: height) {
                candidates.append(rhombus)
            }

            // Parallelogram
            if let parallelogram = detectParallelogram(points: points, poly: simplified, minX: minX, minY: minY, width: width, height: height) {
                candidates.append(parallelogram)
            }

            // Capsule
            if let capsule = detectCapsule(points: points, minX: minX, minY: minY, width: width, height: height, diag: diag) {
                candidates.append(capsule)
            }

            // Circle & Ellipse
            var sumX: CGFloat = 0, sumY: CGFloat = 0
            for p in points { sumX += p.x; sumY += p.y }
            let count = CGFloat(points.count)
            let center = CGPoint(x: sumX / count, y: sumY / count)

            var hasQ1 = false, hasQ2 = false, hasQ3 = false, hasQ4 = false
            for p in points {
                let ang = atan2(p.y - center.y, p.x - center.x)
                if ang >= 0 && ang < .pi / 2 { hasQ1 = true }
                else if ang >= .pi / 2 && ang <= .pi { hasQ2 = true }
                else if ang < 0 && ang >= -.pi / 2 { hasQ4 = true }
                else { hasQ3 = true }
            }

            if hasQ1 && hasQ2 && hasQ3 && hasQ4 {
                if let circle = detectCircle(points: points, center: center, count: count, width: width, height: height, relaxed: false) {
                    candidates.append(circle)
                } else if let circleRel = detectCircle(points: points, center: center, count: count, width: width, height: height, relaxed: true) {
                    candidates.append(circleRel)
                }

                if let ellipse = detectEllipse(points: points, center: center, count: count, width: width, height: height, relaxed: false) {
                    candidates.append(ellipse)
                } else if let ellipseRel = detectEllipse(points: points, center: center, count: count, width: width, height: height, relaxed: true) {
                    candidates.append(ellipseRel)
                }
            }

            // Hexagon & Pentagon
            if let hexagon = detectHexagon(points: points, poly: simplified, minX: minX, minY: minY, width: width, height: height) {
                candidates.append(hexagon)
            }
            if let pentagon = detectPentagon(points: points, poly: simplified, minX: minX, minY: minY, width: width, height: height) {
                candidates.append(pentagon)
            }

            // Star
            if let star = detectStar(points: points, minX: minX, minY: minY, width: width, height: height, diag: diag) {
                candidates.append(star)
            }

            // Cylinder
            if let cylinder = detectCylinder(points: points, minX: minX, minY: minY, width: width, height: height, diag: diag) {
                candidates.append(cylinder)
            }

            // Cube (with strict structural requirements)
            if let cube = detectCube(points: points, minX: minX, minY: minY, width: width, height: height, diag: diag) {
                candidates.append(cube)
            }

            // Speech Bubble (with strict tail validation)
            if let bubble = detectSpeechBubble(points: points, minX: minX, minY: minY, width: width, height: height, diag: diag) {
                candidates.append(bubble)
            }
        }

        // Rank by confidence descending
        let sorted = candidates.sorted { $0.confidence > $1.confidence }
        guard let topScore = sorted.first?.confidence else { return [] }

        // Only include candidates whose score is close to the top match
        let minScoreThreshold = max(0.48, topScore * 0.65)

        var seenNames = Set<String>()
        var result: [DetectedShape] = []

        for item in sorted where item.confidence >= minScoreThreshold {
            if !seenNames.contains(item.shape.name) {
                seenNames.insert(item.shape.name)
                result.append(item.shape)
                if result.count >= maxCandidates {
                    break
                }
            }
        }

        return result
    }

    // MARK: - Straight Line Detection
    private static func detectLine(points: [CGPoint], totalLength: CGFloat, endToEndDist: CGFloat, relaxed: Bool = false) -> ScoredDetectedShape? {
        guard points.count >= 2 else { return nil }
        let straightness = endToEndDist / totalLength
        let minStraightness: CGFloat = relaxed ? 0.76 : 0.82
        guard straightness >= minStraightness else { return nil }

        let pStart = points[0]
        let pEnd = points[points.count - 1]

        // Check maximum perpendicular distance from secant line
        var maxPerp: CGFloat = 0
        let dx = pEnd.x - pStart.x
        let dy = pEnd.y - pStart.y
        let len = max(endToEndDist, 1.0)

        for p in points {
            let perp = abs(dy * p.x - dx * p.y + pEnd.x * pStart.y - pEnd.y * pStart.x) / len
            if perp > maxPerp { maxPerp = perp }
        }

        let maxAllowedPerp = max(18.0, endToEndDist * (relaxed ? 0.22 : 0.18))
        guard maxPerp <= maxAllowedPerp else { return nil }

        // Snap near-horizontal, near-vertical, or 45-degree angles
        var snappedEnd = pEnd
        let angle = atan2(dy, dx) * 180.0 / .pi
        let absAngle = abs(angle)

        if absAngle < 8.0 || absAngle > 172.0 {
            snappedEnd.y = pStart.y
        } else if abs(absAngle - 90.0) < 8.0 {
            snappedEnd.x = pStart.x
        } else if abs(absAngle - 45.0) < 6.0 || abs(absAngle - 135.0) < 6.0 {
            let signX: CGFloat = (dx >= 0) ? 1 : -1
            let signY: CGFloat = (dy >= 0) ? 1 : -1
            let d = max(abs(dx), abs(dy))
            snappedEnd = CGPoint(x: pStart.x + signX * d, y: pStart.y + signY * d)
        }

        let perpRatio = maxPerp / max(endToEndDist * 0.20, 1.0)
        let confidence = max(0.50, min(0.98, Double(straightness) * 0.7 + (1.0 - Double(perpRatio)) * 0.3))
        return ScoredDetectedShape(shape: .line(start: pStart, end: snappedEnd), confidence: confidence)
    }

    // MARK: - Arrow Detection
    private static func detectArrow(points: [CGPoint], totalLength: CGFloat, endToEndDist: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 6 else { return nil }
        let pStart = points[0]

        // Find the point furthest away from the start point (the arrow tip)
        var maxDist: CGFloat = 0
        var tipIndex = 0
        for i in 0..<points.count {
            let d = hypot(points[i].x - pStart.x, points[i].y - pStart.y)
            if d > maxDist {
                maxDist = d
                tipIndex = i
            }
        }

        guard maxDist >= 24.0 else { return nil }

        let fraction = CGFloat(tipIndex) / CGFloat(points.count)
        guard fraction >= 0.52 && tipIndex < points.count - 1 else { return nil }

        // 1. Check shaft straightness (from start to tip)
        var shaftLen: CGFloat = 0
        for i in 1...tipIndex {
            shaftLen += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
        }
        let shaftStraightness = maxDist / max(shaftLen, 1.0)
        guard shaftStraightness >= 0.78 else { return nil }

        // 2. Check the arrowhead return/barb portion (points after tipIndex)
        let tip = points[tipIndex]
        let shaftVector = CGPoint(x: tip.x - pStart.x, y: tip.y - pStart.y)
        let shaftAngle = atan2(shaftVector.y, shaftVector.x)

        var hasReturnBarb = false
        for i in (tipIndex + 1)..<points.count {
            let barbVector = CGPoint(x: points[i].x - tip.x, y: points[i].y - tip.y)
            let barbDist = hypot(barbVector.x, barbVector.y)
            if barbDist > 5.0 {
                let barbAngle = atan2(barbVector.y, barbVector.x)
                var angleDiff = abs(barbAngle - shaftAngle) * 180.0 / .pi
                if angleDiff > 180.0 { angleDiff = 360.0 - angleDiff }
                if angleDiff >= 75.0 {
                    hasReturnBarb = true
                    break
                }
            }
        }

        guard hasReturnBarb else { return nil }
        let confidence = max(0.55, min(0.96, Double(shaftStraightness) * 0.6 + 0.35))
        return ScoredDetectedShape(shape: .arrow(start: pStart, end: tip), confidence: confidence)
    }

    // MARK: - Circle Detection
    private static func detectCircle(points: [CGPoint], center: CGPoint, count: CGFloat, width: CGFloat, height: CGFloat, relaxed: Bool = false) -> ScoredDetectedShape? {
        guard points.count >= 6 else { return nil }
        var radii: [CGFloat] = []
        radii.reserveCapacity(points.count)
        var meanRadius: CGFloat = 0

        for p in points {
            let r = hypot(p.x - center.x, p.y - center.y)
            radii.append(r)
            meanRadius += r
        }
        meanRadius /= count
        guard meanRadius >= 6.0 else { return nil }

        var variance: CGFloat = 0
        for r in radii {
            let diff = r - meanRadius
            variance += diff * diff
        }
        let stdDev = sqrt(variance / count)
        let cv = stdDev / meanRadius

        let aspectRatio = width / max(height, 1.0)
        let isRoughlyEqualAspect = aspectRatio >= 0.70 && aspectRatio <= 1.42
        let maxCVForCircle: CGFloat = relaxed ? 0.22 : 0.15

        guard isRoughlyEqualAspect && cv <= maxCVForCircle else { return nil }

        let aspectPenalty = abs(Double(aspectRatio) - 1.0) * 0.45
        let cvPenalty = Double(cv) * 2.5
        let confidence = max(0.50, min(0.99, 1.0 - aspectPenalty - cvPenalty))

        let circleRadius = (width + height) / 4.0
        return ScoredDetectedShape(shape: .circle(center: center, radius: circleRadius), confidence: confidence)
    }

    // MARK: - Ellipse Detection
    private static func detectEllipse(points: [CGPoint], center: CGPoint, count: CGFloat, width: CGFloat, height: CGFloat, relaxed: Bool = false) -> ScoredDetectedShape? {
        guard points.count >= 6 else { return nil }
        let a = max(width / 2.0, 1.0)
        let b = max(height / 2.0, 1.0)

        var normVariance: CGFloat = 0
        for p in points {
            let dx = (p.x - center.x) / a
            let dy = (p.y - center.y) / b
            let d = sqrt(dx * dx + dy * dy)
            let diff = d - 1.0
            normVariance += diff * diff
        }
        let ellipseError = sqrt(normVariance / count)
        let maxEllipseError: CGFloat = relaxed ? 0.20 : 0.14

        guard ellipseError <= maxEllipseError else { return nil }

        let confidence = max(0.48, min(0.97, 1.0 - Double(ellipseError) * 3.0))
        let rect = CGRect(x: center.x - a, y: center.y - b, width: a * 2.0, height: b * 2.0)
        return ScoredDetectedShape(shape: .ellipse(rect), confidence: confidence)
    }

    // MARK: - Rectangle / Square Detection
    private static func detectRectangle(points: [CGPoint], poly: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) -> ScoredDetectedShape? {
        var corners = poly
        if corners.count == 5 && hypot(corners.first!.x - corners.last!.x, corners.first!.y - corners.last!.y) < 25.0 {
            corners.removeLast()
        }
        guard corners.count == 4 else { return nil }

        let boxArea = width * height
        guard boxArea >= 60 else { return nil }

        let polyArea = polygonArea(corners)
        let areaRatio = polyArea / max(boxArea, 1.0)
        guard areaRatio >= 0.65 && areaRatio <= 1.25 else { return nil }

        var rightAngles = 0
        for i in 0..<4 {
            let ang = cornerAngle(corners[(i + 3) % 4], corners[i], corners[(i + 1) % 4])
            if abs(ang - 90.0) <= 30.0 {
                rightAngles += 1
            }
        }
        guard rightAngles >= 3 else { return nil }

        let aspect = width / max(height, 1.0)
        let isSquare = aspect >= 0.80 && aspect <= 1.25

        let shape: DetectedShape
        if isSquare {
            let side = (width + height) / 2.0
            let cx = minX + width / 2.0
            let cy = minY + height / 2.0
            let sqRect = CGRect(x: cx - side / 2.0, y: cy - side / 2.0, width: side, height: side)
            shape = .rect(sqRect)
        } else {
            let rect = CGRect(x: minX, y: minY, width: width, height: height)
            shape = .rect(rect)
        }

        let areaFit = 1.0 - min(abs(Double(areaRatio) - 1.0), 0.35)
        let angleFit = Double(rightAngles) / 4.0
        let confidence = max(0.50, min(0.98, angleFit * 0.6 + areaFit * 0.4))
        return ScoredDetectedShape(shape: shape, confidence: confidence)
    }

    // MARK: - Triangle Detection
    private static func detectTriangle(points: [CGPoint], poly: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) -> ScoredDetectedShape? {
        var corners = poly
        if corners.count == 4 && hypot(corners[0].x - corners[3].x, corners[0].y - corners[3].y) < 25.0 {
            corners.removeLast()
        }
        guard corners.count == 3 else { return nil }

        let boxArea = width * height
        guard boxArea >= 60 else { return nil }

        let polyArea = polygonArea(corners)
        let areaRatio = polyArea / boxArea

        guard areaRatio >= 0.18 && areaRatio <= 0.65 else { return nil }

        let a0 = cornerAngle(corners[2], corners[0], corners[1])
        let a1 = cornerAngle(corners[0], corners[1], corners[2])
        let a2 = cornerAngle(corners[1], corners[2], corners[0])
        let sumAngles = a0 + a1 + a2

        guard abs(sumAngles - 180.0) <= 55.0 else { return nil }
        guard a0 >= 14.0 && a1 >= 14.0 && a2 >= 14.0 else { return nil }

        let angleDev = abs(Double(sumAngles) - 180.0) / 180.0
        let confidence = max(0.50, min(0.96, 1.0 - angleDev * 1.5))
        return ScoredDetectedShape(shape: .triangle(p1: corners[0], p2: corners[1], p3: corners[2]), confidence: confidence)
    }

    // MARK: - Double Arrow Detection
    private static func detectDoubleArrow(points: [CGPoint], totalLength: CGFloat, endToEndDist: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 10, endToEndDist >= 30.0 else { return nil }
        let pStart = points[0]
        let pEnd = points[points.count - 1]

        var maxD: CGFloat = 0
        var bestStart = pStart
        var bestEnd = pEnd
        let startLimit = min(points.count / 4, 10)
        let endStart = max(points.count - 10, points.count * 3 / 4)

        for i in 0..<startLimit {
            for j in endStart..<points.count {
                let d = hypot(points[j].x - points[i].x, points[j].y - points[i].y)
                if d > maxD {
                    maxD = d
                    bestStart = points[i]
                    bestEnd = points[j]
                }
            }
        }

        guard maxD >= 30.0 else { return nil }
        let straightness = maxD / max(totalLength, 1.0)
        guard straightness >= 0.35 else { return nil }

        var startHasBarb = false
        for i in 1..<min(points.count / 3, 14) {
            let ang = cornerAngle(points[i - 1], points[i], points[i + 1])
            if ang <= 115.0 {
                startHasBarb = true
                break
            }
        }

        var endHasBarb = false
        for i in max(points.count * 2 / 3, points.count - 14)..<(points.count - 1) {
            let ang = cornerAngle(points[i - 1], points[i], points[i + 1])
            if ang <= 115.0 {
                endHasBarb = true
                break
            }
        }

        if startHasBarb && endHasBarb {
            return ScoredDetectedShape(shape: .doubleArrow(start: bestStart, end: bestEnd), confidence: 0.85)
        }
        return nil
    }

    // MARK: - Twisted Arrow Detection
    private static func detectTwistedArrow(points: [CGPoint], totalLength: CGFloat, endToEndDist: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 8, endToEndDist >= 25.0 else { return nil }
        let pStart = points[0]

        var maxDist: CGFloat = 0
        var tipIndex = 0
        for i in 0..<points.count {
            let d = hypot(points[i].x - pStart.x, points[i].y - pStart.y)
            if d > maxDist {
                maxDist = d
                tipIndex = i
            }
        }

        guard maxDist >= 20.0 else { return nil }
        let fraction = CGFloat(tipIndex) / CGFloat(points.count)
        guard fraction >= 0.48 && tipIndex < points.count - 1 else { return nil }

        let tip = points[tipIndex]
        let chord = hypot(tip.x - pStart.x, tip.y - pStart.y)

        var shaftLen: CGFloat = 0
        var maxPerp: CGFloat = 0
        var maxPerpPoint = points[tipIndex / 2]

        let dx = tip.x - pStart.x
        let dy = tip.y - pStart.y

        for i in 1...tipIndex {
            shaftLen += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
            let p = points[i]
            let perp = abs(dy * p.x - dx * p.y + tip.x * pStart.y - tip.y * pStart.x) / max(chord, 1.0)
            if perp > maxPerp {
                maxPerp = perp
                maxPerpPoint = p
            }
        }

        let straightness = chord / max(shaftLen, 1.0)
        guard straightness >= 0.40 && straightness <= 0.85 && maxPerp >= 8.0 else { return nil }

        let shaftVector = CGPoint(x: tip.x - pStart.x, y: tip.y - pStart.y)
        let shaftAngle = atan2(shaftVector.y, shaftVector.x)
        var hasBarb = false
        for i in (tipIndex + 1)..<points.count {
            let barbVector = CGPoint(x: points[i].x - tip.x, y: points[i].y - tip.y)
            let barbDist = hypot(barbVector.x, barbVector.y)
            if barbDist > 3.5 {
                let barbAngle = atan2(barbVector.y, barbVector.x)
                var angleDiff = abs(barbAngle - shaftAngle) * 180.0 / .pi
                if angleDiff > 180.0 { angleDiff = 360.0 - angleDiff }
                if angleDiff >= 60.0 {
                    hasBarb = true
                    break
                }
            }
        }

        guard hasBarb else { return nil }
        return ScoredDetectedShape(shape: .twistedArrow(start: pStart, end: tip, control: maxPerpPoint), confidence: 0.82)
    }

    // MARK: - Star Detection
    private static func detectStar(points: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat, diag: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 14, width >= 24, height >= 24 else { return nil }
        let center = CGPoint(x: minX + width / 2.0, y: minY + height / 2.0)
        let radii = points.map { hypot($0.x - center.x, $0.y - center.y) }
        guard let maxR = radii.max(), let minR = radii.min(), maxR >= 14.0 else { return nil }
        guard maxR / max(minR, 1.0) >= 1.55 else { return nil }

        var peakCount = 0
        var inPeak = false
        for r in radii {
            if r >= maxR * 0.70 {
                if !inPeak {
                    peakCount += 1
                    inPeak = true
                }
            } else if r <= maxR * 0.50 {
                inPeak = false
            }
        }

        if peakCount >= 4 && peakCount <= 6 {
            let side = max(width, height)
            let sqRect = CGRect(x: center.x - side / 2.0, y: center.y - side / 2.0, width: side, height: side)
            return ScoredDetectedShape(shape: .star(sqRect), confidence: 0.88)
        }
        return nil
    }

    // MARK: - Speech Bubble Detection
    private static func detectSpeechBubble(points: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat, diag: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 14, width >= 32, height >= 28 else { return nil }
        let aspect = width / max(height, 1.0)
        guard aspect >= 0.65 && aspect <= 1.65 else { return nil }

        var sumX: CGFloat = 0, sumY: CGFloat = 0
        for p in points { sumX += p.x; sumY += p.y }
        let cx = sumX / CGFloat(points.count)
        let cy = sumY / CGFloat(points.count)

        let radii = points.map { hypot($0.x - cx, $0.y - cy) }.sorted()
        let medianR = radii[radii.count / 2]
        guard medianR >= 12.0 else { return nil }

        // Find outward protruding points (the speech bubble tail)
        var tailPoints: [CGPoint] = []
        for p in points {
            let r = hypot(p.x - cx, p.y - cy)
            if r >= medianR * 1.25 && p.y >= cy {
                tailPoints.append(p)
            }
        }

        guard !tailPoints.isEmpty else { return nil }
        let tailRatio = CGFloat(tailPoints.count) / CGFloat(points.count)
        guard tailRatio >= 0.04 && tailRatio <= 0.22 else { return nil }

        let tailAngles = tailPoints.map { atan2($0.y - cy, $0.x - cx) }
        guard let minA = tailAngles.min(), let maxA = tailAngles.max() else { return nil }
        var span = abs(maxA - minA) * 180.0 / .pi
        if span > 180.0 { span = 360.0 - span }
        guard span <= 85.0 else { return nil }

        return ScoredDetectedShape(shape: .speechBubble(CGRect(x: minX, y: minY, width: width, height: height)), confidence: 0.75)
    }

    // MARK: - 3D Cube Detection
    private static func detectCube(points: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat, diag: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 14, width >= 28, height >= 28 else { return nil }
        let aspect = width / max(height, 1.0)
        guard aspect >= 0.68 && aspect <= 1.45 else { return nil }

        let perimeter = 2.0 * (width + height)
        var totalLen: CGFloat = 0
        for i in 1..<points.count {
            totalLen += hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
        }
        // Require significant stroke overlapping / perimeter ratio
        guard totalLen / max(perimeter, 1.0) >= 1.40 else { return nil }

        let simplified = simplifyClosedPolygon(points, diag: diag)
        if simplified.count >= 6 && simplified.count <= 10 {
            let area = polygonArea(simplified)
            let boxArea = width * height
            let areaRatio = area / boxArea
            if areaRatio >= 0.55 && areaRatio <= 0.95 {
                return ScoredDetectedShape(shape: .cube(CGRect(x: minX, y: minY, width: width, height: height)), confidence: 0.72)
            }
        }
        return nil
    }

    // MARK: - 3D Cylinder Detection
    private static func detectCylinder(points: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat, diag: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 16, width >= 25, height >= 35 else { return nil }
        let aspect = height / max(width, 1.0)
        guard aspect >= 1.15 else { return nil }

        let midYMin = minY + height * 0.25
        let midYMax = minY + height * 0.75

        let leftPoints = points.filter { $0.y >= midYMin && $0.y <= midYMax && $0.x <= minX + width * 0.25 }
        let rightPoints = points.filter { $0.y >= midYMin && $0.y <= midYMax && $0.x >= minX + width * 0.75 }

        guard leftPoints.count >= 3 && rightPoints.count >= 3 else { return nil }

        let leftMeanX = leftPoints.map { $0.x }.reduce(0, +) / CGFloat(leftPoints.count)
        let leftStdX = sqrt(leftPoints.map { pow($0.x - leftMeanX, 2) }.reduce(0, +) / CGFloat(leftPoints.count))

        let rightMeanX = rightPoints.map { $0.x }.reduce(0, +) / CGFloat(rightPoints.count)
        let rightStdX = sqrt(rightPoints.map { pow($0.x - rightMeanX, 2) }.reduce(0, +) / CGFloat(rightPoints.count))

        guard leftStdX <= max(6.0, width * 0.08) && rightStdX <= max(6.0, width * 0.08) else { return nil }

        let topPoints = points.filter { $0.y <= minY + height * 0.25 }
        guard topPoints.count >= 4 else { return nil }

        return ScoredDetectedShape(shape: .cylinder(CGRect(x: minX, y: minY, width: width, height: height)), confidence: 0.75)
    }

    // MARK: - Capsule Detection
    private static func detectCapsule(points: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat, diag: CGFloat) -> ScoredDetectedShape? {
        guard points.count >= 14 else { return nil }
        let aspect = width / max(height, 1.0)
        let isHorizontalCapsule = aspect >= 1.55
        let isVerticalCapsule = aspect <= 0.65

        guard isHorizontalCapsule || isVerticalCapsule else { return nil }

        let boxArea = width * height
        let area = polygonArea(points)
        let areaRatio = area / max(boxArea, 1.0)
        guard areaRatio >= 0.70 && areaRatio <= 0.95 else { return nil }

        let poly = simplifyClosedPolygon(points, diag: diag)
        if poly.count == 4 {
            let a0 = cornerAngle(poly[3], poly[0], poly[1])
            let a1 = cornerAngle(poly[0], poly[1], poly[2])
            if a0 < 125.0 && a1 < 125.0 {
                return nil
            }
        }
        return ScoredDetectedShape(shape: .capsule(CGRect(x: minX, y: minY, width: width, height: height)), confidence: 0.80)
    }

    // MARK: - Rhombus Detection
    private static func detectRhombus(points: [CGPoint], poly: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) -> ScoredDetectedShape? {
        var corners = poly
        if corners.count == 5 && hypot(corners.first!.x - corners.last!.x, corners.first!.y - corners.last!.y) < 25.0 {
            corners.removeLast()
        }
        guard corners.count == 4 else { return nil }

        // Require sharp corners so smooth circles are never classified as rhombus
        var sharpCorners = 0
        for i in 0..<4 {
            let ang = cornerAngle(corners[(i + 3) % 4], corners[i], corners[(i + 1) % 4])
            if ang <= 125.0 { sharpCorners += 1 }
        }
        guard sharpCorners >= 3 else { return nil }

        let midX = minX + width / 2.0
        let midY = minY + height / 2.0

        var hasTop = false, hasBottom = false, hasLeft = false, hasRight = false
        let tolX = width * 0.35
        let tolY = height * 0.35

        for c in corners {
            if abs(c.x - midX) <= tolX && abs(c.y - minY) <= tolY { hasTop = true }
            else if abs(c.x - midX) <= tolX && abs(c.y - (minY + height)) <= tolY { hasBottom = true }
            else if abs(c.x - minX) <= tolX && abs(c.y - midY) <= tolY { hasLeft = true }
            else if abs(c.x - (minX + width)) <= tolX && abs(c.y - midY) <= tolY { hasRight = true }
        }

        if hasTop && hasBottom && hasLeft && hasRight {
            let areaRatio = polygonArea(corners) / max(width * height, 1.0)
            if areaRatio >= 0.32 && areaRatio <= 0.68 {
                return ScoredDetectedShape(shape: .rhombus(CGRect(x: minX, y: minY, width: width, height: height)), confidence: 0.78)
            }
        }
        return nil
    }

    // MARK: - Parallelogram Detection
    private static func detectParallelogram(points: [CGPoint], poly: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) -> ScoredDetectedShape? {
        var corners = poly
        if corners.count == 5 && hypot(corners.first!.x - corners.last!.x, corners.first!.y - corners.last!.y) < 25.0 {
            corners.removeLast()
        }
        guard corners.count == 4 else { return nil }

        let areaRatio = polygonArea(corners) / max(width * height, 1.0)
        guard areaRatio >= 0.58 && areaRatio <= 0.95 else { return nil }

        let v0 = CGPoint(x: corners[1].x - corners[0].x, y: corners[1].y - corners[0].y)
        let v2 = CGPoint(x: corners[2].x - corners[3].x, y: corners[2].y - corners[3].y)
        let ang0 = atan2(v0.y, v0.x) * 180.0 / .pi
        let ang2 = atan2(v2.y, v2.x) * 180.0 / .pi
        var diff02 = abs(ang0 - ang2)
        if diff02 > 180.0 { diff02 = 360.0 - diff02 }

        let angle0 = cornerAngle(corners[3], corners[0], corners[1])
        let isSlanted = abs(angle0 - 90.0) >= 12.0 && abs(angle0 - 90.0) <= 58.0

        if diff02 <= 28.0 && isSlanted {
            return ScoredDetectedShape(shape: .parallelogram(CGRect(x: minX, y: minY, width: width, height: height)), confidence: 0.80)
        }
        return nil
    }

    // MARK: - Pentagon Detection
    private static func detectPentagon(points: [CGPoint], poly: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) -> ScoredDetectedShape? {
        var corners = poly
        if corners.count == 6 && hypot(corners.first!.x - corners.last!.x, corners.first!.y - corners.last!.y) < 25.0 {
            corners.removeLast()
        }
        guard corners.count == 5 else { return nil }

        let aspect = width / max(height, 1.0)
        guard aspect >= 0.68 && aspect <= 1.45 else { return nil }

        let boxArea = width * height
        let polyArea = polygonArea(corners)
        let areaRatio = polyArea / max(boxArea, 1.0)
        guard areaRatio >= 0.48 && areaRatio <= 0.88 else { return nil }

        var validAngles = 0
        for i in 0..<5 {
            let ang = cornerAngle(corners[(i + 4) % 5], corners[i], corners[(i + 1) % 5])
            if ang >= 68.0 && ang <= 145.0 {
                validAngles += 1
            }
        }

        if validAngles >= 4 {
            let side = max(width, height)
            let cx = minX + width / 2.0
            let cy = minY + height / 2.0
            let rect = CGRect(x: cx - side / 2.0, y: cy - side / 2.0, width: side, height: side)
            return ScoredDetectedShape(shape: .pentagon(rect), confidence: 0.82)
        }
        return nil
    }

    // MARK: - Hexagon Detection
    private static func detectHexagon(points: [CGPoint], poly: [CGPoint], minX: CGFloat, minY: CGFloat, width: CGFloat, height: CGFloat) -> ScoredDetectedShape? {
        var corners = poly
        if corners.count == 7 && hypot(corners.first!.x - corners.last!.x, corners.first!.y - corners.last!.y) < 25.0 {
            corners.removeLast()
        }
        guard corners.count == 6 else { return nil }

        let aspect = width / max(height, 1.0)
        guard aspect >= 0.65 && aspect <= 1.50 else { return nil }

        var sides: [CGFloat] = []
        for i in 0..<6 {
            let s = hypot(corners[(i + 1) % 6].x - corners[i].x, corners[(i + 1) % 6].y - corners[i].y)
            sides.append(s)
        }
        guard let minS = sides.min(), let maxS = sides.max(), minS / max(maxS, 1.0) >= 0.35 else { return nil }

        let boxArea = width * height
        let polyArea = polygonArea(corners)
        let areaRatio = polyArea / max(boxArea, 1.0)
        guard areaRatio >= 0.58 && areaRatio <= 0.94 else { return nil }

        var validAngles = 0
        for i in 0..<6 {
            let ang = cornerAngle(corners[(i + 5) % 6], corners[i], corners[(i + 1) % 6])
            if ang >= 88.0 && ang <= 145.0 {
                validAngles += 1
            }
        }

        if validAngles >= 4 {
            let side = max(width, height)
            let cx = minX + width / 2.0
            let cy = minY + height / 2.0
            let rect = CGRect(x: cx - side / 2.0, y: cy - side / 2.0, width: side, height: side)
            return ScoredDetectedShape(shape: .hexagon(rect), confidence: 0.82)
        }
        return nil
    }

    private static func simplifyClosedPolygon(_ points: [CGPoint], diag: CGFloat) -> [CGPoint] {
        guard points.count > 4 else { return points }
        let epsilon = max(6.0, diag * 0.04)

        // Find point furthest from points[0] to bisect closed loop
        let p0 = points[0]
        var maxD: CGFloat = 0
        var farIdx = points.count / 2
        for i in 1..<points.count {
            let d = hypot(points[i].x - p0.x, points[i].y - p0.y)
            if d > maxD {
                maxD = d
                farIdx = i
            }
        }

        let half1 = ramerDouglasPeucker(Array(points[0...farIdx]), epsilon: epsilon)
        let half2 = ramerDouglasPeucker(Array(points[farIdx..<points.count]), epsilon: epsilon)
        var poly = Array(half1.dropLast()) + half2
        if poly.count > 2 && hypot(poly.first!.x - poly.last!.x, poly.first!.y - poly.last!.y) < 25 {
            poly.removeLast()
        }
        return filterCollinearVertices(poly)
    }

    private static func filterCollinearVertices(_ poly: [CGPoint]) -> [CGPoint] {
        let pts = poly
        guard pts.count > 3 else { return pts }

        // 1. Remove duplicate/very close consecutive vertices
        var deduped: [CGPoint] = []
        for i in 0..<pts.count {
            let next = pts[(i + 1) % pts.count]
            if hypot(pts[i].x - next.x, pts[i].y - next.y) > 8.0 {
                deduped.append(pts[i])
            }
        }
        guard deduped.count > 3 else { return pts }

        // 2. Filter vertices where interior angle is nearly straight (> 150°)
        var filtered: [CGPoint] = []
        for i in 0..<deduped.count {
            let prev = deduped[(i + deduped.count - 1) % deduped.count]
            let curr = deduped[i]
            let next = deduped[(i + 1) % deduped.count]
            let ang = cornerAngle(prev, curr, next)
            // If the angle is ~180 (straight edge), it's a midpoint split artifact, not a corner
            if ang < 152.0 {
                filtered.append(curr)
            }
        }

        return filtered.count >= 3 ? filtered : deduped
    }

    // MARK: - Interactive Drag Resizing / Updating
    /// Dynamically transforms the snapped shape as the user drags before releasing.
    public static func updateSnappedShape(_ shape: DetectedShape, withCurrentPoint point: CGPoint) -> DetectedShape {
        switch shape {
        case .line(let start, _):
            var snappedEnd = point
            let dx = point.x - start.x
            let dy = point.y - start.y
            let angle = abs(atan2(dy, dx) * 180.0 / .pi)
            if angle < 6.0 || angle > 174.0 {
                snappedEnd.y = start.y
            } else if abs(angle - 90.0) < 6.0 {
                snappedEnd.x = start.x
            }
            return .line(start: start, end: snappedEnd)

        case .arrow(let start, _):
            return .arrow(start: start, end: point)

        case .doubleArrow(let start, _):
            return .doubleArrow(start: start, end: point)

        case .twistedArrow(let start, _, let ctrl):
            return .twistedArrow(start: start, end: point, control: ctrl)

        case .circle(let center, _):
            let newRadius = max(8.0, hypot(point.x - center.x, point.y - center.y))
            return .circle(center: center, radius: newRadius)

        case .rect(let r):
            return .rect(makeUpdatedRect(from: r.origin, to: point))

        case .ellipse(let r):
            return .ellipse(makeUpdatedRect(from: r.origin, to: point))

        case .triangle(let p1, let p2, _):
            return .triangle(p1: p1, p2: p2, p3: point)

        case .pentagon(let r):
            return .pentagon(makeUpdatedRect(from: r.origin, to: point))

        case .hexagon(let r):
            return .hexagon(makeUpdatedRect(from: r.origin, to: point))

        case .rhombus(let r):
            return .rhombus(makeUpdatedRect(from: r.origin, to: point))

        case .parallelogram(let r):
            return .parallelogram(makeUpdatedRect(from: r.origin, to: point))

        case .cube(let r):
            return .cube(makeUpdatedRect(from: r.origin, to: point))

        case .cylinder(let r):
            return .cylinder(makeUpdatedRect(from: r.origin, to: point))

        case .star(let r):
            return .star(makeUpdatedRect(from: r.origin, to: point))

        case .capsule(let r):
            return .capsule(makeUpdatedRect(from: r.origin, to: point))

        case .speechBubble(let r):
            return .speechBubble(makeUpdatedRect(from: r.origin, to: point))

        case .mathPlus(let r):
            return .mathPlus(makeUpdatedRect(from: r.origin, to: point))

        case .mathMinus(let r):
            return .mathMinus(makeUpdatedRect(from: r.origin, to: point))

        case .mathMultiply(let r):
            return .mathMultiply(makeUpdatedRect(from: r.origin, to: point))

        case .mathDivide(let r):
            return .mathDivide(makeUpdatedRect(from: r.origin, to: point))

        case .mathEquals(let r):
            return .mathEquals(makeUpdatedRect(from: r.origin, to: point))
        }
    }

    private static func makeUpdatedRect(from origin: CGPoint, to point: CGPoint) -> CGRect {
        let minX = min(origin.x, point.x)
        let minY = min(origin.y, point.y)
        let w = max(10.0, abs(point.x - origin.x))
        let h = max(10.0, abs(point.y - origin.y))
        return CGRect(x: minX, y: minY, width: w, height: h)
    }

    // MARK: - Helper Algorithms (RDP, Angles, Area)
    private static func ramerDouglasPeucker(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var maxDist: CGFloat = 0
        var index = 0
        let p0 = points.first!
        let pEnd = points.last!

        let dx = pEnd.x - p0.x
        let dy = pEnd.y - p0.y
        let len = hypot(dx, dy)
        let isClosedLoop = len < 2.0

        for i in 1..<(points.count - 1) {
            let p = points[i]
            let dist: CGFloat
            if isClosedLoop {
                dist = hypot(p.x - p0.x, p.y - p0.y)
            } else {
                dist = abs(dy * p.x - dx * p.y + pEnd.x * p0.y - pEnd.y * p0.x) / len
            }
            if dist > maxDist {
                maxDist = dist
                index = i
            }
        }

        if maxDist > epsilon {
            let left = ramerDouglasPeucker(Array(points[0...index]), epsilon: epsilon)
            let right = ramerDouglasPeucker(Array(points[index..<points.count]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [p0, pEnd]
        }
    }

    private static func polygonArea(_ poly: [CGPoint]) -> CGFloat {
        guard poly.count >= 3 else { return 0 }
        var area: CGFloat = 0
        for i in 0..<poly.count {
            let j = (i + 1) % poly.count
            area += poly[i].x * poly[j].y
            area -= poly[j].x * poly[i].y
        }
        return abs(area) / 2.0
    }

    private static func cornerAngle(_ pPrev: CGPoint, _ pCurr: CGPoint, _ pNext: CGPoint) -> CGFloat {
        let v1 = CGPoint(x: pPrev.x - pCurr.x, y: pPrev.y - pCurr.y)
        let v2 = CGPoint(x: pNext.x - pCurr.x, y: pNext.y - pCurr.y)
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = hypot(v1.x, v1.y)
        let mag2 = hypot(v2.x, v2.y)
        guard mag1 > 0.001 && mag2 > 0.001 else { return 0 }
        let cosTheta = max(-1.0, min(1.0, dot / (mag1 * mag2)))
        return acos(cosTheta) * 180.0 / .pi
    }

    private static func mergeClosestVertices(_ vertices: [CGPoint], targetCount: Int) -> [CGPoint] {
        var result = vertices
        while result.count > targetCount {
            var minDistance: CGFloat = .infinity
            var mergeIdx = 0
            for i in 0..<result.count {
                let nextIdx = (i + 1) % result.count
                let d = hypot(result[nextIdx].x - result[i].x, result[nextIdx].y - result[i].y)
                if d < minDistance {
                    minDistance = d
                    mergeIdx = i
                }
            }
            let nextIdx = (mergeIdx + 1) % result.count
            let mid = CGPoint(
                x: (result[mergeIdx].x + result[nextIdx].x) / 2.0,
                y: (result[mergeIdx].y + result[nextIdx].y) / 2.0
            )
            result[mergeIdx] = mid
            result.remove(at: nextIdx)
        }
        return result
    }

    // MARK: - Multi-Stroke Shape & Math Detection Engine
    public static func detectMultiStrokeCandidates(recentStrokes: [Stroke], maxCandidates: Int = 3) -> [MultiStrokeCandidate] {
        guard recentStrokes.count >= 2 else { return [] }
        var results: [MultiStrokeCandidate] = []

        // 1. Check last 2 strokes for Math signs (+, ×, =)
        if recentStrokes.count >= 2 {
            let s1 = recentStrokes[recentStrokes.count - 2]
            let s2 = recentStrokes[recentStrokes.count - 1]
            if let mathCandidate = detectTwoStrokeMath(s1: s1, s2: s2) {
                results.append(mathCandidate)
            }
        }

        // 2. Check last 3 strokes for Math sign (÷)
        if recentStrokes.count >= 3 {
            let s1 = recentStrokes[recentStrokes.count - 3]
            let s2 = recentStrokes[recentStrokes.count - 2]
            let s3 = recentStrokes[recentStrokes.count - 1]
            if let divideCandidate = detectThreeStrokeDivide(s1: s1, s2: s2, s3: s3) {
                results.append(divideCandidate)
            }
        }

        // 3. Check 2, 3, or 4 joined strokes forming geometric shapes (rect, triangle, circle, etc.)
        for count in [2, 3, 4] {
            guard recentStrokes.count >= count else { continue }
            let slice = Array(recentStrokes.suffix(count))
            if let joined = detectJoinedStrokesShape(strokes: slice) {
                results.append(contentsOf: joined)
            }
        }

        // Sort by confidence and deduplicate
        let sorted = results.sorted { $0.confidence > $1.confidence }
        var seen = Set<String>()
        var finalResults: [MultiStrokeCandidate] = []
        for cand in sorted {
            if !seen.contains(cand.shape.name) {
                seen.insert(cand.shape.name)
                finalResults.append(cand)
                if finalResults.count >= maxCandidates {
                    break
                }
            }
        }
        return finalResults
    }

    private static func detectTwoStrokeMath(s1: Stroke, s2: Stroke) -> MultiStrokeCandidate? {
        let pts1 = s1.points.map(\.cgPoint)
        let pts2 = s2.points.map(\.cgPoint)
        guard pts1.count >= 2 && pts2.count >= 2 else { return nil }

        let b1 = s1.bounds
        let b2 = s2.bounds
        let unionB = b1.union(b2)
        let maxDim = max(unionB.width, unionB.height)
        guard maxDim >= 14 && maxDim <= 800 else { return nil }

        let c1 = CGPoint(x: b1.midX, y: b1.midY)
        let c2 = CGPoint(x: b2.midX, y: b2.midY)
        let centerDist = hypot(c1.x - c2.x, c1.y - c2.y)

        let w1 = b1.width, h1 = b1.height
        let w2 = b2.width, h2 = b2.height

        // A. Plus (+): One horizontal, one vertical, intersecting near center
        let s1Horizontal = w1 > h1 * 1.5
        let s1Vertical = h1 > w1 * 1.5
        let s2Horizontal = w2 > h2 * 1.5
        let s2Vertical = h2 > w2 * 1.5

        if (s1Horizontal && s2Vertical) || (s1Vertical && s2Horizontal) {
            let horizLen = s1Horizontal ? w1 : w2
            let vertLen = s1Vertical ? h1 : h2
            let ratio = min(horizLen, vertLen) / max(horizLen, vertLen)
            if ratio >= 0.35 && centerDist <= maxDim * 0.38 {
                let squareSize = max(horizLen, vertLen)
                let center = CGPoint(x: unionB.midX, y: unionB.midY)
                let plusRect = CGRect(x: center.x - squareSize / 2, y: center.y - squareSize / 2, width: squareSize, height: squareSize)
                return MultiStrokeCandidate(shape: .mathPlus(plusRect), strokeIds: [s1.id, s2.id], confidence: 0.95)
            }
        }

        // B. Multiply (×): Two diagonal intersecting lines
        guard let p1Start = pts1.first, let p1End = pts1.last,
              let p2Start = pts2.first, let p2End = pts2.last else { return nil }

        let dx1 = p1End.x - p1Start.x
        let dy1 = p1End.y - p1Start.y
        let dx2 = p2End.x - p2Start.x
        let dy2 = p2End.y - p2Start.y

        let len1 = hypot(dx1, dy1)
        let len2 = hypot(dx2, dy2)
        if len1 >= 12 && len2 >= 12 && min(len1, len2) / max(len1, len2) >= 0.45 && centerDist <= maxDim * 0.38 {
            // Both strokes must be diagonal (neither horizontal nor vertical)
            let isDiag1 = abs(dx1) > 0.22 * len1 && abs(dy1) > 0.22 * len1
            let isDiag2 = abs(dx2) > 0.22 * len2 && abs(dy2) > 0.22 * len2
            if isDiag1 && isDiag2 {
                // Undirected angle between lines: cos(theta) = |v1 . v2| / (|v1| * |v2|)
                let dot = abs(dx1 * dx2 + dy1 * dy2)
                let cosTheta = dot / (len1 * len2)
                // Angle between ~40° and 90° means cosTheta <= 0.766
                if cosTheta <= 0.75 {
                    let squareSize = max(unionB.width, unionB.height)
                    let center = CGPoint(x: unionB.midX, y: unionB.midY)
                    let multRect = CGRect(x: center.x - squareSize / 2, y: center.y - squareSize / 2, width: squareSize, height: squareSize)
                    return MultiStrokeCandidate(shape: .mathMultiply(multRect), strokeIds: [s1.id, s2.id], confidence: 0.94)
                }
            }
        }

        // C. Equals (=): Two parallel horizontal lines
        if s1Horizontal && s2Horizontal {
            let vertGap = abs(c1.y - c2.y)
            let horizOverlap = min(b1.maxX, b2.maxX) - max(b1.minX, b2.minX)
            let maxW = max(w1, w2)
            if maxW >= 12 && horizOverlap / maxW >= 0.50 && vertGap >= 4 && vertGap <= maxW * 0.85 {
                let eqRect = CGRect(x: unionB.minX, y: unionB.minY, width: unionB.width, height: max(unionB.height, 14))
                return MultiStrokeCandidate(shape: .mathEquals(eqRect), strokeIds: [s1.id, s2.id], confidence: 0.92)
            }
        }

        return nil
    }

    private static func detectThreeStrokeDivide(s1: Stroke, s2: Stroke, s3: Stroke) -> MultiStrokeCandidate? {
        let strokes = [s1, s2, s3]
        guard let barIdx = strokes.indices.max(by: { strokes[$0].bounds.width < strokes[$1].bounds.width }) else { return nil }
        let bar = strokes[barIdx]
        let barB = bar.bounds
        guard barB.width >= 14 && barB.width > barB.height * 1.7 else { return nil }

        let dots = strokes.indices.filter { $0 != barIdx }.map { strokes[$0] }
        guard dots.count == 2 else { return nil }

        let d1 = dots[0], d2 = dots[1]
        let bD1 = d1.bounds, bD2 = d2.bounds

        guard max(bD1.width, bD1.height) <= barB.width * 0.70 && max(bD2.width, bD2.height) <= barB.width * 0.70 else { return nil }

        let oneAbove = (bD1.midY < barB.minY && bD2.midY > barB.maxY) || (bD2.midY < barB.minY && bD1.midY > barB.maxY)
        guard oneAbove else { return nil }

        guard bD1.midX >= barB.minX - 12 && bD1.midX <= barB.maxX + 12 &&
              bD2.midX >= barB.minX - 12 && bD2.midX <= barB.maxX + 12 else { return nil }

        let unionB = barB.union(bD1).union(bD2)
        return MultiStrokeCandidate(shape: .mathDivide(unionB), strokeIds: strokes.map(\.id), confidence: 0.95)
    }

    private static func detectJoinedStrokesShape(strokes: [Stroke]) -> [MultiStrokeCandidate]? {
        guard strokes.count >= 2 else { return nil }
        var unionBounds = strokes[0].bounds
        for s in strokes.dropFirst() {
            unionBounds = unionBounds.union(s.bounds)
        }
        let maxDim = max(unionBounds.width, unionBounds.height)
        guard maxDim >= 20 else { return nil }

        let proximityThreshold = max(45.0, maxDim * 0.35)

        var chained: [CGPoint] = strokes[0].points.map(\.cgPoint)
        for s in strokes.dropFirst() {
            let pts = s.points.map(\.cgPoint)
            guard let last = chained.last, let f = pts.first, let l = pts.last else { return nil }
            let dStart = hypot(last.x - f.x, last.y - f.y)
            let dEnd = hypot(last.x - l.x, last.y - l.y)
            guard min(dStart, dEnd) <= proximityThreshold else { return nil }

            if dStart <= dEnd {
                chained.append(contentsOf: pts)
            } else {
                chained.append(contentsOf: pts.reversed())
            }
        }

        let detectedShapes = detectCandidates(from: chained, maxCandidates: 3)
        guard !detectedShapes.isEmpty else { return nil }

        var candidates: [MultiStrokeCandidate] = []
        let strokeIds = strokes.map(\.id)
        for sh in detectedShapes {
            switch sh {
            case .rect, .circle, .ellipse, .triangle, .capsule, .rhombus, .parallelogram, .pentagon, .hexagon:
                candidates.append(MultiStrokeCandidate(shape: sh, strokeIds: strokeIds, confidence: 0.88))
            default:
                break
            }
        }
        return candidates.isEmpty ? nil : candidates
    }
}
