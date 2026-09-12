import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Native Unified Toolbar Delegate
public final class WhiteboardToolbarDelegate: NSObject, NSToolbarDelegate {
    public weak var canvasView: WhiteboardCanvasView?

    public init(canvasView: WhiteboardCanvasView?) {
        self.canvasView = canvasView
        super.init()
    }

    public static let titleItemId = NSToolbarItem.Identifier("HiramekiWBTitleItem")
    public static let toolsCapsuleId = NSToolbarItem.Identifier("HiramekiWBToolsCapsule")
    public static let patternItemId = NSToolbarItem.Identifier("HiramekiWBPatternItem")

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            Self.titleItemId,
            .flexibleSpace,
            Self.toolsCapsuleId,
            .flexibleSpace,
            Self.patternItemId
        ]
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            Self.titleItemId,
            .flexibleSpace,
            Self.toolsCapsuleId,
            .flexibleSpace,
            Self.patternItemId
        ]
    }

    public func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let canvas = canvasView else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch itemIdentifier {
        case Self.titleItemId:
            let titleView = FreeformWhiteboardTitleView(state: canvas.freeformState, delegate: canvas)
            let host = NSHostingView(rootView: titleView)
            item.view = host
            return item

        case Self.toolsCapsuleId:
            let toolsView = FreeformWhiteboardToolsCapsule(state: canvas.freeformState, delegate: canvas)
            let host = NSHostingView(rootView: toolsView)
            item.view = host
            return item

        case Self.patternItemId:
            let patternView = FreeformWhiteboardPatternView(state: canvas.freeformState, delegate: canvas)
            let host = NSHostingView(rootView: patternView)
            item.view = host
            return item

        default:
            return nil
        }
    }
}

// MARK: - Native macOS Tahoe 26 Whiteboard Window
public final class WhiteboardWindow: NSWindow {
    public let canvasView: WhiteboardCanvasView
    private var toolbarDelegate: WhiteboardToolbarDelegate?

