import Foundation
import AppKit
import SwiftUI

// MARK: - Board Category for Sidebar Navigation
public enum BoardCategory: String, CaseIterable, Identifiable {
    case allBoards = "All Boards"
    case recents = "Recents"
    case shared = "Shared"
    case favorites = "Favorites"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .allBoards: return "square.grid.2x2"
        case .recents: return "clock"
        case .shared: return "person.2"
        case .favorites: return "star"
        }
    }
}

// MARK: - Lightweight Board Item Model for Fast Gallery Display
public struct BoardItem: Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var fileURL: URL
    public var thumbnailURL: URL?
    public var modifiedAt: Date
    public var createdAt: Date
    public var isFavorite: Bool
    public var pageCount: Int

    public init(
        id: UUID,
        title: String,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        modifiedAt: Date,
        createdAt: Date,
        isFavorite: Bool = false,
        pageCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.pageCount = pageCount
    }
}

// MARK: - Board Manager: Auto-Save Engine, Thumbnails & Local Storage Index
public final class BoardManager: ObservableObject {
    public static let shared = BoardManager()

    @Published public var boards: [BoardItem] = []
    @Published public var selectedCategory: BoardCategory = .allBoards
    @Published public var searchQuery: String = ""
    @Published public var currentBoardID: UUID?
    @Published public var isSaving: Bool = false

    private var autoSaveTimer: Timer?
    private var pendingDocumentToSave: WhiteboardDocument?
    private let saveQueue = DispatchQueue(label: "com.hirameki.boardmanager.save", qos: .utility)

    public var thumbnailsDirectory: URL {
        let dir = WhiteboardDocument.defaultDirectory.appendingPathComponent(".thumbnails", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(atPath: dir.path, withIntermediateDirectories: true)
        }
        return dir
    }

    public init() {
        reloadBoards()
    }

    // MARK: - Filtered Boards
    public var filteredBoards: [BoardItem] {
        var list = boards

        switch selectedCategory {
        case .allBoards:
            break
        case .recents:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
            list = list.filter { $0.modifiedAt >= sevenDaysAgo }
        case .shared:
            list = [] // Local Hirameki boards; shared can be empty or flagged
        case .favorites:
            list = list.filter { $0.isFavorite }
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter { $0.title.lowercased().contains(query) }
        }

        return list.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    public func count(for category: BoardCategory) -> Int {
        switch category {
        case .allBoards: return boards.count
        case .recents:
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
            return boards.filter { $0.modifiedAt >= sevenDaysAgo }.count
        case .shared: return 0
        case .favorites: return boards.filter { $0.isFavorite }.count
        }
    }

    // MARK: - File Indexing
    public func reloadBoards() {
        let dir = WhiteboardDocument.defaultDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var loaded: [BoardItem] = []
        for file in files where file.pathExtension == WhiteboardDocument.fileExtension || file.pathExtension == "hirameki" {
            if let doc = try? WhiteboardDocument.load(from: file) {
                let thumbURL = thumbnailURL(for: doc.id)
                let item = BoardItem(
                    id: doc.id,
                    title: doc.title,
                    fileURL: file,
                    thumbnailURL: FileManager.default.fileExists(atPath: thumbURL.path) ? thumbURL : nil,
                    modifiedAt: doc.modifiedAt,
                    createdAt: doc.createdAt,
                    isFavorite: doc.isFavorite,
                    pageCount: doc.pages.count
                )
                loaded.append(item)
            }
        }

        DispatchQueue.main.async {
            self.boards = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
        }
    }

    public func thumbnailURL(for boardID: UUID) -> URL {
        thumbnailsDirectory.appendingPathComponent("\(boardID.uuidString).png")
    }

    // MARK: - Auto-Save Engine
    public func autoSave(document: WhiteboardDocument) {
        pendingDocumentToSave = document
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            self?.flushPendingAutoSave()
        }
    }

    public func flushPendingAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        guard var doc = pendingDocumentToSave else { return }
        pendingDocumentToSave = nil

        let targetURL: URL
        if let existing = doc.fileURL {
            targetURL = existing
        } else {
            targetURL = WhiteboardDocument.defaultDirectory
                .appendingPathComponent("\(doc.title).\(WhiteboardDocument.fileExtension)")
            doc.fileURL = targetURL
        }

