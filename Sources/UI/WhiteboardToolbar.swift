import SwiftUI
import AppKit

// MARK: - Freeform Whiteboard Action Delegate
public protocol FreeformWhiteboardActionDelegate: AnyObject {
    func freeformDidSelectTool(_ tool: Tool)
    func freeformDidChangeColor(_ color: NSColor)
    func freeformDidChangeWidth(_ width: CGFloat)
    func freeformDidRequestNewBoard()
    func freeformDidRequestOpenBoard()
    func freeformDidRequestSaveBoard()
    func freeformDidRequestSaveBoardAs()
    func freeformDidRequestExportPDF()
    func freeformDidRequestInsertPDF()
    func freeformDidRequestInsertImage()
    func freeformDidRequestRename(to newTitle: String)
    func freeformDidRequestUndo()
    func freeformDidRequestRedo()
    func freeformDidRequestClear()
    func freeformDidChangeEraserType(_ type: EraserType)
    func freeformDidChangePattern(_ pattern: String)
    func freeformDidChangeOpacity(_ opacity: CGFloat)
    func freeformDidZoomIn()
    func freeformDidZoomOut()
    func freeformDidResetZoom()
    func freeformDidSetZoom(_ scale: CGFloat)
    func freeformDidZoomToFit()
    func freeformDidRequestReturnToGallery()
    func freeformDidRequestSwitchBoard(id: UUID)
}

public extension FreeformWhiteboardActionDelegate {
    func freeformDidRequestReturnToGallery() {}
    func freeformDidRequestSwitchBoard(id: UUID) {}
}

public enum EraserType: String, CaseIterable, Codable {
    case object
    case stroke
}

// MARK: - Freeform Whiteboard Observable State
public final class FreeformWhiteboardState: ObservableObject {
    @Published public var activeTool: Tool
    @Published public var activeColor: Color
    @Published public var activeWidth: CGFloat
    @Published public var penWidth: CGFloat
    @Published public var markerWidth: CGFloat
    @Published public var shapeWidth: CGFloat
    @Published public var laserWidth: CGFloat
    @Published public var documentTitle: String
    @Published public var zoomScale: CGFloat
    @Published public var eraserType: EraserType
    @Published public var pattern: String
    @Published public var boardOpacity: CGFloat
    @Published public var savedFeedback: Bool = false

    public init(
        activeTool: Tool = .select,
        activeColor: Color = .black,
        activeWidth: CGFloat = 4.0,
        penWidth: CGFloat = 4.0,
        markerWidth: CGFloat = 18.0,
        shapeWidth: CGFloat = 3.0,
        laserWidth: CGFloat = 6.0,
        documentTitle: String = "Untitled Board",
        zoomScale: CGFloat = 1.0,
        eraserType: EraserType = .object,
        pattern: String = "dots",
        boardOpacity: CGFloat = 1.0
    ) {
        self.activeTool = activeTool
        self.activeColor = activeColor
        self.activeWidth = activeWidth
        self.penWidth = penWidth
        self.markerWidth = markerWidth
        self.shapeWidth = shapeWidth
        self.laserWidth = laserWidth
        self.documentTitle = documentTitle
        self.zoomScale = zoomScale
        self.eraserType = eraserType
        self.pattern = pattern
        self.boardOpacity = boardOpacity
    }
}

// MARK: - Freeform Boards List Popover (Presented from < Boards back button)
public struct BoardsListPopoverView: View {
    @ObservedObject public var boardManager: BoardManager
    public let currentBoardTitle: String
    public var onSelectBoard: (UUID) -> Void
    public var onReturnToGallery: () -> Void
    public var onNewBoard: () -> Void

    @State private var search: String = ""
    @State private var hoveredBoardID: UUID?

    public init(
        boardManager: BoardManager,
        currentBoardTitle: String,
        onSelectBoard: @escaping (UUID) -> Void,
        onReturnToGallery: @escaping () -> Void,
        onNewBoard: @escaping () -> Void
    ) {
        self.boardManager = boardManager
        self.currentBoardTitle = currentBoardTitle
        self.onSelectBoard = onSelectBoard
        self.onReturnToGallery = onReturnToGallery
        self.onNewBoard = onNewBoard
    }