    public init(canvasView: WhiteboardCanvasView, initialRect: NSRect) {
        self.canvasView = canvasView

        super.init(
            contentRect: initialRect,
            styleMask: [
                .titled,
                .closable,
                .miniaturizable,
                .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )

        title = "Hirameki Whiteboard"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        toolbarStyle = .unified
        collectionBehavior = [.fullScreenPrimary]
        appearance = NSAppearance(named: .aqua)
        backgroundColor = .white
        hasShadow = true
        minSize = NSSize(width: 820, height: 540)
        acceptsMouseMovedEvents = true

        // Attach native unified toolbar
        let tbDelegate = WhiteboardToolbarDelegate(canvasView: canvasView)
        self.toolbarDelegate = tbDelegate
        let toolbar = NSToolbar(identifier: "HiramekiWhiteboardUnifiedToolbar")
        toolbar.delegate = tbDelegate
        toolbar.displayMode = .iconOnly
        self.toolbar = toolbar

        contentView = canvasView
        setFrameAutosaveName("HiramekiFreeformWhiteboardWindow")
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
                return super.performKeyEquivalent(with: event)
            }
            if chars == "w" {
                performClose(nil)
                return true
            }
            if chars == "m" {
                miniaturize(nil)
                return true
            }
            if chars == "0" {
                canvasView.resetZoom()
                return true
            }
            if chars == "=" || chars == "+" {
                canvasView.zoomIn()
                return true
            }
            if chars == "-" {
                canvasView.zoomOut()
                return true
            }
            if chars == "s" {
                if event.modifierFlags.contains(.shift) {
                    canvasView.freeformDidRequestSaveBoardAs()
                } else {
                    canvasView.freeformDidRequestSaveBoard()
                }
                return true
            }
            if chars == "o" {
                canvasView.freeformDidRequestOpenBoard()
                return true
            }
            if chars == "n" {
                canvasView.freeformDidRequestNewBoard()
                return true
            }
            if chars == "e" {
                canvasView.freeformDidRequestExportPDF()
                return true
            }
            if chars == "i" {
                canvasView.freeformDidRequestInsertPDF()
                return true
            }
            if chars == "u" {
                canvasView.freeformDidRequestInsertImage()
                return true
            }
            if chars == "z" {
                if event.modifierFlags.contains(.shift) {
                    canvasView.redo()
                } else {
                    canvasView.undo()
                }
                return true
            }
            if chars == "k" {
                canvasView.clearAll()
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

// MARK: - Main Whiteboard Window Controller
public final class WhiteboardWindowController: NSWindowController, NSWindowDelegate, WhiteboardCanvasDelegate {
    public var canvasView: WhiteboardCanvasView!
    public var whiteboardWindow: WhiteboardWindow!

    public init(document: WhiteboardDocument = WhiteboardDocument()) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 1280, height: 820)
        let width = min(1280, screenFrame.width - 80)
        let height = min(820, screenFrame.height - 80)
        let initialRect = NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        )

        let canvas = WhiteboardCanvasView(frame: NSRect(origin: .zero, size: initialRect.size), document: document)
        let win = WhiteboardWindow(canvasView: canvas, initialRect: initialRect)

        super.init(window: win)

        self.canvasView = canvas
        self.whiteboardWindow = win
        win.delegate = self
        canvas.canvasDelegate = self

        updateWindowTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateWindowTitle() {
        guard let canvas = canvasView, let win = whiteboardWindow else { return }
        let pageName = canvas.document.activePage.name
        let docTitle = canvas.document.title
        win.title = "\(docTitle) — \(pageName)"
    }

    public func windowWillClose(_ notification: Notification) {
        if let fileURL = canvasView.document.fileURL {
            try? canvasView.document.save(to: fileURL)
        }
    }

    // MARK: - File Dialogs
    public func saveBoardDialog(saveAs: Bool = false) {
        guard let win = whiteboardWindow else { return }

        if !saveAs, let existingURL = canvasView.document.fileURL {
            do {
                try canvasView.document.save(to: existingURL)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
            return
        }

        let savePanel = NSSavePanel()
        savePanel.directoryURL = WhiteboardDocument.defaultDirectory
        savePanel.nameFieldStringValue = "\(canvasView.document.title).\(WhiteboardDocument.fileExtension)"
        if let uti = UTType(filenameExtension: WhiteboardDocument.fileExtension) {
            savePanel.allowedContentTypes = [uti]
        }
        savePanel.title = "Save Whiteboard File"
        savePanel.message = "Choose a location to save this Hirameki Whiteboard"

        savePanel.beginSheetModal(for: win) { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = savePanel.url {
                do {
                    try self.canvasView.document.save(to: url)
                    self.updateWindowTitle()
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }

    public func openBoardDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = WhiteboardDocument.defaultDirectory
        if let uti = UTType(filenameExtension: WhiteboardDocument.fileExtension) {
            panel.allowedContentTypes = [uti]
        }
        panel.title = "Open Whiteboard File"
        panel.message = "Choose a Hirameki Whiteboard file to open"

        guard let win = whiteboardWindow else { return }
        panel.beginSheetModal(for: win) { response in
            if response == .OK, let url = panel.url {
                do {
                    let doc = try WhiteboardDocument.load(from: url)
                    let newCtrl = WhiteboardAppDelegate.shared.createBoard(document: doc)
                    newCtrl.showWindow(nil)
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }

    public func exportPDFDialog() {
        guard let win = whiteboardWindow else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let safeName = canvasView.document.activePage.name.replacingOccurrences(of: "/", with: "-")
        savePanel.nameFieldStringValue = "\(canvasView.document.title) - \(safeName).pdf"
        savePanel.title = "Export Whiteboard to PDF"

        savePanel.beginSheetModal(for: win) { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else { return }
            let pdfData = PDFExportManager.shared.exportPageToPDF(page: self.canvasView.document.activePage)
            do {
                try pdfData.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    public func promptInsertPDF() {
        guard let win = whiteboardWindow else { return }
        let panel = NSOpenPanel()
        panel.title = "Insert PDF into Whiteboard"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.canvasView.insertPDF(url: url)
            }
        }
    }

    public func promptInsertImage() {
        guard let win = whiteboardWindow else { return }
        let panel = NSOpenPanel()
        panel.title = "Insert Image Attachment"
        let types: [UTType] = [.image, .png, .jpeg, .tiff, .gif, .webP, .heic, .bmp]
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.canvasView.insertImage(url: url)
            }
        }
    }

    // MARK: - WhiteboardCanvasDelegate
    public func canvasDidUpdateDocument(_ doc: WhiteboardDocument) {
        updateWindowTitle()
    }

    public func canvasDidRequestNewPage() {
        canvasView.addNewPage()
    }

    public func canvasDidRequestInsertPDF() {
        promptInsertPDF()
    }

    public func canvasDidRequestInsertImage() {
        promptInsertImage()
    }

    public func canvasDidRequestSave() {
        saveBoardDialog(saveAs: false)
    }

    public func canvasDidRequestSaveAs() {
        saveBoardDialog(saveAs: true)
    }

    public func canvasDidRequestOpen() {
        openBoardDialog()
    }

    public func canvasDidRequestExportPDF() {
        exportPDFDialog()
    }

    public func canvasDidRequestNewBoard() {
        let newCtrl = WhiteboardAppDelegate.shared.createBoard()
        newCtrl.showWindow(nil)
    }
}

// MARK: - Main Application Delegate & Menu Builder
@main
public final class WhiteboardAppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: WhiteboardAppDelegate {
        NSApplication.shared.delegate as! WhiteboardAppDelegate
    }

    public static func main() {
        let app = NSApplication.shared
        let delegate = WhiteboardAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    private var windowControllers: [WhiteboardWindowController] = []

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        let args = CommandLine.arguments.dropFirst()
        var openedAny = false
        for arg in args where !arg.starts(with: "-") {
            let url = URL(fileURLWithPath: arg)
            if FileManager.default.fileExists(atPath: url.path) {
                if application(NSApplication.shared, openFile: url.path) {
                    openedAny = true
                }
            }
        }
        if !openedAny && windowControllers.isEmpty {
            createBoard()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createBoard()
        }
        return true
    }

    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            _ = self.application(application, openFile: url.path)
        }
    }

    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            let winCtrl: WhiteboardWindowController
            if let first = windowControllers.first, first.canvasView.document.activePage.strokes.isEmpty && first.canvasView.document.activePage.embeddedPDFs.isEmpty && first.canvasView.document.activePage.embeddedImages.isEmpty {
                winCtrl = first
            } else {
                winCtrl = createBoard()
            }
            winCtrl.canvasView.insertPDF(url: url)
            winCtrl.whiteboardWindow.makeKeyAndOrderFront(nil)
            return true
        }

        if ["png", "jpg", "jpeg", "gif", "tiff", "tif", "webp", "heic", "bmp"].contains(ext) {
            let winCtrl: WhiteboardWindowController
            if let first = windowControllers.first, first.canvasView.document.activePage.strokes.isEmpty && first.canvasView.document.activePage.embeddedPDFs.isEmpty && first.canvasView.document.activePage.embeddedImages.isEmpty {
                winCtrl = first
            } else {
                winCtrl = createBoard()
            }
            winCtrl.canvasView.insertImage(url: url)
            winCtrl.whiteboardWindow.makeKeyAndOrderFront(nil)
            return true
        }

        do {
            let doc = try WhiteboardDocument.load(from: url)
            let winCtrl = createBoard(document: doc)
            winCtrl.showWindow(self)
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }

    @discardableResult
    public func createBoard(document: WhiteboardDocument = WhiteboardDocument()) -> WhiteboardWindowController {
        let winCtrl = WhiteboardWindowController(document: document)
        windowControllers.append(winCtrl)
        winCtrl.showWindow(self)
        winCtrl.whiteboardWindow.center()
        winCtrl.whiteboardWindow.makeKeyAndOrderFront(nil)
        winCtrl.whiteboardWindow.orderFrontRegardless()
        return winCtrl
    }

    public var currentWindowController: WhiteboardWindowController? {
        if let keyWin = NSApp.keyWindow {
            return windowControllers.first { $0.window == keyWin }
        }
        return windowControllers.first
    }

    // MARK: - Menu Setup
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. Application Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Hirameki Whiteboard", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Hirameki Whiteboard", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Hirameki Whiteboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Whiteboard", action: #selector(menuNewBoard), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open Whiteboard...", action: #selector(menuOpenBoard), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(menuSaveBoard), keyEquivalent: "s")
        let saveAs = NSMenuItem(title: "Save As...", action: #selector(menuSaveBoardAs), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAs)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Insert Image Attachment...", action: #selector(menuInsertImage), keyEquivalent: "u")
        fileMenu.addItem(withTitle: "Insert PDF Document...", action: #selector(menuInsertPDF), keyEquivalent: "i")
        fileMenu.addItem(withTitle: "Export Annotated PDF...", action: #selector(menuExportPDF), keyEquivalent: "e")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(menuUndo), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Redo", action: #selector(menuRedo), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Paste", action: #selector(menuPaste), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Clear Whiteboard", action: #selector(menuClearAll), keyEquivalent: "k")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(menuZoomIn), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(menuZoomOut), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size (100%)", action: #selector(menuResetZoom), keyEquivalent: "0")
        viewMenu.addItem(NSMenuItem.separator())
        let fullScreenItem = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(fullScreenItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 5. Window Menu
        let winMenuItem = NSMenuItem()
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        winMenuItem.submenu = winMenu
        mainMenu.addItem(winMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Hirameki Whiteboard"
        alert.informativeText = "Infinite Vector Canvas with Multi-Page & PDF Annotation Support.\nVersion 1.0.0"
        alert.runModal()
    }

    @objc private func menuNewBoard() {
        createBoard()
    }

    @objc private func menuOpenBoard() {
        currentWindowController?.openBoardDialog()
    }

    @objc private func menuSaveBoard() {
        currentWindowController?.saveBoardDialog(saveAs: false)
    }

    @objc private func menuSaveBoardAs() {
        currentWindowController?.saveBoardDialog(saveAs: true)
    }

    @objc private func menuInsertImage() {
        currentWindowController?.promptInsertImage()
    }

    @objc private func menuInsertPDF() {
        currentWindowController?.promptInsertPDF()
    }

    @objc private func menuPaste() {
        currentWindowController?.canvasView.paste(nil)
    }

    @objc private func menuExportPDF() {
        currentWindowController?.exportPDFDialog()
    }

    @objc private func menuUndo() {
        currentWindowController?.canvasView.undo()
    }

    @objc private func menuRedo() {
        currentWindowController?.canvasView.redo()
    }

    @objc private func menuClearAll() {
        currentWindowController?.canvasView.clearAll()
    }

    @objc private func menuZoomIn() {
        currentWindowController?.canvasView.zoomIn()
    }

    @objc private func menuZoomOut() {
        currentWindowController?.canvasView.zoomOut()
    }

    @objc private func menuResetZoom() {
        currentWindowController?.canvasView.resetZoom()
    }
}
