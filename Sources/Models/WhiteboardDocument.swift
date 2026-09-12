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
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        title: String = "Untitled Board",
        pages: [WhiteboardPage] = [WhiteboardPage(name: "Page 1")],
        activePageIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        fileURL: URL? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.pages = pages.isEmpty ? [WhiteboardPage(name: "Page 1")] : pages
        self.activePageIndex = max(0, min(activePageIndex, self.pages.count - 1))
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.fileURL = fileURL
        self.isFavorite = isFavorite
    }

    enum CodingKeys: String, CodingKey {
        case id, title, pages, activePageIndex, createdAt, modifiedAt, fileURL, isFavorite
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        pages = try container.decode([WhiteboardPage].self, forKey: .pages)
        activePageIndex = try container.decode(Int.self, forKey: .activePageIndex)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        fileURL = try container.decodeIfPresent(URL.self, forKey: .fileURL)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(pages, forKey: .pages)
        try container.encode(activePageIndex, forKey: .activePageIndex)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encodeIfPresent(fileURL, forKey: .fileURL)
        try container.encode(isFavorite, forKey: .isFavorite)
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
