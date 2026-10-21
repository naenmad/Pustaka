import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Single Document Tab Item

struct DocumentTabItemView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    let isSelected: Bool
    var onClose: () -> Void

    @State private var isHovered: Bool = false
    @State private var isCloseHovered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // Document Icon (Emoji or SF Symbol)
            if page.id == WorkspaceStore.trashPageId {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.red.opacity(0.9) : Color.secondary)
            } else if !page.icon.isEmpty {
                Text(page.icon)
                    .font(.system(size: 13))
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }

            // Document Title
            Text(page.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : page.title)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 160, alignment: .leading)

            // Close Tab Button (xmark)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isCloseHovered ? Color.primary : Color.secondary)
                    .frame(width: 16, height: 16)
                    .background(isCloseHovered ? Color.primary.opacity(0.12) : Color.clear)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .opacity((isHovered || isSelected) ? 1.0 : 0.0)
            .onHover { h in isCloseHovered = h }
            .help("Close Tab (⌘W)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? Color.primary.opacity(0.14) : Color.clear, lineWidth: 1)
        )
        .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 1.5, y: 0.5)
        .contentShape(Rectangle())
        .onHover { h in isHovered = h }
        .onTapGesture {
            store.selectPage(id: page.id)
        }
        .contextMenu {
            Button(action: onClose) {
                Label("Close Tab", systemImage: "xmark")
            }
            Button(action: { store.closeOtherTabs(keepPageId: page.id) }) {
                Label("Close Other Tabs", systemImage: "xmark.circle")
            }
            Button(action: { store.closeTabsToRight(pageId: page.id) }) {
                Label("Close Tabs to the Right", systemImage: "arrow.right.to.line")
            }
            Divider()
            if page.id == WorkspaceStore.trashPageId {
                Button(action: { store.revealTrashInFinder() }) {
                    Label("Reveal .trash in Finder", systemImage: "folder")
                }
                if !store.trashPages.isEmpty {
                    Button(role: .destructive, action: {
                        NotificationCenter.default.post(name: NSNotification.Name("PromptEmptyTrash"), object: nil)
                    }) {
                        Label("Empty Trash...", systemImage: "trash")
                    }
                }
            } else {
                Button(action: { store.duplicatePage(id: page.id) }) {
                    Label("Duplicate Tab", systemImage: "plus.square.on.square")
                }
                Divider()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    let title = page.title.isEmpty ? "Untitled" : page.title
                    NSPasteboard.general.setString(title, forType: .string)
                }) {
                    Label("Copy Document Title", systemImage: "text.quote")
                }
                Button(action: { store.revealInFinder(pageId: page.id) }) {
                    Label("Reveal in Finder", systemImage: "folder")
                }
            }
        }
    }
}

// MARK: - Document Tab Bar View (Horizontal Scrollable Strip)