        self.isSaving = true
        saveQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try doc.save(to: targetURL)
                self.renderAndSaveThumbnail(for: doc)

                DispatchQueue.main.async {
                    self.isSaving = false
                    self.updateItem(from: doc, fileURL: targetURL)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSaving = false
                    NSLog("[BoardManager] Failed to auto-save document: \(error)")
                }
            }
        }
    }

    private func updateItem(from doc: WhiteboardDocument, fileURL: URL) {
        let thumbURL = thumbnailURL(for: doc.id)
        let item = BoardItem(
            id: doc.id,
            title: doc.title,
            fileURL: fileURL,
            thumbnailURL: FileManager.default.fileExists(atPath: thumbURL.path) ? thumbURL : nil,
            modifiedAt: doc.modifiedAt,
            createdAt: doc.createdAt,
            isFavorite: doc.isFavorite,
            pageCount: doc.pages.count
        )

        if let idx = boards.firstIndex(where: { $0.id == doc.id }) {
            boards[idx] = item
        } else {
            boards.insert(item, at: 0)
        }
    }

    // MARK: - CRUD Operations
    @discardableResult
    public func createNewBoard(title: String? = nil) -> WhiteboardDocument {
        let defaultTitle: String
        let fileURL: URL
        if let customTitle = title, !customTitle.isEmpty {
            defaultTitle = customTitle
            fileURL = WhiteboardDocument.defaultDirectory.appendingPathComponent("\(customTitle).\(WhiteboardDocument.fileExtension)")
        } else {
            fileURL = WhiteboardDocument.nextUntitledURL()
            defaultTitle = fileURL.deletingPathExtension().lastPathComponent
        }

        let doc = WhiteboardDocument(
            id: UUID(),
            title: defaultTitle,
            pages: [WhiteboardPage(name: "Page 1")],
            activePageIndex: 0,
            createdAt: Date(),
            modifiedAt: Date(),
            fileURL: fileURL,
            isFavorite: false
        )

        try? doc.save(to: fileURL)
        renderAndSaveThumbnail(for: doc)
        updateItem(from: doc, fileURL: fileURL)
        return doc
    }

    public func duplicateBoard(id: UUID) -> WhiteboardDocument? {
        guard let item = boards.first(where: { $0.id == id }),
              let originalDoc = try? WhiteboardDocument.load(from: item.fileURL) else {
            return nil
        }

        let newTitle = "\(originalDoc.title) Copy"
        var uniqueURL = WhiteboardDocument.defaultDirectory.appendingPathComponent("\(newTitle).\(WhiteboardDocument.fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: uniqueURL.path) {
            uniqueURL = WhiteboardDocument.defaultDirectory.appendingPathComponent("\(newTitle) \(counter).\(WhiteboardDocument.fileExtension)")
            counter += 1
        }

        var newDoc = originalDoc
        newDoc.id = UUID()
        newDoc.title = uniqueURL.deletingPathExtension().lastPathComponent
        newDoc.createdAt = Date()
        newDoc.modifiedAt = Date()
        newDoc.fileURL = uniqueURL
        newDoc.isFavorite = false

        try? newDoc.save(to: uniqueURL)
        renderAndSaveThumbnail(for: newDoc)
        updateItem(from: newDoc, fileURL: uniqueURL)
        return newDoc
    }

    public func deleteBoard(id: UUID) {
        guard let item = boards.first(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: item.fileURL)
        let thumbURL = thumbnailURL(for: id)
        try? FileManager.default.removeItem(at: thumbURL)
        boards.removeAll { $0.id == id }
    }

    public func renameBoard(id: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = boards.firstIndex(where: { $0.id == id }) else { return }
        var item = boards[idx]

        guard var doc = try? WhiteboardDocument.load(from: item.fileURL) else { return }
        doc.title = trimmed
        doc.modifiedAt = Date()

        let newURL = WhiteboardDocument.defaultDirectory.appendingPathComponent("\(trimmed).\(WhiteboardDocument.fileExtension)")
        if newURL != item.fileURL {
            try? FileManager.default.moveItem(at: item.fileURL, to: newURL)
            doc.fileURL = newURL
            item.fileURL = newURL
        }

        try? doc.save(to: doc.fileURL ?? newURL)
        item.title = trimmed
        item.modifiedAt = doc.modifiedAt
        boards[idx] = item
    }

    public func toggleFavorite(id: UUID) {
        guard let idx = boards.firstIndex(where: { $0.id == id }) else { return }
        var item = boards[idx]
        item.isFavorite.toggle()
        boards[idx] = item

        if var doc = try? WhiteboardDocument.load(from: item.fileURL) {
            doc.isFavorite = item.isFavorite
            try? doc.save(to: item.fileURL)
        }
    }

    // MARK: - Crisp Thumbnail Renderer
    public func renderAndSaveThumbnail(for doc: WhiteboardDocument) {
        let size = NSSize(width: 320, height: 200)
        let image = NSImage(size: size)

        image.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return
        }

        // 1. Background: Clean Apple White with subtle soft border
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // 2. Draw subtle grid or dots
        let pattern = doc.activePage.pattern
        if pattern == "dots" {
            NSColor(calibratedWhite: 0.88, alpha: 1.0).setFill()
            let spacing: CGFloat = 16.0
            for x in stride(from: 8.0, to: size.width, by: spacing) {
                for y in stride(from: 8.0, to: size.height, by: spacing) {
                    ctx.fillEllipse(in: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5))
                }
            }
        } else if pattern == "grid" {
            NSColor(calibratedWhite: 0.92, alpha: 1.0).setStroke()
            let path = NSBezierPath()
            let spacing: CGFloat = 20.0
            for x in stride(from: 0.0, to: size.width, by: spacing) {
                path.move(to: NSPoint(x: x, y: 0))
                path.line(to: NSPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, to: size.height, by: spacing) {
                path.move(to: NSPoint(x: 0, y: y))
                path.line(to: NSPoint(x: size.width, y: y))
            }
            path.lineWidth = 0.5
            path.stroke()
        }

        // 3. Render strokes, notes, text, etc.
        let page = doc.activePage
        if !page.strokes.isEmpty {
            // Compute bounds of strokes to scale gracefully
            var minX: CGFloat = .greatestFiniteMagnitude
            var maxX: CGFloat = -.greatestFiniteMagnitude
            var minY: CGFloat = .greatestFiniteMagnitude
            var maxY: CGFloat = -.greatestFiniteMagnitude

            for stroke in page.strokes {
                for pt in stroke.points {
                    minX = min(minX, pt.x)
                    maxX = max(maxX, pt.x)
                    minY = min(minY, pt.y)
                    maxY = max(maxY, pt.y)
                }
            }

            let strokeW = max(100, maxX - minX)
            let strokeH = max(100, maxY - minY)
            let pad: CGFloat = 24.0
            let scaleX = (size.width - pad * 2) / strokeW
            let scaleY = (size.height - pad * 2) / strokeH
            let scale = min(scaleX, scaleY, 1.0)

            let offsetX = (size.width - strokeW * scale) / 2 - minX * scale
            let offsetY = (size.height - strokeH * scale) / 2 - minY * scale

            for stroke in page.strokes {
                guard stroke.points.count >= 2 else { continue }
                let bPath = NSBezierPath()
                let first = stroke.points[0]
                bPath.move(to: NSPoint(x: first.x * scale + offsetX, y: first.y * scale + offsetY))

                for i in 1..<stroke.points.count {
                    let pt = stroke.points[i]
                    bPath.line(to: NSPoint(x: pt.x * scale + offsetX, y: pt.y * scale + offsetY))
                }

                stroke.nsColor.setStroke()
                bPath.lineWidth = max(1.0, stroke.width * scale * 0.8)
                bPath.lineCapStyle = .round
                bPath.lineJoinStyle = .round
                bPath.stroke()
            }
        } else if !page.embeddedImages.isEmpty || !page.embeddedPDFs.isEmpty {
            // Draw placeholder visual icon for media if strokes empty
            let icon = NSImage(systemSymbolName: "photo.on.rectangle.angled", accessibilityDescription: nil)
            let iconRect = NSRect(x: (size.width - 48)/2, y: (size.height - 48)/2, width: 48, height: 48)
            icon?.draw(in: iconRect)
        }

        image.unlockFocus()

        // Save PNG to thumbnails directory
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return
        }

        let file = thumbnailURL(for: doc.id)
        try? png.write(to: file)
    }
}
