import SwiftUI
import AppKit

public struct PageNavigationBar: View {
    @Binding var document: WhiteboardDocument
    var onSelectPage: (Int) -> Void
    var onAddPage: () -> Void
    var onDuplicatePage: (Int) -> Void
    var onDeletePage: (Int) -> Void
    var onRenamePage: (Int, String) -> Void
    var onZoomIn: () -> Void
    var onZoomOut: () -> Void
    var onResetZoom: () -> Void
    var currentZoom: CGFloat

    @State private var showPagesPopover: Bool = false
    @State private var editingPageIndex: Int?
    @State private var editingPageName: String = ""

    public var body: some View {
        HStack(spacing: 8) {
            // MARK: - 1. Page Selector Button (tldraw-style dropdown)
            Button {
                showPagesPopover.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.plaintext")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(document.activePage.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("(\(document.activePageIndex + 1)/\(document.pages.count))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPagesPopover, arrowEdge: .top) {
                pagesListPopover
            }

            // MARK: - 2. Prev / Next Navigation Arrows
            HStack(spacing: 2) {
                Button {
                    if document.activePageIndex > 0 {
                        onSelectPage(document.activePageIndex - 1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(document.activePageIndex > 0 ? .primary : .secondary.opacity(0.4))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(document.activePageIndex <= 0)

                Button {
                    if document.activePageIndex < document.pages.count - 1 {
                        onSelectPage(document.activePageIndex + 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(document.activePageIndex < document.pages.count - 1 ? .primary : .secondary.opacity(0.4))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(document.activePageIndex >= document.pages.count - 1)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )

            // MARK: - 3. Add Page Button Quick Action
            Button {
                onAddPage()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.accentColor)
                    .frame(width: 26, height: 26)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            // MARK: - 4. Zoom Controls
            HStack(spacing: 4) {
                Button {
                    onZoomOut()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)

                Button {
                    onResetZoom()
                } label: {
                    Text("\(Int(round(currentZoom * 100)))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    onZoomIn()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.85))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
        )
    }

    // MARK: - Pages Popover (tldraw-style Page Management Drawer)
    private var pagesListPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PAGES")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(0..<document.pages.count, id: \.self) { idx in
                        let page = document.pages[idx]
                        let isSelected = idx == document.activePageIndex

                        HStack(spacing: 8) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.6))

                            if editingPageIndex == idx {
                                TextField("Page Name", text: $editingPageName, onCommit: {
                                    onRenamePage(idx, editingPageName)
                                    editingPageIndex = nil
                                })
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, weight: .semibold))
                            } else {
                                Text(page.name)
                                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(.primary)

                                Spacer()

                                // Page context actions (Duplicate, Rename, Delete)
                                Menu {
                                    Button {
                                        editingPageIndex = idx
                                        editingPageName = page.name
                                    } label: {
                                        Label("Rename Page", systemImage: "pencil")
                                    }

                                    Button {
                                        onDuplicatePage(idx)
                                    } label: {
                                        Label("Duplicate Page", systemImage: "plus.square.on.square")
                                    }

                                    if document.pages.count > 1 {
                                        Divider()
                                        Button(role: .destructive) {
                                            onDeletePage(idx)
                                        } label: {
                                            Label("Delete Page", systemImage: "trash")
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .frame(width: 18, height: 18)
                                }
                                .menuStyle(.borderlessButton)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editingPageIndex == nil {
                                onSelectPage(idx)
                                showPagesPopover = false
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(maxHeight: 220)

            Divider()

            Button {
                onAddPage()
                showPagesPopover = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("New Page")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 220)
        .padding(.bottom, 6)
    }
}
