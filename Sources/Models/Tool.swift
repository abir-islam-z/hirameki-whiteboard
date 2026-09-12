import Foundation
import AppKit

public enum Tool: String, CaseIterable, Identifiable, Codable {
    case none
    case select
    case hand
    case pen
    case highlighter
    case laser
    case eraser
    case text
    case note
    case rect
    case square
    case ellipse
    case circle
    case triangle
    case pentagon
    case hexagon
    case rhombus = "diamond"
    case parallelogram
    case cube
    case cylinder
    case twistedArrow = "twisted_arrow"
    case star
    case capsule
    case speechBubble = "speech_bubble"
    case arrow
    case doubleArrow = "double_arrow"
    case line
    case mathPlus = "math_plus"
    case mathMinus = "math_minus"
    case mathMultiply = "math_multiply"
    case mathDivide = "math_divide"
    case mathEquals = "math_equals"

    public static let diamond: Tool = .rhombus

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "Pointer"
        case .select: return "Select (V)"
        case .hand: return "Hand / Pan (H)"
        case .pen: return "Pen (P)"
        case .highlighter: return "Marker (M)"
        case .laser: return "Laser (D)"
        case .eraser: return "Eraser (E)"
        case .text: return "Text (T)"
        case .note: return "Sticky Note (N)"
        case .rect: return "Rectangle (R)"
        case .square: return "Square"
        case .ellipse, .circle: return "Circle (C)"
        case .triangle: return "Triangle (G)"
        case .pentagon: return "Pentagon"
        case .hexagon: return "Hexagon"
        case .rhombus: return "Diamond"
        case .parallelogram: return "Parallelogram"
        case .cube: return "3D Cube"
        case .cylinder: return "3D Cylinder"
        case .twistedArrow: return "Twisted Arrow"
        case .star: return "Star"
        case .capsule: return "Capsule"
        case .speechBubble: return "Speech Bubble"
        case .arrow: return "Arrow (A)"
        case .doubleArrow: return "Double Arrow"
        case .line: return "Line (L)"
        case .mathPlus: return "Plus (+)"
        case .mathMinus: return "Minus (−)"
        case .mathMultiply: return "Multiply (×)"
        case .mathDivide: return "Divide (÷)"
        case .mathEquals: return "Equals (=)"
        }
    }

    public var isShape: Bool {
        switch self {
        case .rect, .square, .ellipse, .circle, .triangle, .pentagon, .hexagon,
             .rhombus, .parallelogram, .cube, .cylinder, .twistedArrow, .star,
             .capsule, .speechBubble, .arrow, .doubleArrow, .line,
             .mathPlus, .mathMinus, .mathMultiply, .mathDivide, .mathEquals:
            return true
        default:
            return false
        }
    }
}
