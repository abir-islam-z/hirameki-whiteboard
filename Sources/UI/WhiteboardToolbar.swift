import SwiftUI
import AppKit

public struct WhiteboardToolbar: View {
    @Binding var activeTool: Tool
    @Binding var activeColor: Color
    @Binding var activeWidth: CGFloat
    var onInsertPDF: () -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void
    var onClearAll: () -> Void
    var onExportPDF: () -> Void

    @State private var showPenPopover: Bool = false
    @State private var showShapesPopover: Bool = false
    @State private var showColorsPopover: Bool = false

    private let presetColors: [Color] = [
        .black,
        Color(red: 0.95, green: 0.25, blue: 0.25), // Red
        Color(red: 0.15, green: 0.55, blue: 0.95), // Blue
        Color(red: 0.20, green: 0.75, blue: 0.40), // Green
        Color(red: 0.95, green: 0.65, blue: 0.15), // Orange
        Color(red: 0.65, green: 0.35, blue: 0.85), // Purple
        Color(red: 0.95, green: 0.85, blue: 0.20)  // Yellow
    ]

    public var body: some View {
        HStack(spacing: 6) {
            // 1. Select Tool (V)
            toolButton(tool: .select, icon: "arrow.up.left", tooltip: "Select & Transform (V)")

            // 2. Hand / Pan Tool (H)
            toolButton(tool: .hand, icon: "hand.raised", tooltip: "Hand / Pan Canvas (H) • Hold Spacebar")

            Divider().frame(height: 20).opacity(0.3)

            // 3. Pen Tool (P)
            Button {
                if activeTool == .pen {
                    showPenPopover.toggle()
                } else {
                    activeTool = .pen
                }
            } label: {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(activeTool == .pen ? .accentColor : .primary)
                    .frame(width: 32, height: 32)
                    .background(activeTool == .pen ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        activeTool == .pen ? Circle().stroke(Color.accentColor.opacity(0.3), lineWidth: 1) : nil
                    )
            }
            .buttonStyle(.plain)
            .help("Pen Tool (P)")
            .popover(isPresented: $showPenPopover, arrowEdge: .bottom) {
                strokeThicknessPopover
            }

            // 4. Marker / Highlighter Tool (M)
            toolButton(tool: .highlighter, icon: "highlighter", tooltip: "Marker / Highlighter (M)")

            // 5. Laser Pointer (D)
            toolButton(tool: .laser, icon: "rays", tooltip: "Laser Pointer (D)")

            // 6. Eraser (E)
            toolButton(tool: .eraser, icon: "eraser.fill", tooltip: "Eraser (E)")

            Divider().frame(height: 20).opacity(0.3)

            // 7. Shapes Dropdown
            Button {
                showShapesPopover.toggle()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: activeTool.isShape ? shapeIcon(for: activeTool) : "square.on.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(activeTool.isShape ? .accentColor : .primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(height: 32)
                .padding(.horizontal, 6)
                .background(activeTool.isShape ? Color.accentColor.opacity(0.18) : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Vector Shapes (R, C, A, L)")
            .popover(isPresented: $showShapesPopover, arrowEdge: .bottom) {
                shapesGridPopover
            }

            // 8. Text Tool (T)
            toolButton(tool: .text, icon: "character.textbox", tooltip: "Text Box (T)")

            // 9. Sticky Note Tool (N)
            toolButton(tool: .note, icon: "note.text", tooltip: "Sticky Note (N)")

            Divider().frame(height: 20).opacity(0.3)

            // 10. Insert PDF Button (⌘I)
            Button {
                onInsertPDF()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.red)
                    Text("Insert PDF")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Insert & Annotate PDF (⌘I)")

            // 11. Active Color Picker
            Button {
                showColorsPopover.toggle()
            } label: {
                Circle()
                    .fill(activeColor)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1.5))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Pick Stroke Color")
            .popover(isPresented: $showColorsPopover, arrowEdge: .bottom) {
                colorPalettePopover
            }

            Divider().frame(height: 20).opacity(0.3)

            // 12. Undo / Redo
            HStack(spacing: 2) {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Undo (⌘Z)")

                Button(action: onRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .help("Redo (⇧⌘Z)")
            }

            // 13. Export PDF
            Button(action: onExportPDF) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Export Annotated PDF (⌘E)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
        )
    }

    private func toolButton(tool: Tool, icon: String, tooltip: String) -> some View {
        Button {
            activeTool = tool
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(activeTool == tool ? .accentColor : .primary)
                .frame(width: 32, height: 32)
                .background(activeTool == tool ? Color.accentColor.opacity(0.18) : Color.clear)
                .clipShape(Circle())
                .overlay(
                    activeTool == tool ? Circle().stroke(Color.accentColor.opacity(0.3), lineWidth: 1) : nil
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func shapeIcon(for tool: Tool) -> String {
        switch tool {
        case .rect: return "rectangle"
        case .square: return "square"
        case .circle: return "circle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .diamond: return "rhombus"
        case .star: return "star"
        default: return "square.on.circle"
        }
    }

    // MARK: - Shapes Grid Popover
    private var shapesGridPopover: some View {
        VStack(spacing: 8) {
            Text("SHAPES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.fixed(36)), GridItem(.fixed(36)), GridItem(.fixed(36)), GridItem(.fixed(36))], spacing: 6) {
                shapeGridItem(.rect, icon: "rectangle", label: "Rectangle (R)")
                shapeGridItem(.square, icon: "square", label: "Square")
                shapeGridItem(.circle, icon: "circle", label: "Circle (C)")
                shapeGridItem(.triangle, icon: "triangle", label: "Triangle (G)")
                shapeGridItem(.line, icon: "line.diagonal", label: "Line (L)")
                shapeGridItem(.arrow, icon: "arrow.up.right", label: "Arrow (A)")
                shapeGridItem(.diamond, icon: "rhombus", label: "Diamond")
                shapeGridItem(.star, icon: "star", label: "Star")
            }
        }
        .padding(10)
    }

    private func shapeGridItem(_ tool: Tool, icon: String, label: String) -> some View {
        Button {
            activeTool = tool
            showShapesPopover = false
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(activeTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
    }

    // MARK: - Thickness Popover
    private var strokeThicknessPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STROKE THICKNESS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach([2.0, 4.0, 8.0, 14.0], id: \.self) { w in
                    Button {
                        activeWidth = CGFloat(w)
                        showPenPopover = false
                    } label: {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: CGFloat(w * 1.5) + 4, height: CGFloat(w * 1.5) + 4)
                            .frame(width: 32, height: 32)
                            .background(activeWidth == CGFloat(w) ? Color.accentColor.opacity(0.18) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Color Palette Popover
    private var colorPalettePopover: some View {
        VStack(spacing: 8) {
            Text("PALETTE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                ForEach(presetColors, id: \.self) { c in
                    Button {
                        activeColor = c
                        showColorsPopover = false
                    } label: {
                        Circle()
                            .fill(c)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
    }
}