    private var filtered: [BoardItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return Array(boardManager.boards.prefix(12))
        }
        return boardManager.boards.filter { $0.title.lowercased().contains(q) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. Top Action: Return to Gallery
            Button(action: onReturnToGallery) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 1) {
                        Text("All Boards")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Browse, search and manage all boards")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.horizontal, 8)

            // 2. Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Search boards...", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !search.isEmpty {
                    Button {
                        search = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // 3. Section Header
            HStack {
                Text(search.isEmpty ? "RECENT BOARDS" : "SEARCH RESULTS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)

                Spacer()

                Button {
                    onNewBoard()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("New Board")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)

            // 4. Boards List
            ScrollView {
                LazyVStack(spacing: 2) {
                    if filtered.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("No boards found")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        ForEach(filtered) { item in
                            let isCurrent = (item.title == currentBoardTitle || item.id == boardManager.currentBoardID)
                            let isHovered = hoveredBoardID == item.id

                            Button {
                                onSelectBoard(item.id)
                            } label: {
                                HStack(spacing: 8) {
                                    // Mini thumbnail or icon
                                    boardMiniThumbnail(for: item)
                                        .frame(width: 36, height: 26)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
                                        )

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.title)
                                            .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        Text(formatDate(item.modifiedAt))
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if isCurrent {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    isHovered
                                        ? Color.accentColor.opacity(0.12)
                                        : (isCurrent ? Color.primary.opacity(0.04) : Color.clear)
                                )
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .onHover { h in
                                if h { hoveredBoardID = item.id }
                                else if hoveredBoardID == item.id { hoveredBoardID = nil }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
            }
            .frame(maxHeight: 250)

            Divider()
                .padding(.horizontal, 8)

            // 5. Bottom Quick Actions
            HStack {
                Button {
                    onNewBoard()
                } label: {
                    Label("New Board", systemImage: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    onReturnToGallery()
                } label: {
                    Text("View All (\(boardManager.boards.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private func boardMiniThumbnail(for item: BoardItem) -> some View {
        if let thumbURL = item.thumbnailURL, let img = NSImage(contentsOf: thumbURL) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(NSColor.controlBackgroundColor)
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let df = DateFormatter()
            df.timeStyle = .short
            return "Today, " + df.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let df = DateFormatter()
            df.dateStyle = .short
            return df.string(from: date)
        }
    }
}

// MARK: - 1. Top-Left: Freeform Navigation Pill (< Boards, Title, Board Switcher Menu)
public struct FreeformWhiteboardTitleView: View {
    @ObservedObject public var state: FreeformWhiteboardState
    public weak var delegate: FreeformWhiteboardActionDelegate?

    @State private var isEditingTitle: Bool = false
    @State private var tempTitle: String = ""
    @State private var backButtonAnchor: NSView?

    public init(state: FreeformWhiteboardState, delegate: FreeformWhiteboardActionDelegate?) {
        self.state = state
        self.delegate = delegate
    }

    public var body: some View {
        HStack(spacing: 3) {
            // Freeform Back Button: < Boards ▾
            HStack(spacing: 0) {
                // Clicking chevron returns directly to Gallery
                Button {
                    WhiteboardPopoverPresenter.shared.close()
                    delegate?.freeformDidRequestReturnToGallery()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(.leading, 6)
                        .padding(.trailing, 2)
                        .frame(height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to Boards Gallery (Auto-saves)")

                // Clicking "Boards ▾" opens the boards list popover via WhiteboardPopoverPresenter
                Button {
                    toggleBoardsPopover()
                } label: {
                    HStack(spacing: 3) {
                        Text("Boards")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.accentColor.opacity(0.8))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 6)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show list of boards")
            }
            .background(PopoverAnchorView { backButtonAnchor = $0 })

            // Capsule Divider
            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 2)

            // Document Title & Quick Actions Menu
            Menu {
                Button {
                    tempTitle = state.documentTitle
                    isEditingTitle = true
                } label: {
                    Label("Rename Board...", systemImage: "pencil")
                }

                Button {
                    delegate?.freeformDidRequestNewBoard()
                } label: {
                    Label("New Board", systemImage: "plus.square")
                }

                Button {
                    delegate?.freeformDidRequestOpenBoard()
                } label: {
                    Label("Open Board File...", systemImage: "folder")
                }

                Button {
                    delegate?.freeformDidRequestSaveBoard()
                } label: {
                    Label("Save Board", systemImage: "square.and.arrow.down")
                }

                Button {
                    delegate?.freeformDidRequestExportPDF()
                } label: {
                    Label("Export to PDF...", systemImage: "arrow.down.doc")
                }

                Divider()

                Button {
                    WhiteboardPopoverPresenter.shared.close()
                    delegate?.freeformDidRequestReturnToGallery()
                } label: {
                    Label("All Boards Gallery", systemImage: "square.grid.2x2")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(state.documentTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Board Actions (Rename, Export, New)")
            .popover(isPresented: $isEditingTitle, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Rename Whiteboard")
                        .font(.system(size: 12, weight: .bold))
                    TextField("Board Title", text: $tempTitle, onCommit: {
                        commitRename()
                    })
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)

                    HStack {
                        Spacer()
                        Button("Cancel") {
                            isEditingTitle = false
                        }
                        Button("Rename") {
                            commitRename()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(14)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 28)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private func toggleBoardsPopover() {
        if WhiteboardPopoverPresenter.shared.isShowing {
            WhiteboardPopoverPresenter.shared.close()
        } else if let anchor = backButtonAnchor {
            WhiteboardPopoverPresenter.shared.show(from: anchor, preferredEdge: .maxY) {
                BoardsListPopoverView(
                    boardManager: BoardManager.shared,
                    currentBoardTitle: state.documentTitle,
                    onSelectBoard: { id in
                        WhiteboardPopoverPresenter.shared.close()
                        delegate?.freeformDidRequestSwitchBoard(id: id)
                    },
                    onReturnToGallery: {
                        WhiteboardPopoverPresenter.shared.close()
                        delegate?.freeformDidRequestReturnToGallery()
                    },
                    onNewBoard: {
                        WhiteboardPopoverPresenter.shared.close()
                        delegate?.freeformDidRequestNewBoard()
                    }
                )
            }
        }
    }

    private func commitRename() {
        isEditingTitle = false
        let trimmed = tempTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            state.documentTitle = trimmed
            delegate?.freeformDidRequestRename(to: trimmed)
        }
    }
}

// MARK: - Native Popover Presenter for NSToolbar Views
public final class WhiteboardPopoverPresenter: NSObject, NSPopoverDelegate {
    public static let shared = WhiteboardPopoverPresenter()
    private var currentPopover: NSPopover?

    public var isShowing: Bool {
        currentPopover?.isShown == true
    }

    public func show<Content: View>(
        from anchor: NSView,
        preferredEdge: NSRectEdge = .maxY,
        @ViewBuilder content: () -> Content
    ) {
        currentPopover?.close()
        let popover = NSPopover()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: content())
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: preferredEdge)
        self.currentPopover = popover
    }

    public func close() {
        currentPopover?.close()
        currentPopover = nil
    }

    public func popoverDidClose(_ notification: Notification) {
        currentPopover = nil
    }
}

public struct PopoverAnchorView: NSViewRepresentable {
    let onView: (NSView) -> Void
    public init(onView: @escaping (NSView) -> Void) {
        self.onView = onView
    }
    public func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        DispatchQueue.main.async { onView(v) }
        return v
    }
    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onView(nsView) }
    }
}

// MARK: - 2. Top-Center: Freeform Tools Capsule (Cursor, Hand, Sticky Note, Shapes, Text, Pen, Marker, Laser, Eraser, Color, Clear)
public struct FreeformWhiteboardToolsCapsule: View {
    @ObservedObject public var state: FreeformWhiteboardState
    public weak var delegate: FreeformWhiteboardActionDelegate?

    @State private var shapesAnchor: NSView?
    @State private var penAnchor: NSView?
    @State private var markerAnchor: NSView?
    @State private var eraserAnchor: NSView?
    @State private var colorAnchor: NSView?

    public init(state: FreeformWhiteboardState, delegate: FreeformWhiteboardActionDelegate?) {
        self.state = state
        self.delegate = delegate
    }

    public var body: some View {
        HStack(spacing: 3) {
            // 1. Pointer / Selection Cursor Tool (V)
            capsuleToolButton(
                icon: "cursorarrow",
                isSelected: state.activeTool == .select,
                tooltip: "Selection / Pointer (V)"
            ) {
                WhiteboardPopoverPresenter.shared.close()
                state.activeTool = .select
                delegate?.freeformDidSelectTool(.select)
            }

            // 2. Move / Hand / Pan Tool (H)
            capsuleToolButton(
                icon: "hand.raised",
                isSelected: state.activeTool == .hand,
                tooltip: "Move / Pan Canvas (H) • Hold Spacebar"
            ) {
                WhiteboardPopoverPresenter.shared.close()
                state.activeTool = .hand
                delegate?.freeformDidSelectTool(.hand)
            }

            // 3. Sticky Note Tool (N)
            capsuleToolButton(
                icon: "note.text",
                isSelected: state.activeTool == .note,
                tooltip: "Sticky Note (N) — Click to place"
            ) {
                WhiteboardPopoverPresenter.shared.close()
                state.activeTool = .note
                delegate?.freeformDidSelectTool(.note)
            }

            // 4. Vector Shapes Dropdown Menu
            Button {
                if WhiteboardPopoverPresenter.shared.isShowing {
                    WhiteboardPopoverPresenter.shared.close()
                } else if let anchor = shapesAnchor {
                    WhiteboardPopoverPresenter.shared.show(from: anchor) {
                        FreeformShapesGridPopover(
                            activeTool: $state.activeTool,
                            onSelectShape: { shapeTool in
                                state.activeTool = shapeTool
                                state.activeWidth = state.shapeWidth
                                delegate?.freeformDidSelectTool(shapeTool)
                                delegate?.freeformDidChangeWidth(state.shapeWidth)
                                WhiteboardPopoverPresenter.shared.close()
                            }
                        )
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: state.activeTool.isShape ? shapeIcon(for: state.activeTool) : "square.on.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(state.activeTool.isShape ? .accentColor : .primary.opacity(0.85))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 36, height: 28)
                .background(state.activeTool.isShape ? Color.accentColor.opacity(0.18) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    state.activeTool.isShape ? Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1) : nil
                )
            }
            .buttonStyle(.plain)
            .background(PopoverAnchorView { shapesAnchor = $0 })
            .help("Shapes (R, C, A, L)")

            // 5. Text Tool (T)
            capsuleToolButton(
                icon: "character.textbox",
                isSelected: state.activeTool == .text,
                tooltip: "Text Box (T) — Click to write"
            ) {
                WhiteboardPopoverPresenter.shared.close()
                state.activeTool = .text
                delegate?.freeformDidSelectTool(.text)
            }

            // 6. Pen Tool (P)
            Button {
                if state.activeTool != .pen {
                    WhiteboardPopoverPresenter.shared.close()
                    state.activeTool = .pen
                    state.activeWidth = state.penWidth
                    delegate?.freeformDidSelectTool(.pen)
                    delegate?.freeformDidChangeWidth(state.penWidth)
                } else if let anchor = penAnchor {
                    if WhiteboardPopoverPresenter.shared.isShowing {
                        WhiteboardPopoverPresenter.shared.close()
                    } else {
                        WhiteboardPopoverPresenter.shared.show(from: anchor) {
                            ToolThicknessPopover(
                                title: "Pen Thickness",
                                activeWidth: $state.penWidth,
                                options: [
                                    (name: "Fine", value: 2.0),
                                    (name: "Regular", value: 4.0),
                                    (name: "Medium", value: 7.0),
                                    (name: "Bold", value: 12.0)
                                ],
                                onWidthPicked: { w in
                                    state.penWidth = w
                                    state.activeWidth = w
                                    delegate?.freeformDidChangeWidth(w)
                                    WhiteboardPopoverPresenter.shared.close()
                                }
                            )
                        }
                    }
                }
            } label: {
                Image(systemName: "pencil.tip")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(state.activeTool == .pen ? .accentColor : .primary.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(state.activeTool == .pen ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        state.activeTool == .pen ? Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 1) : nil
                    )
            }
            .buttonStyle(.plain)
            .background(PopoverAnchorView { penAnchor = $0 })
            .help("Pen (P) — Thickness: \(Int(state.penWidth))px • Click to draw or change thickness")

            // 7. Marker / Highlighter Tool (M)
            Button {
                if state.activeTool != .highlighter {
                    WhiteboardPopoverPresenter.shared.close()
                    state.activeTool = .highlighter
                    state.activeWidth = state.markerWidth
                    delegate?.freeformDidSelectTool(.highlighter)
                    delegate?.freeformDidChangeWidth(state.markerWidth)
                } else if let anchor = markerAnchor {
                    if WhiteboardPopoverPresenter.shared.isShowing {
                        WhiteboardPopoverPresenter.shared.close()
                    } else {
                        WhiteboardPopoverPresenter.shared.show(from: anchor) {
                            ToolThicknessPopover(
                                title: "Highlighter Width",
                                activeWidth: $state.markerWidth,
                                options: [
                                    (name: "Thin", value: 12.0),
                                    (name: "Regular", value: 18.0),
                                    (name: "Broad", value: 28.0),
                                    (name: "Chisel", value: 38.0)
                                ],
                                onWidthPicked: { w in
                                    state.markerWidth = w
                                    state.activeWidth = w
                                    delegate?.freeformDidChangeWidth(w)
                                    WhiteboardPopoverPresenter.shared.close()
                                }
                            )
                        }
                    }
                }
            } label: {
                Image(systemName: "highlighter")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(state.activeTool == .highlighter ? .accentColor : .primary.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(state.activeTool == .highlighter ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        state.activeTool == .highlighter ? Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 1) : nil
                    )
            }
            .buttonStyle(.plain)
            .background(PopoverAnchorView { markerAnchor = $0 })
            .help("Marker / Highlighter (M) — Width: \(Int(state.markerWidth))px • Click to draw or change width")

            // 8. Laser Pointer Tool (D)
            capsuleToolButton(
                icon: "rays",
                isSelected: state.activeTool == .laser,
                tooltip: "Laser Pointer / Vanishing Ink (D)"
            ) {
                WhiteboardPopoverPresenter.shared.close()
                state.activeTool = .laser
                delegate?.freeformDidSelectTool(.laser)
            }

            // 9. Eraser Tool with Options Popover (E)
            Button {
                if state.activeTool != .eraser {
                    WhiteboardPopoverPresenter.shared.close()
                    state.activeTool = .eraser
                    delegate?.freeformDidSelectTool(.eraser)
                } else if let anchor = eraserAnchor {
                    if WhiteboardPopoverPresenter.shared.isShowing {
                        WhiteboardPopoverPresenter.shared.close()
                    } else {
                        WhiteboardPopoverPresenter.shared.show(from: anchor) {
                            EraserOptionsPopover(
                                eraserType: $state.eraserType,
                                onTypePicked: { type in
                                    state.eraserType = type
                                    delegate?.freeformDidChangeEraserType(type)
                                    WhiteboardPopoverPresenter.shared.close()
                                },
                                onClearBoard: {
                                    WhiteboardPopoverPresenter.shared.close()
                                    delegate?.freeformDidRequestClear()
                                }
                            )
                        }
                    }
                }
            } label: {
                Image(systemName: state.eraserType == .object ? "eraser.fill" : "circle.dotted")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(state.activeTool == .eraser ? .accentColor : .primary.opacity(0.85))
                    .frame(width: 28, height: 28)
                    .background(state.activeTool == .eraser ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(Circle())
                    .overlay(
                        state.activeTool == .eraser ? Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 1) : nil
                    )
            }
            .buttonStyle(.plain)
            .background(PopoverAnchorView { eraserAnchor = $0 })
            .help("Eraser (E) — Click again for Object vs Pixel Eraser")

            // Capsule Divider
            capsuleDivider

            // 10. Color Picker with Full Palette Popover
            Button {
                if WhiteboardPopoverPresenter.shared.isShowing {
                    WhiteboardPopoverPresenter.shared.close()
                } else if let anchor = colorAnchor {
                    WhiteboardPopoverPresenter.shared.show(from: anchor) {
                        MarkupColorPickerPopover(
                            selectedColor: $state.activeColor,
                            onColorPicked: { newColor in
                                state.activeColor = newColor
                                delegate?.freeformDidChangeColor(NSColor(newColor))
                                WhiteboardPopoverPresenter.shared.close()
                            },
                            onOpenFullPanel: {
                                WhiteboardPopoverPresenter.shared.close()
                                NSColorPanel.shared.orderFront(nil)
                            }
                        )
                    }
                }
            } label: {
                Circle()
                    .fill(state.activeColor)
                    .frame(width: 17, height: 17)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                    )
                    .frame(width: 28, height: 28)
                    .background(Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .background(PopoverAnchorView { colorAnchor = $0 })
            .help("Color Palette & Eyedropper")

            // Capsule Divider
            capsuleDivider

            // 11. All-Clear Circled Cross Button
            Button {
                WhiteboardPopoverPresenter.shared.close()
                delegate?.freeformDidRequestClear()
            } label: {
                CircledCrossIconView(size: 18)
                    .frame(width: 28, height: 28)
                    .background(Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Clear Board (⌘K)")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
    }

    @ViewBuilder
    private var capsuleDivider: some View {
        RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func capsuleToolButton(
        icon: String,
        isSelected: Bool,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.85))
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                .clipShape(Circle())
                .overlay(
                    isSelected ? Circle().stroke(Color.accentColor.opacity(0.35), lineWidth: 1) : nil
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    private func shapeIcon(for tool: Tool) -> String {
        switch tool {
        case .rect: return "rectangle"
        case .square: return "square"
        case .circle, .ellipse: return "circle"
        case .triangle: return "triangle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.up.right"
        case .rhombus: return "rhombus"
        case .star: return "star"
        default: return "square.on.circle"
        }
    }
}

// MARK: - 3. Top-Right: Pattern, Opacity & Insert PDF Bar
public struct FreeformWhiteboardPatternView: View {
    @ObservedObject public var state: FreeformWhiteboardState
    public weak var delegate: FreeformWhiteboardActionDelegate?

    public init(state: FreeformWhiteboardState, delegate: FreeformWhiteboardActionDelegate?) {
        self.state = state
        self.delegate = delegate
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Pattern Dropdown
            Menu {
                Button("Solid Slate / White") {
                    state.pattern = "solid"
                    delegate?.freeformDidChangePattern("solid")
                }
                Button("Dot Grid") {
                    state.pattern = "dots"
                    delegate?.freeformDidChangePattern("dots")
                }
                Button("Graph Grid") {
                    state.pattern = "grid"
                    delegate?.freeformDidChangePattern("grid")
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: patternIcon(state.pattern))
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .frame(height: 26)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Background Pattern: Solid, Dots, Grid")

            // Opacity Dropdown
            Menu {
                Button("100% Solid") {
                    state.boardOpacity = 1.0
                    delegate?.freeformDidChangeOpacity(1.0)
                }
                Button("90% Frosted Glass") {
                    state.boardOpacity = 0.90
                    delegate?.freeformDidChangeOpacity(0.90)
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: state.boardOpacity < 0.95 ? "circle.dashed" : "circle.fill")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .frame(height: 26)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Board Opacity (Solid vs Frosted)")

            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 1)

            // Insert Image Button
            Button {
                delegate?.freeformDidRequestInsertImage()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("Image")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.9))
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
            }
            .buttonStyle(.plain)
            .help("Insert & Annotate Image Attachment (⌘U)")

            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 16)
                .padding(.horizontal, 1)

            // Insert PDF Button
            Button {
                delegate?.freeformDidRequestInsertPDF()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                    Text("PDF")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.9))
                }
                .padding(.horizontal, 7)
                .frame(height: 26)
            }
            .buttonStyle(.plain)
            .help("Insert & Annotate PDF Document (⌘I)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private func patternIcon(_ pat: String) -> String {
        switch pat {
        case "dots": return "circle.grid.2x2.fill"
        case "grid": return "square.grid.3x3.fill"
        default: return "square.fill"
        }
    }
}

// MARK: - 4. Bottom-Left: Zoom & Undo/Redo Glass Capsule
public struct FreeformWhiteboardBottomLeftBar: View {
    @ObservedObject public var state: FreeformWhiteboardState
    public weak var delegate: FreeformWhiteboardActionDelegate?

    public init(state: FreeformWhiteboardState, delegate: FreeformWhiteboardActionDelegate?) {
        self.state = state
        self.delegate = delegate
    }

    public var body: some View {
        HStack(spacing: 5) {
            // Zoom Out
            Button {
                delegate?.freeformDidZoomOut()
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 20, height: 22)
            }
            .buttonStyle(.plain)
            .help("Zoom Out (⌘-)")

            // Zoom Percentage Menu & Reset
            Menu {
                Button("Zoom to 25%") { delegate?.freeformDidSetZoom(0.25) }
                Button("Zoom to 50%") { delegate?.freeformDidSetZoom(0.50) }
                Button("Zoom to 75%") { delegate?.freeformDidSetZoom(0.75) }
                Button("Zoom to 100% (⌘0)") { delegate?.freeformDidResetZoom() }
                Button("Zoom to 125%") { delegate?.freeformDidSetZoom(1.25) }
                Button("Zoom to 150%") { delegate?.freeformDidSetZoom(1.50) }
                Button("Zoom to 200%") { delegate?.freeformDidSetZoom(2.00) }
                Button("Zoom to 400%") { delegate?.freeformDidSetZoom(4.00) }
                Divider()
                Button("Zoom to Fit") { delegate?.freeformDidZoomToFit() }
            } label: {
                Text("\(Int(round(state.zoomScale * 100)))%")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.85))
                    .frame(minWidth: 40)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Zoom Presets (⌘0)")

            // Zoom In
            Button {
                delegate?.freeformDidZoomIn()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 20, height: 22)
            }
            .buttonStyle(.plain)
            .help("Zoom In (⌘+)")

            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 2)

            // Undo
            Button {
                delegate?.freeformDidRequestUndo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help("Undo (⌘Z)")

            // Redo
            Button {
                delegate?.freeformDidRequestRedo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help("Redo (⇧⌘Z)")

            RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.primary.opacity(0.15))
                .frame(width: 1, height: 14)
                .padding(.horizontal, 2)

            // Fit to View / Zoom to Content
            Button {
                delegate?.freeformDidZoomToFit()
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.85))
                    .frame(width: 24, height: 22)
            }
            .buttonStyle(.plain)
            .help("Zoom to Fit")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
    }
}

// MARK: - Hand-Drawn Circled Cross Icon View
public struct CircledCrossIconView: View {
    public var size: CGFloat
    public var color: Color

    public init(size: CGFloat = 18, color: Color = Color(red: 0.98, green: 0.08, blue: 0.08)) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let radius = min(w, h) / 2 - 1.5

            // Outer hand-drawn ring
            var ringPath = Path()
            ringPath.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-48),
                endAngle: .degrees(295),
                clockwise: false
            )
            ctx.stroke(
                ringPath,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1.2, size * 0.09), lineCap: .round, lineJoin: .round)
            )

            // Inner cross stroke 1 (\)
            let crossSpan = radius * 0.58
            var xPath1 = Path()
            xPath1.move(to: CGPoint(x: center.x - crossSpan * 0.9, y: center.y - crossSpan * 0.85))
            xPath1.addQuadCurve(
                to: CGPoint(x: center.x + crossSpan * 0.85, y: center.y + crossSpan * 0.9),
                control: CGPoint(x: center.x, y: center.y + 0.5)
            )
            ctx.stroke(
                xPath1,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1.4, size * 0.11), lineCap: .round)
            )

            // Inner cross stroke 2 (/)
            var xPath2 = Path()
            xPath2.move(to: CGPoint(x: center.x + crossSpan * 0.85, y: center.y - crossSpan * 0.85))
            xPath2.addQuadCurve(
                to: CGPoint(x: center.x - crossSpan * 0.9, y: center.y + crossSpan * 0.9),
                control: CGPoint(x: center.x - 0.5, y: center.y)
            )
            ctx.stroke(
                xPath2,
                with: .color(color),
                style: StrokeStyle(lineWidth: max(1.4, size * 0.11), lineCap: .round)
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Tool Thickness Popover
public struct ToolThicknessPopover: View {
    public let title: String
    @Binding public var activeWidth: CGFloat
    public let options: [(name: String, value: CGFloat)]
    public let onWidthPicked: (CGFloat) -> Void

    public init(
        title: String,
        activeWidth: Binding<CGFloat>,
        options: [(name: String, value: CGFloat)],
        onWidthPicked: @escaping (CGFloat) -> Void
    ) {
        self.title = title
        self._activeWidth = activeWidth
        self.options = options
        self.onWidthPicked = onWidthPicked
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                ForEach(options, id: \.value) { opt in
                    let isSelected = abs(activeWidth - opt.value) < 0.5
                    Button {
                        activeWidth = opt.value
                        onWidthPicked(opt.value)
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(isSelected ? Color.accentColor : Color.primary)
                                .frame(width: max(4, min(24, opt.value)), height: max(4, min(24, opt.value)))
                                .frame(width: 28, height: 28)

                            Text(opt.name)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.85))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 6)
                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            isSelected ?
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1) : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Eraser Options Popover
public struct EraserOptionsPopover: View {
    @Binding var eraserType: EraserType
    var onTypePicked: (EraserType) -> Void
    var onClearBoard: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eraser Options")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 3) {
                // Object Eraser
                Button {
                    onTypePicked(.object)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "eraser.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(eraserType == .object ? .accentColor : .primary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Object Eraser")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Deletes whole shapes on touch")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if eraserType == .object {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(eraserType == .object ? Color.accentColor.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                // Pixel / Stroke Eraser
                Button {
                    onTypePicked(.stroke)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.dotted")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(eraserType == .stroke ? .accentColor : .primary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Pixel / Stroke Eraser")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Erases precise path segments")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if eraserType == .stroke {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(eraserType == .stroke ? Color.accentColor.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Clear Whiteboard Action
            Button(action: onClearBoard) {
                HStack(spacing: 10) {
                    CircledCrossIconView(size: 16)
                        .frame(width: 22)

                    Text("Clear Whiteboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 250)
    }
}

// MARK: - Freeform Shapes Grid Popover
public struct FreeformShapesGridPopover: View {
    @Binding var activeTool: Tool
    var onSelectShape: (Tool) -> Void

    public var body: some View {
        VStack(spacing: 8) {
            Text("VECTOR SHAPES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.fixed(36)), GridItem(.fixed(36)), GridItem(.fixed(36)), GridItem(.fixed(36))], spacing: 6) {
                shapeButton(.rect, icon: "rectangle", label: "Rectangle (R)")
                shapeButton(.square, icon: "square", label: "Square")
                shapeButton(.circle, icon: "circle", label: "Circle (C)")
                shapeButton(.triangle, icon: "triangle", label: "Triangle (G)")
                shapeButton(.line, icon: "line.diagonal", label: "Line (L)")
                shapeButton(.arrow, icon: "arrow.up.right", label: "Arrow (A)")
                shapeButton(.rhombus, icon: "rhombus", label: "Diamond")
                shapeButton(.star, icon: "star", label: "Star")
            }
        }
        .padding(10)
    }

    private func shapeButton(_ tool: Tool, icon: String, label: String) -> some View {
        Button {
            onSelectShape(tool)
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
}

// MARK: - Color Picker Popover with Eyedropper & macOS Color Panel
public struct MarkupColorPickerPopover: View {
    @Binding public var selectedColor: Color
    public var onColorPicked: ((Color) -> Void)?
    public var onOpenFullPanel: (() -> Void)?

    private let standardColors: [Color] = [
        .black, Color(white: 0.35), Color(white: 0.7), .white,
        .red, .orange, .yellow, .green,
        .mint, .teal, .cyan, .blue,
        .indigo, .purple, .pink, .brown
    ]

    private let neonColors: [Color] = [
        Color(red: 0.05, green: 1.0, blue: 0.4),  // Lime
        Color(red: 1.0, green: 0.15, blue: 0.55), // Hot Pink
        Color(red: 1.0, green: 0.95, blue: 0.05), // Electric Yellow
        Color(red: 0.0, green: 0.95, blue: 1.0),  // Cyan
        Color(red: 1.0, green: 0.45, blue: 0.0),  // Vivid Orange
        Color(red: 0.75, green: 0.15, blue: 1.0), // Electric Purple
        Color(red: 0.0, green: 1.0, blue: 0.7),   // Mint
        Color(red: 1.0, green: 0.35, blue: 0.88)  // Bubblegum
    ]

    public init(
        selectedColor: Binding<Color>,
        onColorPicked: ((Color) -> Void)? = nil,
        onOpenFullPanel: (() -> Void)? = nil
    ) {
        self._selectedColor = selectedColor
        self.onColorPicked = onColorPicked
        self.onOpenFullPanel = onOpenFullPanel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Palette")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 6), count: 8), spacing: 6) {
                ForEach(standardColors, id: \.self) { col in
                    colorSwatch(col)
                }
            }

            Text("Vibrant")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(22), spacing: 6), count: 8), spacing: 6) {
                ForEach(neonColors, id: \.self) { col in
                    colorSwatch(col)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    NSColorSampler().show { selectedNSColor in
                        if let ns = selectedNSColor {
                            let c = Color(ns)
                            selectedColor = c
                            onColorPicked?(c)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eyedropper")
                            .font(.system(size: 11))
                        Text("Eyedropper")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Pick Color from Screen")

                Button {
                    NSColorPanel.shared.makeKeyAndOrderFront(nil)
                    onOpenFullPanel?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "paintpalette")
                            .font(.system(size: 11))
                        Text("Show Colors...")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Open Full macOS Color Panel")
            }
        }
        .padding(12)
        .frame(width: 240)
    }

    private func colorSwatch(_ col: Color) -> some View {
        Button {
            selectedColor = col
            onColorPicked?(col)
        } label: {
            Circle()
                .fill(col)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .stroke(selectedColor == col ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: selectedColor == col ? 2.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}
