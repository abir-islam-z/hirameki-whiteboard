import AppKit
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

// MARK: - Whiteboard ViewModel
public final class WhiteboardViewModel: ObservableObject, WhiteboardCanvasDelegate {
    @Published public var document: WhiteboardDocument = WhiteboardDocument()
    @Published public var activeTool: Tool = .pen
    @Published public var activeColor: Color = .black
    @Published public var activeWidth: CGFloat = 4.0
    @Published public var currentZoom: CGFloat = 1.0

    public weak var canvasView: WhiteboardCanvasView?
    public weak var window: NSWindow?

    public init(document: WhiteboardDocument = WhiteboardDocument()) {
        self.document = document
    }

    public func syncFromCanvas() {
        guard let canvas = canvasView else { return }
        self.document = canvas.document
        self.currentZoom = canvas.zoomScale
        self.activeTool = canvas.activeTool
        updateWindowTitle()
    }

    public func updateWindowTitle() {
        let pageName = document.activePage.name
        let docTitle = document.title
        window?.title = "\(docTitle) — \(pageName)"
    }

    // MARK: - Page Actions
    public func selectPage(at index: Int) {
        canvasView?.switchToPage(at: index)
        syncFromCanvas()
    }

    public func addPage() {
        let newIndex = canvasView?.document.addPage() ?? document.addPage()
        canvasView?.switchToPage(at: newIndex)
        syncFromCanvas()
    }

    public func duplicatePage(at index: Int) {
        let newIndex = canvasView?.document.duplicatePage(at: index) ?? document.duplicatePage(at: index)
        canvasView?.switchToPage(at: newIndex)
        syncFromCanvas()
    }

    public func deletePage(at index: Int) {
        canvasView?.document.deletePage(at: index)
        canvasView?.loadCurrentPage()
        syncFromCanvas()
    }

    public func renamePage(at index: Int, to newName: String) {
        canvasView?.document.renamePage(at: index, to: newName)
        syncFromCanvas()
    }

    public func nextPage() {
        if document.activePageIndex < document.pages.count - 1 {
            selectPage(at: document.activePageIndex + 1)
        }
    }

    public func prevPage() {
        if document.activePageIndex > 0 {
            selectPage(at: document.activePageIndex - 1)
        }
    }

    // MARK: - Canvas Actions
    public func undo() {
        canvasView?.undo()
        syncFromCanvas()
    }

    public func redo() {
        canvasView?.redo()
        syncFromCanvas()
    }

    public func clearAll() {
        canvasView?.clearAll()
        syncFromCanvas()
    }

    public func zoomIn() {
        canvasView?.zoomIn()
        currentZoom = canvasView?.zoomScale ?? 1.0
    }

    public func zoomOut() {
        canvasView?.zoomOut()
        currentZoom = canvasView?.zoomScale ?? 1.0
    }

    public func resetZoom() {
        canvasView?.resetZoom()
        currentZoom = canvasView?.zoomScale ?? 1.0
    }

