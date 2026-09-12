import SwiftUI
import AppKit

// MARK: - Freeform Boards Gallery / Browser View
public struct BoardsGalleryView: View {
    @ObservedObject public var boardManager = BoardManager.shared
    public var onOpenBoard: (BoardItem) -> Void
    public var onNewBoard: () -> Void

    @State private var isSidebarVisible: Bool = true
    @State private var viewMode: GalleryViewMode = .grid
    @State private var renamingBoardID: UUID?
    @State private var renameText: String = ""
    @State private var hoveredBoardID: UUID?

    public enum GalleryViewMode {
        case grid
        case list
    }

    public init(
        onOpenBoard: @escaping (BoardItem) -> Void,
        onNewBoard: @escaping () -> Void
    ) {
        self.onOpenBoard = onOpenBoard
        self.onNewBoard = onNewBoard
    }

    public var body: some View {
        HStack(spacing: 0) {
            // 1. Freeform Collapsible Sidebar
            if isSidebarVisible {
                gallerySidebar
                    .frame(width: 220)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                
                Divider()
            }

            // 2. Main Gallery Content Area
            VStack(spacing: 0) {
                galleryTopToolbar
                
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Category Title Header
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(boardManager.selectedCategory.rawValue)
                                    .font(.system(size: 26, weight: .bold, design: .default))
                                    .foregroundColor(.primary)

                                let count = boardManager.filteredBoards.count
                                Text("\(count) \(count == 1 ? "board" : "boards")")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            // View Mode Toggle (Grid / List)
                            Picker("View Mode", selection: $viewMode) {
                                Image(systemName: "square.grid.2x2")
                                    .tag(GalleryViewMode.grid)
                                Image(systemName: "list.bullet")
                                    .tag(GalleryViewMode.list)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 80)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 24)

                        // Content Grid or List
                        if boardManager.filteredBoards.isEmpty {
                            emptyStateView
                                .frame(maxWidth: .infinity, minHeight: 360)
                        } else if viewMode == .grid {
                            boardsGridView
                                .padding(.horizontal, 28)
                                .padding(.bottom, 40)
                        } else {
                            boardsListView
                                .padding(.horizontal, 28)
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .sheet(item: Binding(
            get: { renamingBoardID.map { IdentifiableUUID(id: $0) } },
            set: { renamingBoardID = $0?.id }
        )) { item in
            renameSheet(for: item.id)
        }
    }

    // MARK: - Sidebar Component
    private var gallerySidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sidebar Header / App Branding
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.accentColor)
                Text("Hirameki")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)

            // Categories List
            VStack(spacing: 2) {
                ForEach(BoardCategory.allCases) { cat in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            boardManager.selectedCategory = cat
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 20)
                                .foregroundColor(boardManager.selectedCategory == cat ? .white : .accentColor)

                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(boardManager.selectedCategory == cat ? .white : .primary)

                            Spacer()

                            let count = boardManager.count(for: cat)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(boardManager.selectedCategory == cat ? .white.opacity(0.85) : .secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(boardManager.selectedCategory == cat ? Color.white.opacity(0.2) : Color.primary.opacity(0.06))
                                    )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(boardManager.selectedCategory == cat ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            // New Board Button in Sidebar Bottom
            Button {
                onNewBoard()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("New Board")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.65))
    }