struct DocumentTabBarView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var isHoveringPlus: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(store.openTabs) { page in
                        DocumentTabItemView(
                            store: store,
                            page: page,
                            isSelected: store.selectedPageId == page.id,
                            onClose: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    store.closeTab(pageId: page.id)
                                }
                            }
                        )
                        .id(page.id)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }

                    // "+" New Tab Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.addNewPage()
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(isHoveringPlus ? Color.primary.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in isHoveringPlus = h }
                    .help("New Tab (⌘T)")
                    .padding(.leading, 2)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .onChange(of: store.selectedPageId) { newId, _ in
                if let id = newId {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Native Window Dragging Helper

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }
    func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

class WindowDragNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - Top Document Navigation Bar (Sidebar Toggle, Tab Bar, Share & 3-Dots)

struct TopDocumentNavBarView: View {
    @ObservedObject var store: WorkspaceStore
    var isSidebarHidden: Bool = false

    var currentPage: DocumentPage? {
        store.selectedPage
    }

    var body: some View {
        HStack(spacing: 8) {
            // When sidebar is hidden/collapsed, reserve space for macOS Traffic Lights on the far left
            if isSidebarHidden {
                Spacer()
                    .frame(width: 66)
            }

            // 1. Sidebar Toggle Button (Leading)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
            }) {
                Image(systemName: "sidebar.leading")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Toggle Sidebar (⌃⌘S)")

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            // 2. Horizontal Document Tab Bar
            DocumentTabBarView(store: store)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 3. Trailing Document Actions (Share & 3-Dots Menu)
            if let page = currentPage {
                HStack(spacing: 6) {
                    // Share & Export Menu
                    Menu {
                        Button(action: {
                            _ = store.generateTypstSvg(for: page)
                            store.isPreviewDrawerPresented = true
                        }) {
                            Label("Preview Typst Typesetting...", systemImage: "sparkles")
                        }
                        Divider()
                        Button(action: { exportDocument(page: page, format: "md") }) {
                            Label("Export as Markdown (.md)", systemImage: "arrow.down.doc")
                        }
                        Button(action: { exportDocument(page: page, format: "typ") }) {
                            Label("Export as Typst (.typ)", systemImage: "arrow.down.doc.fill")
                        }
                        Divider()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            let md = "# \(page.title)\n\n\(page.rawContent)"
                            NSPasteboard.general.setString(md, forType: .string)
                        }) {
                            Label("Copy Full Markdown", systemImage: "doc.on.doc")
                        }
                        Button(action: {
                            let svg = store.generateTypstSvg(for: page)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(svg, forType: .string)
                        }) {
                            Label("Copy Typst SVG Vector", systemImage: "sparkle.magnifyingglass")
                        }
                        Divider()
                        Button(action: { store.revealInFinder(pageId: page.id) }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Export & Share Document")

                    // Page Options Menu (Three Dots ...)
                    Menu {
                        Button(action: { store.addNewSubpage(parentPageId: page.id) }) {
                            Label("Add Subpage", systemImage: "doc.badge.plus")
                        }
                        Divider()
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenCoverPicker"), object: nil)
                        }) {
                            Label(page.coverUrl.isEmpty ? "Add Cover" : "Change Cover", systemImage: "photo")
                        }
                        Button(action: {
                            NotificationCenter.default.post(name: NSNotification.Name("OpenIconPicker"), object: nil)
                        }) {
                            Label(page.icon.isEmpty ? "Add Icon" : "Change Icon", systemImage: "face.smiling")
                        }
                        Divider()
                        Button(action: { store.revealInFinder(pageId: page.id) }) {
                            Label("Reveal in Finder", systemImage: "folder")
                        }
                        Divider()
                        Button(action: { store.duplicatePage(id: page.id) }) {
                            Label("Duplicate Page", systemImage: "plus.square.on.square")
                        }
                        Button(action: { store.toggleFavorite(id: page.id) }) {
                            Label(
                                page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: page.isFavorite ? "star.fill" : "star"
                            )
                        }
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            let md = page.title.isEmpty ? "Untitled" : page.title
                            NSPasteboard.general.setString(md, forType: .string)
                        }) {
                            Label("Copy Page Title", systemImage: "text.quote")
                        }
                        Divider()
                        Button(role: .destructive, action: { store.deletePage(id: page.id) }) {
                            Label("Move to Trash", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .help("Page Options")
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(WindowDragView())
    }

    // MARK: - Export Action Helper

    private func exportDocument(page: DocumentPage, format: String) {
        let panel = NSSavePanel()
        panel.title = "Export Document"
        let safeTitle = page.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : page.title
        panel.nameFieldStringValue = "\(safeTitle).\(format)"
        panel.allowedContentTypes = [UTType(filenameExtension: format) ?? .plainText]
        panel.canCreateDirectories = true

        let content: String
        if format == "typ" {
            content = "= \(page.title)\n\n\(page.rawContent)"
        } else {
            content = "# \(page.title)\n\n\(page.rawContent)"
        }

        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