    // MARK: - PDF Insertion & Export
    public func promptInsertPDF() {
        let panel = NSOpenPanel()
        panel.title = "Insert PDF into Whiteboard"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        panel.beginSheetModal(for: window ?? NSApp.keyWindow ?? NSWindow()) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.canvasView?.insertPDF(url: url)
                self?.syncFromCanvas()
            }
        }
    }

    public func promptExportPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Annotated PDF"
        panel.allowedContentTypes = [.pdf]
        let safeName = document.activePage.name.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(document.title) - \(safeName).pdf"

        panel.beginSheetModal(for: window ?? NSApp.keyWindow ?? NSWindow()) { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            let pdfData = PDFExportManager.shared.exportPageToPDF(page: self.document.activePage)
            do {
                try pdfData.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    // MARK: - Save & Load Whiteboard Document (.hiramekiboard)
    public func promptSaveDocument(saveAs: Bool = false) {
        if !saveAs, let existingURL = document.fileURL {
            do {
                try document.save(to: existingURL)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save Hirameki Whiteboard"
        panel.allowedContentTypes = [UTType(filenameExtension: WhiteboardDocument.fileExtension) ?? .json]
        panel.nameFieldStringValue = "\(document.title).\(WhiteboardDocument.fileExtension)"

        panel.beginSheetModal(for: window ?? NSApp.keyWindow ?? NSWindow()) { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            do {
                self.document.title = url.deletingPathExtension().lastPathComponent
                try self.document.save(to: url)
                self.updateWindowTitle()
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    public func promptOpenDocument() {
        let panel = NSOpenPanel()
        panel.title = "Open Hirameki Whiteboard"
        panel.allowedContentTypes = [UTType(filenameExtension: WhiteboardDocument.fileExtension) ?? .json, .pdf]
        panel.allowsMultipleSelection = false

        panel.beginSheetModal(for: window ?? NSApp.keyWindow ?? NSWindow()) { [weak self] response in
            guard response == .OK, let url = panel.url, let self = self else { return }
            if url.pathExtension.lowercased() == "pdf" {
                self.canvasView?.insertPDF(url: url)
                self.syncFromCanvas()
            } else {
                do {
                    let loadedDoc = try WhiteboardDocument.load(from: url)
                    self.document = loadedDoc
                    self.canvasView?.document = loadedDoc
                    self.canvasView?.loadCurrentPage()
                    self.syncFromCanvas()
                } catch {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - WhiteboardCanvasDelegate
    public func canvasDidUpdateDocument(_ doc: WhiteboardDocument) {
        self.document = doc
        updateWindowTitle()
    }

    public func canvasDidRequestNewPage() {
        addPage()
    }

    public func canvasDidRequestInsertPDF() {
        promptInsertPDF()
    }
}

// MARK: - Root SwiftUI Window View
public struct WhiteboardRootView: View {
    @ObservedObject var vm: WhiteboardViewModel

    public var body: some View {
        ZStack {
            // Background is transparent so mouse passes through to canvas
            Color.clear

            // Top Floating Toolbar
            VStack {
                WhiteboardToolbar(
                    activeTool: Binding(
                        get: { vm.activeTool },
                        set: { newTool in
                            vm.activeTool = newTool
                            vm.canvasView?.activeTool = newTool
                        }
                    ),
                    activeColor: Binding(
                        get: { vm.activeColor },
                        set: { newColor in
                            vm.activeColor = newColor
                            vm.canvasView?.activeColor = NSColor(newColor)
                        }
                    ),
                    activeWidth: Binding(
                        get: { vm.activeWidth },
                        set: { newWidth in
                            vm.activeWidth = newWidth
                            vm.canvasView?.activeWidth = newWidth
                        }
                    ),
                    onInsertPDF: { vm.promptInsertPDF() },
                    onUndo: { vm.undo() },
                    onRedo: { vm.redo() },
                    onClearAll: { vm.clearAll() },
                    onExportPDF: { vm.promptExportPDF() }
                )
                .padding(.top, 14)

                Spacer()
            }

            // Bottom Floating Page Navigation Bar
            VStack {
                Spacer()

                HStack {
                    PageNavigationBar(
                        document: $vm.document,
                        onSelectPage: { idx in vm.selectPage(at: idx) },
                        onAddPage: { vm.addPage() },
                        onDuplicatePage: { idx in vm.duplicatePage(at: idx) },
                        onDeletePage: { idx in vm.deletePage(at: idx) },
                        onRenamePage: { idx, name in vm.renamePage(at: idx, to: name) },
                        onZoomIn: { vm.zoomIn() },
                        onZoomOut: { vm.zoomOut() },
                        onResetZoom: { vm.resetZoom() },
                        currentZoom: vm.currentZoom
                    )
                    .frame(maxWidth: 480)

                    Spacer()
                }
                .padding(.leading, 18)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Pass-Through Hosting View for Transparent SwiftUI Overlay
public final class TransparentPassThroughHostingView<Content: View>: NSHostingView<Content> {
    public override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        // If the hit view is the hosting view itself or background, let the canvas underneath receive mouse events
        if view === self {
            return nil
        }
        return view
    }
}

// MARK: - Main Whiteboard Window Controller
public final class WhiteboardWindowController: NSWindowController, NSWindowDelegate {
    public let viewModel: WhiteboardViewModel
    private var canvasView: WhiteboardCanvasView!
    private var overlayHostingView: TransparentPassThroughHostingView<WhiteboardRootView>!

    public init(document: WhiteboardDocument = WhiteboardDocument()) {
        self.viewModel = WhiteboardViewModel(document: document)

        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 880, height: 560)
        window.title = "Hirameki Whiteboard"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .white
        window.isOpaque = true
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        self.viewModel.window = window

        setupViews(in: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews(in window: NSWindow) {
        guard let contentView = window.contentView else { return }

        // 1. Vector Infinite Canvas (Main background responder)
        canvasView = WhiteboardCanvasView(frame: contentView.bounds, document: viewModel.document)
        canvasView.autoresizingMask = [.width, .height]
        canvasView.canvasDelegate = viewModel
        viewModel.canvasView = canvasView

        canvasView.onToolChanged = { [weak self] newTool in
            DispatchQueue.main.async {
                self?.viewModel.activeTool = newTool
            }
        }
        canvasView.onZoomChanged = { [weak self] newZoom in
            DispatchQueue.main.async {
                self?.viewModel.currentZoom = newZoom
            }
        }

        contentView.addSubview(canvasView)

        // 2. SwiftUI Floating Overlays (Toolbar & Page Navigator)
        let rootView = WhiteboardRootView(vm: viewModel)
        overlayHostingView = TransparentPassThroughHostingView(rootView: rootView)
        overlayHostingView.frame = contentView.bounds
        overlayHostingView.autoresizingMask = [.width, .height]

        contentView.addSubview(overlayHostingView)

        viewModel.updateWindowTitle()
        window.makeFirstResponder(canvasView)
    }

    public func windowWillClose(_ notification: Notification) {
        if let fileURL = viewModel.document.fileURL {
            try? viewModel.document.save(to: fileURL)
        }
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
        createNewBoard()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createNewBoard()
        }
        return true
    }

    public func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if url.pathExtension.lowercased() == "pdf" {
            let winCtrl = createNewBoard()
            winCtrl.viewModel.canvasView?.insertPDF(url: url)
            winCtrl.viewModel.syncFromCanvas()
            return true
        }

        do {
            let doc = try WhiteboardDocument.load(from: url)
            let winCtrl = WhiteboardWindowController(document: doc)
            windowControllers.append(winCtrl)
            winCtrl.showWindow(self)
            return true
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
            return false
        }
    }

    @discardableResult
    public func createNewBoard() -> WhiteboardWindowController {
        let winCtrl = WhiteboardWindowController()
        windowControllers.append(winCtrl)
        winCtrl.showWindow(self)
        winCtrl.window?.center()
        winCtrl.window?.makeKeyAndOrderFront(nil)
        winCtrl.window?.orderFrontRegardless()
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
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Hirameki Whiteboard", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Hirameki Whiteboard", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Board", action: #selector(menuNewBoard), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open Board...", action: #selector(menuOpenBoard), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(withTitle: "Save Board", action: #selector(menuSaveBoard), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(withTitle: "Save Board As...", action: #selector(menuSaveBoardAs), keyEquivalent: "s")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Insert PDF...", action: #selector(menuInsertPDF), keyEquivalent: "i")
        fileMenu.addItem(withTitle: "Export PDF...", action: #selector(menuExportPDF), keyEquivalent: "e")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(menuUndo), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: "Redo", action: #selector(menuRedo), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Clear Board", action: #selector(menuClearAll), keyEquivalent: "k")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Page Menu
        let pageMenuItem = NSMenuItem()
        let pageMenu = NSMenu(title: "Page")
        let newPage = pageMenu.addItem(withTitle: "New Page", action: #selector(menuNewPage), keyEquivalent: "n")
        newPage.keyEquivalentModifierMask = [.command, .option]
        let dupPage = pageMenu.addItem(withTitle: "Duplicate Page", action: #selector(menuDuplicatePage), keyEquivalent: "d")
        dupPage.keyEquivalentModifierMask = [.command, .option]
        pageMenu.addItem(.separator())
        let nextPage = pageMenu.addItem(withTitle: "Next Page", action: #selector(menuNextPage), keyEquivalent: String(UnicodeScalar(NSRightArrowFunctionKey)!))
        nextPage.keyEquivalentModifierMask = [.command, .option]
        let prevPage = pageMenu.addItem(withTitle: "Previous Page", action: #selector(menuPrevPage), keyEquivalent: String(UnicodeScalar(NSLeftArrowFunctionKey)!))
        prevPage.keyEquivalentModifierMask = [.command, .option]
        pageMenu.addItem(.separator())
        let delPage = pageMenu.addItem(withTitle: "Delete Page", action: #selector(menuDeletePage), keyEquivalent: "\u{08}")
        delPage.keyEquivalentModifierMask = [.command, .option]
        pageMenuItem.submenu = pageMenu
        mainMenu.addItem(pageMenuItem)

        // 5. View Menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(menuResetZoom), keyEquivalent: "0")
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(menuZoomIn), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(menuZoomOut), keyEquivalent: "-")
        viewMenu.addItem(.separator())
        let fullScreen = viewMenu.addItem(withTitle: "Toggle Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 6. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Hirameki Whiteboard"
        alert.informativeText = "A standalone, local, multi-page vector whiteboard with native PDF annotation.\n\nVersion 1.0.0"
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func menuNewBoard() {
        createNewBoard()
    }

    @objc private func menuOpenBoard() {
        currentWindowController?.viewModel.promptOpenDocument()
    }

    @objc private func menuSaveBoard() {
        currentWindowController?.viewModel.promptSaveDocument(saveAs: false)
    }

    @objc private func menuSaveBoardAs() {
        currentWindowController?.viewModel.promptSaveDocument(saveAs: true)
    }

    @objc private func menuInsertPDF() {
        currentWindowController?.viewModel.promptInsertPDF()
    }

    @objc private func menuExportPDF() {
        currentWindowController?.viewModel.promptExportPDF()
    }

    @objc private func menuUndo() {
        currentWindowController?.viewModel.undo()
    }

    @objc private func menuRedo() {
        currentWindowController?.viewModel.redo()
    }

    @objc private func menuClearAll() {
        currentWindowController?.viewModel.clearAll()
    }

    @objc private func menuNewPage() {
        currentWindowController?.viewModel.addPage()
    }

    @objc private func menuDuplicatePage() {
        guard let vm = currentWindowController?.viewModel else { return }
        vm.duplicatePage(at: vm.document.activePageIndex)
    }

    @objc private func menuDeletePage() {
        guard let vm = currentWindowController?.viewModel else { return }
        vm.deletePage(at: vm.document.activePageIndex)
    }

    @objc private func menuNextPage() {
        currentWindowController?.viewModel.nextPage()
    }

    @objc private func menuPrevPage() {
        currentWindowController?.viewModel.prevPage()
    }

    @objc private func menuZoomIn() {
        currentWindowController?.viewModel.zoomIn()
    }

    @objc private func menuZoomOut() {
        currentWindowController?.viewModel.zoomOut()
    }

    @objc private func menuResetZoom() {
        currentWindowController?.viewModel.resetZoom()
    }
}