    // MARK: - Gallery Top Toolbar
    private var galleryTopToolbar: some View {
        HStack(spacing: 12) {
            // Sidebar Toggle Button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Toggle Sidebar")

            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("Search boards", text: $boardManager.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !boardManager.searchQuery.isEmpty {
                    Button {
                        boardManager.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .frame(width: 240)

            Spacer()

            // New Board Button (Freeform `square.and.pencil`)
            Button {
                onNewBoard()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New Board")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .help("Create New Whiteboard (⌘N)")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Board Grid View (Authentic Freeform Cards)
    private var boardsGridView: some View {
        let columns = [
            GridItem(.adaptive(minimum: 230, maximum: 300), spacing: 24)
        ]

        return LazyVGrid(columns: columns, spacing: 24) {
            ForEach(boardManager.filteredBoards) { item in
                boardCard(for: item)
            }
        }
    }

    // MARK: - Board Card Component
    private func boardCard(for item: BoardItem) -> some View {
        let isHovered = hoveredBoardID == item.id

        return Button {
            onOpenBoard(item)
        } label: {
            VStack(spacing: 0) {
                // Top Canvas Thumbnail Preview
                ZStack {
                    Color.white

                    // Dot Grid Pattern preview background
                    dotPatternBackground

                    if let thumbURL = item.thumbnailURL,
                       let nsImg = NSImage(contentsOf: thumbURL) {
                        Image(nsImage: nsImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "applepencil.and.scribble")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Empty Board")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
                .frame(height: 155)
                .clipped()

                Divider()

                // Bottom Metadata Strip
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(formattedDate(item.modifiedAt))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Favorite Button
                    Button {
                        boardManager.toggleFavorite(id: item.id)
                    } label: {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundColor(item.isFavorite ? .yellow : .secondary.opacity(0.6))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isHovered ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.12),
                        lineWidth: isHovered ? 1.5 : 1
                    )
            )
            .shadow(
                color: Color.black.opacity(isHovered ? 0.14 : 0.06),
                radius: isHovered ? 12 : 6,
                x: 0,
                y: isHovered ? 4 : 2
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
            .animation(.easeOut(duration: 0.16), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { h in
            hoveredBoardID = h ? item.id : nil
        }
        .contextMenu {
            Button {
                onOpenBoard(item)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }

            Button {
                let _ = boardManager.duplicateBoard(id: item.id)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }

            Button {
                renameText = item.title
                renamingBoardID = item.id
            } label: {
                Label("Rename...", systemImage: "pencil")
            }

            Button {
                boardManager.toggleFavorite(id: item.id)
            } label: {
                Label(item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: item.isFavorite ? "star.slash" : "star")
            }

            Divider()

            Button(role: .destructive) {
                boardManager.deleteBoard(id: item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Board List View
    private var boardsListView: some View {
        VStack(spacing: 2) {
            ForEach(boardManager.filteredBoards) { item in
                Button {
                    onOpenBoard(item)
                } label: {
                    HStack(spacing: 14) {
                        // Mini Thumbnail
                        ZStack {
                            Color.white
                            if let thumbURL = item.thumbnailURL,
                               let nsImg = NSImage(contentsOf: thumbURL) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.dashed")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 44, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                        // Title & Pages
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(item.pageCount) \(item.pageCount == 1 ? "page" : "pages")")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formattedDate(item.modifiedAt))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 140, alignment: .trailing)

                        Button {
                            boardManager.toggleFavorite(id: item.id)
                        } label: {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 13))
                                .foregroundColor(item.isFavorite ? .yellow : .secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rename Sheet
    private func renameSheet(for id: UUID) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Whiteboard")
                .font(.system(size: 14, weight: .bold))

            TextField("Board Title", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)

            HStack {
                Spacer()
                Button("Cancel") {
                    renamingBoardID = nil
                }
                Button("Rename") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        boardManager.renameBoard(id: id, newTitle: trimmed)
                    }
                    renamingBoardID = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))

            Text("No Boards Found")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)

            Text("Create a new whiteboard to start sketching, writing, or collaborating.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            Button {
                onNewBoard()
            } label: {
                Label("Create New Board", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    // MARK: - Dot Pattern Background
    private var dotPatternBackground: some View {
        GeometryReader { geo in
            Path { path in
                let spacing: CGFloat = 16
                for x in stride(from: 8.0, to: geo.size.width, by: spacing) {
                    for y in stride(from: 8.0, to: geo.size.height, by: spacing) {
                        path.addEllipse(in: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
                    }
                }
            }
            .fill(Color.primary.opacity(0.08))
        }
    }

    // MARK: - Date Formatter
    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "'Today,' h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "'Yesterday,' h:mm a"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Identifiable UUID Helper for Sheet
private struct IdentifiableUUID: Identifiable {
    let id: UUID
}
