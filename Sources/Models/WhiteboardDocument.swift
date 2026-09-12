import Foundation
import AppKit

public struct WhiteboardDocument: Identifiable, Codable {
    public var id: UUID
    public var title: String
    public var pages: [WhiteboardPage]
    public var activePageIndex: Int
    public var createdAt: Date
    public var modifiedAt: Date
    public var fileURL: URL?

    public init(
        id: UUID = UUID(),
        title: String = "Untitled Board",
        pages: [WhiteboardPage] = [WhiteboardPage(name: "Page 1")],
        activePageIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        fileURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.pages = pages.isEmpty ? [WhiteboardPage(name: "Page 1")] : pages
        self.activePageIndex = max(0, min(activePageIndex, self.pages.count - 1))
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.fileURL = fileURL
    }

    public static let fileExtension = "hiramekiboard"

    public var activePage: WhiteboardPage {
        get {
            guard activePageIndex < pages.count else { return pages[0] }
            return pages[activePageIndex]
        }
        set {
            if activePageIndex < pages.count {
                pages[activePageIndex] = newValue
            }
        }
    }

    public mutating func addPage(name: String? = nil) -> Int {
        let pageNumber = pages.count + 1
        let newName = name ?? "Page \(pageNumber)"
        let newPage = WhiteboardPage(name: newName)
        pages.append(newPage)
        activePageIndex = pages.count - 1
        modifiedAt = Date()
        return activePageIndex
    }

    public mutating func duplicatePage(at index: Int) -> Int {
        guard index >= 0 && index < pages.count else { return activePageIndex }
        var copy = pages[index]
        copy.id = UUID()
        copy.name = "\(copy.name) (Copy)"
        let insertIndex = index + 1
        pages.insert(copy, at: insertIndex)
        activePageIndex = insertIndex
        modifiedAt = Date()
        return insertIndex
    }

    public mutating func deletePage(at index: Int) {
        guard pages.count > 1 else { return }
        guard index >= 0 && index < pages.count else { return }
        pages.remove(at: index)
        if activePageIndex >= pages.count {
            activePageIndex = pages.count - 1
        }
        modifiedAt = Date()
    }

    public mutating func renamePage(at index: Int, to newName: String) {
        guard index >= 0 && index < pages.count else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pages[index].name = trimmed
            modifiedAt = Date()
        }
    }

    public static var defaultDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
        let boardsDir = docs.appendingPathComponent("Hirameki Whiteboards")
        if !FileManager.default.fileExists(atPath: boardsDir.path) {
            try? FileManager.default.createDirectory(atPath: boardsDir.path, withIntermediateDirectories: true)
        }
        return boardsDir
    }

    public static func nextUntitledURL() -> URL {
        let dir = defaultDirectory
        let baseName = "Untitled Board"
        var candidateURL = dir.appendingPathComponent("\(baseName).\(fileExtension)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidateURL.path) {
            candidateURL = dir.appendingPathComponent("\(baseName) \(index).\(fileExtension)")
            index += 1
        }
        return candidateURL
    }

    public func save(to url: URL) throws {
        var doc = self
        doc.fileURL = url
        doc.modifiedAt = Date()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)
        try data.write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> WhiteboardDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var doc = try decoder.decode(WhiteboardDocument.self, from: data)
        doc.fileURL = url
        return doc
    }
}
