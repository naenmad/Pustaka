import Foundation
import SwiftUI
import Combine

// MARK: - Disk Persistence Container

struct WorkspaceStorageData: Codable {
    var categories: [SidebarCategory]
    var pages: [DocumentPage]
    var selectedPageId: String?
}

class WorkspaceStore: ObservableObject {
    @Published var categories: [SidebarCategory] = []
    @Published var pages: [DocumentPage] = []
    @Published var selectedPageId: String? = nil
    @Published var isPreviewDrawerPresented: Bool = false
    @Published var engineInfo: String = "Ready"
    @Published var currentRon: String = ""
    @Published var currentSvg: String = ""

    init() {
        loadFromDisk()
        self.engineInfo = getEngineInfo()
        recompileCurrentPage()
    }

    // MARK: - Disk Storage Management (Obsidian-Style Vault in ~/Documents/Pustaka/)

    /// The root Obsidian-compatible vault directory in user Documents
    var vaultURL: URL {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pustakaDir = docs.appendingPathComponent("Pustaka", isDirectory: true)
        if !fileManager.fileExists(atPath: pustakaDir.path) {
            try? fileManager.createDirectory(at: pustakaDir, withIntermediateDirectories: true, attributes: nil)
        }
        return pustakaDir
    }

    /// Legacy Application Support URL for automatic seamless migration
    private var legacyStorageURL: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Pustaka", isDirectory: true).appendingPathComponent("workspace.json")
    }

    /// Primary workspace index file stored directly in ~/Documents/Pustaka/workspace.json
    var storageURL: URL {
        vaultURL.appendingPathComponent("workspace.json")
    }

    /// Obsidian-compatible .trash directory inside ~/Documents/Pustaka/.trash/
    var trashURL: URL {
        let trashDir = vaultURL.appendingPathComponent(".trash", isDirectory: true)
        if !FileManager.default.fileExists(atPath: trashDir.path) {
            try? FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true, attributes: nil)
        }
        return trashDir
    }

    /// All active (non-deleted) document pages
    var activePages: [DocumentPage] {
        pages.filter { !$0.isDeleted }
    }

    /// All soft-deleted pages currently residing in the Trash
    var trashPages: [DocumentPage] {
        pages.filter { $0.isDeleted }
    }

    /// Starred active pages for quick 1-click access
    var favoritePages: [DocumentPage] {
        activePages.filter { $0.isFavorite }
    }

    /// Recent active pages sorted by last modified (newest first)
    var recentPages: [DocumentPage] {
        Array(activePages.sorted { $0.lastModified > $1.lastModified }.prefix(8))
    }

    func loadFromDisk() {
        let fileManager = FileManager.default
        let url = storageURL
        var dataToDecode: Data? = nil

        // 1. Try loading from ~/Documents/Pustaka/workspace.json
        if fileManager.fileExists(atPath: url.path),
           let data = try? Data(contentsOf: url) {
            dataToDecode = data
        } else if fileManager.fileExists(atPath: legacyStorageURL.path),
                  let legacyData = try? Data(contentsOf: legacyStorageURL) {
            // 2. Seamlessly migrate from Application Support if existing
            dataToDecode = legacyData
            print("[WorkspaceStore] Migrating legacy workspace from Application Support to ~/Documents/Pustaka/")
        }

        if let data = dataToDecode,
           let decoded = try? JSONDecoder().decode(WorkspaceStorageData.self, from: data),
           !decoded.pages.isEmpty {
            self.categories = decoded.categories.isEmpty ? WorkspaceStore.defaultCategories : decoded.categories
            self.pages = decoded.pages

            // Ensure categories don't have cat_fav as a folder (Favorites has its own pinned group)
            for i in 0..<self.pages.count {
                if self.pages[i].categoryId == "cat_fav" {
                    self.pages[i].categoryId = "cat_notes"
                    self.pages[i].isFavorite = true
                }
            }
            self.categories.removeAll { $0.id == "cat_fav" }

            let nonDeleted = self.pages.filter { !$0.isDeleted }
            if let sel = decoded.selectedPageId, nonDeleted.contains(where: { $0.id == sel }) {
                self.selectedPageId = sel
            } else {
                self.selectedPageId = nonDeleted.first?.id
            }
        } else {
            // Seed initial defaults
            self.categories = WorkspaceStore.defaultCategories
            self.pages = WorkspaceStore.defaultPages
            self.selectedPageId = pages.first?.id
        }

        // Save immediately to ensure ~/Documents/Pustaka and all .md files are written
        saveToDisk()
    }

    func saveToDisk() {
        let storage = WorkspaceStorageData(
            categories: self.categories,
            pages: self.pages,
            selectedPageId: self.selectedPageId
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(storage)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("[WorkspaceStore] Error saving workspace.json: \(error)")
        }

        // Sync individual Markdown (.md) files for Obsidian & Finder access
        syncMarkdownVault()
    }

    // MARK: - Obsidian Vault Markdown Sync

    func safeFileName(for page: DocumentPage) -> String {
        let trimmed = page.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitized = trimmed
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "")
        let base = sanitized.isEmpty ? "Untitled" : sanitized
        return "\(base).md"
    }

    /// Synchronizes all document pages as standard Markdown files (.md) in ~/Documents/Pustaka/ or .trash/
    private func syncMarkdownVault() {
        let vault = vaultURL
        let trash = trashURL
        let isoFormatter = ISO8601DateFormatter()
        let fileManager = FileManager.default

        for page in pages {
            let fileName = safeFileName(for: page)
            let activeFileURL = vault.appendingPathComponent(fileName)
            let trashFileURL = trash.appendingPathComponent(fileName)

            let targetURL = page.isDeleted ? trashFileURL : activeFileURL
            let staleURL = page.isDeleted ? activeFileURL : trashFileURL

            // Clean up stale file from previous state if location changed
            if fileManager.fileExists(atPath: staleURL.path) {
                try? fileManager.removeItem(at: staleURL)
            }

            let categoryName = categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
            let isoDate = isoFormatter.string(from: page.lastModified)

            var md = "---\n"
            md += "id: \"\(page.id)\"\n"
            md += "title: \"\(page.title.replacingOccurrences(of: "\"", with: "\\\""))\"\n"
            if !page.icon.isEmpty {
                md += "icon: \"\(page.icon)\"\n"
            }
            if !page.coverUrl.isEmpty {
                md += "cover: \"\(page.coverUrl)\"\n"
            }
            md += "category: \"\(categoryName)\"\n"
            if let parentId = page.parentPageId {
                md += "parentPageId: \"\(parentId)\"\n"
            }
            md += "isFavorite: \(page.isFavorite)\n"
            md += "isDeleted: \(page.isDeleted)\n"
            md += "lastModified: \"\(isoDate)\"\n"
            md += "---\n\n"

            if !page.title.isEmpty {
                md += "# \(page.title)\n\n"
            }
            md += page.rawContent

            if let data = md.data(using: .utf8) {
                try? data.write(to: targetURL, options: .atomic)
            }
        }
    }

    /// Reveals the vault directory or a specific note file in macOS Finder
    func revealInFinder(pageId: String? = nil) {
        let targetId = pageId ?? selectedPageId
        if let targetId = targetId,
           let page = pages.first(where: { $0.id == targetId }) {
            let targetURL = page.isDeleted ? trashURL.appendingPathComponent(safeFileName(for: page)) : vaultURL.appendingPathComponent(safeFileName(for: page))
            if FileManager.default.fileExists(atPath: targetURL.path) {
                NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                return
            }
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: vaultURL.path)
    }

    // MARK: - Default Seeds

    static var defaultCategories: [SidebarCategory] {
        [
            SidebarCategory(id: "cat_notes", name: "Documents", icon: "📁", isExpanded: true, showPageCount: true, orderIndex: 0)
        ]
    }

    static var defaultPages: [DocumentPage] {
        [
            DocumentPage(
                id: "doc_welcome",
                title: "Welcome to Pustaka",
                icon: "👋",
                coverUrl: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1400&q=80",
                categoryId: "cat_notes",
                rawContent: """
                . Welcome to Pustaka
                A minimal, ultra-fast local workspace for your thoughts and documents.

                :info Everything here is saved locally. Zero cloud lock-in. Powered by Typst for vector typesetting.

                Hover on the left of any block to add new blocks or drag to reorder.
                """,
                isFavorite: true,
                isDeleted: false,
                lastModified: Date(),
                boardTasks: []
            ),
            DocumentPage(
                id: "doc_architecture",
                title: "Architecture & Pipeline",
                icon: "⚡️",
                coverUrl: "",
                categoryId: "cat_notes",
                rawContent: """
                . Architecture & Pipeline
                User Input -> Normalizer -> RON Block Tree -> Typst Compiler -> Vector SVG

                :tip Sub-millisecond rendering running completely in-memory via Rust and Typst.
                """,
                isFavorite: false,
                isDeleted: false,
                lastModified: Date().addingTimeInterval(-3600),
                boardTasks: []
            )
        ]
    }

    var sortedCategories: [SidebarCategory] {
        categories.sorted { $0.orderIndex < $1.orderIndex }
    }

    var selectedPage: DocumentPage? {
        get {
            pages.first { $0.id == selectedPageId && !$0.isDeleted } ?? pages.first { $0.id == selectedPageId }
        }
        set {
            if let newValue = newValue,
               let index = pages.firstIndex(where: { $0.id == newValue.id }) {
                pages[index] = newValue
                saveToDisk()
            }
        }
    }

    func selectPage(id: String) {
        self.selectedPageId = id
        saveToDisk()
        recompileCurrentPage()
    }

    func page(id: String?) -> DocumentPage? {
        guard let id = id else { return nil }
        return pages.first(where: { $0.id == id })
    }

    func pages(in categoryId: String) -> [DocumentPage] {
        if categoryId == "cat_fav" {
            return activePages.filter { $0.isFavorite }
        }
        return activePages.filter { $0.categoryId == categoryId }
    }

    func subpages(of parentPageId: String) -> [DocumentPage] {
        activePages.filter { $0.parentPageId == parentPageId }
    }

    func rootPages(in categoryId: String) -> [DocumentPage] {
        if categoryId == "cat_fav" {
            return activePages.filter { $0.isFavorite }
        }
        return activePages.filter { page in
            guard page.categoryId == categoryId else { return false }
            if let parentId = page.parentPageId, activePages.contains(where: { $0.id == parentId }) {
                return false
            }
            return true
        }
    }

    @discardableResult
    func addNewSubpage(parentPageId: String, title: String = "") -> DocumentPage {
        let parent = page(id: parentPageId)
        let catId = parent?.categoryId ?? "cat_notes"
        let newId = "doc_\(UUID().uuidString.prefix(8).lowercased())"
        let subpage = DocumentPage(
            id: newId,
            title: title,
            icon: "📄",
            coverUrl: "",
            categoryId: catId,
            parentPageId: parentPageId,
            rawContent: "",
            isFavorite: false,
            lastModified: Date(),
            boardTasks: []
        )
        if let idx = pages.firstIndex(where: { $0.id == parentPageId }) {
            pages.insert(subpage, at: idx + 1)
        } else {
            pages.append(subpage)
        }
        self.selectedPageId = newId
        saveToDisk()
        recompileCurrentPage()
        return subpage
    }

    // MARK: - Local Image & Asset Management

    /// Opens an NSOpenPanel to let user pick an image file from disk, copies it into ~/Documents/Pustaka/assets/, and returns the relative path "assets/filename.png"
    func importLocalImageToVault() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .image, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.prompt = "Select Image"
        panel.message = "Choose an image to copy into your Pustaka vault"
        if panel.runModal() == .OK, let selectedUrl = panel.url {
            let assetsDir = vaultURL.appendingPathComponent("assets", isDirectory: true)
            try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)
            let ext = selectedUrl.pathExtension.isEmpty ? "png" : selectedUrl.pathExtension
            let destName = "img_\(UUID().uuidString.prefix(8)).\(ext)"
            let destURL = assetsDir.appendingPathComponent(destName)
            try? FileManager.default.copyItem(at: selectedUrl, to: destURL)
            return "assets/\(destName)"
        }
        return nil
    }

    /// Resolves an image URL or vault-relative path to an absolute file path if existing on disk
    func resolveVaultImagePath(_ pathOrUrl: String) -> String? {
        if pathOrUrl.hasPrefix("assets/") {
            let full = vaultURL.appendingPathComponent(pathOrUrl).path
            if FileManager.default.fileExists(atPath: full) {
                return full
            }
        } else if pathOrUrl.hasPrefix("file://") {
            let path = pathOrUrl.replacingOccurrences(of: "file://", with: "")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        } else if pathOrUrl.hasPrefix("/") {
            if FileManager.default.fileExists(atPath: pathOrUrl) {
                return pathOrUrl
            }
        }
        return nil
    }

    // MARK: - Category Management & Customization

    func toggleCategoryExpanded(id: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].isExpanded.toggle()
            saveToDisk()
        }
    }

    func toggleShowPageCount(id: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].showPageCount.toggle()
            saveToDisk()
        }
    }

    func updateCategory(id: String, newName: String, newIcon: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].name = newName
            categories[idx].icon = newIcon
            saveToDisk()
        }
    }

    func moveCategoryUp(id: String) {
        let sorted = sortedCategories
        guard let currentIdx = sorted.firstIndex(where: { $0.id == id }), currentIdx > 0 else { return }
        let prevItem = sorted[currentIdx - 1]

        if let catIdx = categories.firstIndex(where: { $0.id == id }),
           let prevCatIdx = categories.firstIndex(where: { $0.id == prevItem.id }) {
            let tmp = categories[catIdx].orderIndex
            categories[catIdx].orderIndex = categories[prevCatIdx].orderIndex
            categories[prevCatIdx].orderIndex = tmp
            saveToDisk()
        }
    }

    func moveCategoryDown(id: String) {
        let sorted = sortedCategories
        guard let currentIdx = sorted.firstIndex(where: { $0.id == id }), currentIdx < sorted.count - 1 else { return }
        let nextItem = sorted[currentIdx + 1]

        if let catIdx = categories.firstIndex(where: { $0.id == id }),
           let nextCatIdx = categories.firstIndex(where: { $0.id == nextItem.id }) {
            let tmp = categories[catIdx].orderIndex
            categories[catIdx].orderIndex = categories[nextCatIdx].orderIndex
            categories[nextCatIdx].orderIndex = tmp
            saveToDisk()
        }
    }

    func addCategory(name: String, icon: String) {
        let newId = "cat_\(UUID().uuidString.prefix(6))"
        let maxIndex = categories.map(\.orderIndex).max() ?? 0
        let newCat = SidebarCategory(
            id: newId,
            name: name,
            icon: icon,
            isExpanded: true,
            showPageCount: true,
            orderIndex: maxIndex + 1
        )
        categories.append(newCat)
        saveToDisk()
    }

    func deleteCategory(id: String) {
        for i in 0..<pages.count {
            if pages[i].categoryId == id {
                pages[i].categoryId = "cat_notes"
            }
        }
        categories.removeAll { $0.id == id }
        saveToDisk()
    }

    // MARK: - Page Actions

    func toggleFavorite(id: String) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages[idx].isFavorite.toggle()
            saveToDisk()
        }
    }

    /// Creates a fresh, clean page with NO pre-filled boilerplate text
    func addNewPage(in categoryId: String = "cat_notes") {
        let newId = "doc_\(UUID().uuidString.prefix(8).lowercased())"
        let newPage = DocumentPage(
            id: newId,
            title: "",
            icon: "",
            coverUrl: "",
            categoryId: categoryId,
            rawContent: "",
            isFavorite: categoryId == "cat_fav",
            lastModified: Date(),
            boardTasks: []
        )
        pages.append(newPage)
        self.selectedPageId = newId
        saveToDisk()
        recompileCurrentPage()
    }

    func duplicatePage(id: String) {
        guard let page = pages.first(where: { $0.id == id }) else { return }
        let newId = "doc_\(UUID().uuidString.prefix(8).lowercased())"
        let copy = DocumentPage(
            id: newId,
            title: page.title.isEmpty ? "Copy of Untitled" : "\(page.title) (Copy)",
            icon: page.icon,
            coverUrl: page.coverUrl,
            categoryId: page.categoryId,
            rawContent: page.rawContent,
            isFavorite: page.isFavorite,
            lastModified: Date(),
            boardTasks: page.boardTasks
        )
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages.insert(copy, at: idx + 1)
        } else {
            pages.append(copy)
        }
        self.selectedPageId = newId
        saveToDisk()
        recompileCurrentPage()
    }

    // MARK: - Soft-Delete, Trash & Organization (Obsidian .trash/ compatible)

    /// Soft-deletes a document and its subpages, moving markdown files to ~/Documents/Pustaka/.trash/
    func moveToTrash(id: String) {
        var toTrashIds = Set<String>([id])
        var addedMore = true
        while addedMore {
            addedMore = false
            for p in pages {
                if let parent = p.parentPageId, toTrashIds.contains(parent), !toTrashIds.contains(p.id) {
                    toTrashIds.insert(p.id)
                    addedMore = true
                }
            }
        }

        objectWillChange.send()
        for idx in 0..<pages.count {
            if toTrashIds.contains(pages[idx].id) {
                pages[idx].isDeleted = true
                pages[idx].lastModified = Date()
            }
        }

        // If the active document was trashed, switch selection to next available note
        if let sel = selectedPageId, toTrashIds.contains(sel) {
            selectedPageId = activePages.first?.id
            recompileCurrentPage()
        }

        saveToDisk()
    }

    /// Restores a soft-deleted document and its subpages from Trash back to active notes
    func restoreFromTrash(id: String) {
        var toRestoreIds = Set<String>([id])
        var addedMore = true
        while addedMore {
            addedMore = false
            for p in pages {
                if let parent = p.parentPageId, toRestoreIds.contains(parent), !toRestoreIds.contains(p.id) {
                    toRestoreIds.insert(p.id)
                    addedMore = true
                }
            }
        }

        objectWillChange.send()
        for idx in 0..<pages.count {
            if toRestoreIds.contains(pages[idx].id) {
                pages[idx].isDeleted = false
                pages[idx].lastModified = Date()
            }
        }

        self.selectedPageId = id
        saveToDisk()
        recompileCurrentPage()
    }

    /// Permanently destroys a document and its subpages from disk and memory
    func permanentlyDelete(id: String) {
        var toDeleteIds = Set<String>([id])
        var addedMore = true
        while addedMore {
            addedMore = false
            for p in pages {
                if let parent = p.parentPageId, toDeleteIds.contains(parent), !toDeleteIds.contains(p.id) {
                    toDeleteIds.insert(p.id)
                    addedMore = true
                }
            }
        }

        for delId in toDeleteIds {
            if let page = pages.first(where: { $0.id == delId }) {
                let fileURL = vaultURL.appendingPathComponent(safeFileName(for: page))
                let trashFileURL = trashURL.appendingPathComponent(safeFileName(for: page))
                try? FileManager.default.removeItem(at: fileURL)
                try? FileManager.default.removeItem(at: trashFileURL)
            }
        }

        objectWillChange.send()
        pages.removeAll { toDeleteIds.contains($0.id) }
        if let sel = selectedPageId, toDeleteIds.contains(sel) {
            selectedPageId = activePages.first?.id
            recompileCurrentPage()
        }
        saveToDisk()
    }

    /// Empties the entire trash, permanently deleting all soft-deleted files
    func emptyTrash() {
        let deleted = trashPages
        for page in deleted {
            let fileURL = vaultURL.appendingPathComponent(safeFileName(for: page))
            let trashFileURL = trashURL.appendingPathComponent(safeFileName(for: page))
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: trashFileURL)
        }

        objectWillChange.send()
        pages.removeAll { $0.isDeleted }
        saveToDisk()
    }

    /// Alias for deletePage - redirects safely to moveToTrash
    func deletePage(id: String) {
        moveToTrash(id: id)
    }

    /// Moves a document to a different category/folder (e.g. via drag-and-drop or context menu)
    func movePage(id: String, toCategory categoryId: String) {
        guard let idx = pages.firstIndex(where: { $0.id == id }) else { return }
        objectWillChange.send()
        pages[idx].categoryId = categoryId
        pages[idx].parentPageId = nil // Move to root level of folder
        pages[idx].lastModified = Date()
        saveToDisk()
    }

    func updatePageCover(pageId: String, newCoverUrl: String) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        objectWillChange.send()
        pages[idx].coverUrl = newCoverUrl
        pages[idx].lastModified = Date()
        saveToDisk()
    }

    func updatePageCover(_ newCoverUrl: String) {
        if let id = selectedPageId {
            updatePageCover(pageId: id, newCoverUrl: newCoverUrl)
        }
    }

    // MARK: - Task / Kanban Board Actions

    func addTask(to pageId: String, title: String, status: TaskStatus) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        let newTask = TaskCard(
            id: "tsk_\(UUID().uuidString.prefix(6))",
            title: title,
            status: status,
            tag: "Feature",
            assignee: "Local",
            priority: .medium
        )
        pages[idx].boardTasks.append(newTask)
        saveToDisk()
    }

    func updateTaskStatus(pageId: String, taskId: String, newStatus: TaskStatus) {
        guard let pageIdx = pages.firstIndex(where: { $0.id == pageId }),
              let taskIdx = pages[pageIdx].boardTasks.firstIndex(where: { $0.id == taskId }) else { return }
        pages[pageIdx].boardTasks[taskIdx].status = newStatus
        saveToDisk()
    }

    func deleteTask(pageId: String, taskId: String) {
        guard let pageIdx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        pages[pageIdx].boardTasks.removeAll { $0.id == taskId }
        saveToDisk()
    }

    func updatePageTitle(pageId: String, newTitle: String) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        let oldPage = pages[idx]
        let oldFileName = safeFileName(for: oldPage)
        let oldFileURL = vaultURL.appendingPathComponent(oldFileName)

        objectWillChange.send()
        pages[idx].title = newTitle
        pages[idx].lastModified = Date()

        let newFileName = safeFileName(for: pages[idx])
        if oldFileName != newFileName && FileManager.default.fileExists(atPath: oldFileURL.path) {
            try? FileManager.default.removeItem(at: oldFileURL)
        }

        saveToDisk()
    }

    func updatePageTitle(_ newTitle: String) {
        if let id = selectedPageId {
            updatePageTitle(pageId: id, newTitle: newTitle)
        }
    }

    func updatePageIcon(pageId: String, newIcon: String) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        objectWillChange.send()
        pages[idx].icon = newIcon
        pages[idx].lastModified = Date()
        saveToDisk()
    }

    func updatePageIcon(_ newIcon: String) {
        if let id = selectedPageId {
            updatePageIcon(pageId: id, newIcon: newIcon)
        }
    }

    func updatePageContent(_ newContent: String) {
        guard let id = selectedPageId,
              let idx = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[idx].rawContent = newContent
        pages[idx].lastModified = Date()
        saveToDisk()
        recompileCurrentPage()
    }

    func recompileCurrentPage() {
        guard let page = selectedPage else { return }
        let contentToCompile = page.rawContent.isEmpty ? (page.title.isEmpty ? "" : ". \(page.title)") : page.rawContent
        let ron = parsePfsToRon(input: contentToCompile)
        self.currentRon = ron
        let svg = renderRonToSvg(ronStr: ron)
        self.currentSvg = svg
    }

    // MARK: - Clean Block Parser

    func parseToUIBlocks(content: String) -> [UIBlockItem] {
        let trimmedTotal = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTotal.isEmpty {
            return [UIBlockItem(id: "blk_1", kind: .paragraph, text: "")]
        }

        var items: [UIBlockItem] = []
        var counter = 0
        var inCode = false
        var codeLang = ""
        var codeLines: [String] = []
        var inTable = false
        var tableLines: [String] = []

        func flushTable() {
            guard inTable, !tableLines.isEmpty else { return }
            inTable = false
            counter += 1
            var parsedHeaders: [String] = []
            var parsedRows: [[String]] = []

            for (idx, tLine) in tableLines.enumerated() {
                let cells = tLine.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                var cleanCells = cells
                if cleanCells.first == "" { cleanCells.removeFirst() }
                if cleanCells.last == "" { cleanCells.removeLast() }

                if idx == 0 {
                    parsedHeaders = cleanCells.isEmpty ? ["Column 1", "Column 2"] : cleanCells
                } else if idx == 1 && cleanCells.allSatisfy({ $0.contains("-") }) {
                    continue
                } else {
                    parsedRows.append(cleanCells)
                }
            }

            if parsedHeaders.isEmpty {
                parsedHeaders = ["Column 1", "Column 2", "Column 3"]
            }
            if parsedRows.isEmpty {
                parsedRows = [Array(repeating: "", count: parsedHeaders.count)]
            }

            items.append(UIBlockItem(
                id: "blk_\(counter)",
                kind: .grid(headers: parsedHeaders, rows: parsedRows),
                text: tableLines.joined(separator: "\n")
            ))
            tableLines.removeAll()
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmedStart = line.trimmingCharacters(in: .whitespaces)

            if trimmedStart.hasPrefix("```") {
                if !inCode {
                    inCode = true
                    codeLang = String(trimmedStart.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLines.removeAll()
                } else {
                    inCode = false
                    counter += 1
                    items.append(UIBlockItem(
                        id: "blk_\(counter)",
                        kind: .code(lang: codeLang.isEmpty ? "text" : codeLang),
                        text: codeLines.joined(separator: "\n")
                    ))
                }
                continue
            }

            if inCode {
                codeLines.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if inTable { flushTable() }
                continue
            }

            if trimmed.hasPrefix("|") && trimmed.contains("|") {
                inTable = true
                tableLines.append(trimmed)
                continue
            } else if inTable {
                flushTable()
            }

            counter += 1
            if trimmed.hasPrefix("... ") || trimmed.hasPrefix("### ") {
                let rest = String(trimmed.dropFirst(4))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .heading(level: 3), text: rest))
            } else if trimmed.hasPrefix(".. ") || trimmed.hasPrefix("## ") {
                let rest = String(trimmed.dropFirst(3))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .heading(level: 2), text: rest))
            } else if trimmed.hasPrefix(". ") || trimmed.hasPrefix("# ") {
                let rest = String(trimmed.dropFirst(2))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .heading(level: 1), text: rest))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let rest = String(trimmed.dropFirst(2))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .bullet, text: rest))
            } else if trimmed.hasPrefix("1. ") {
                let rest = String(trimmed.dropFirst(3))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .numbered(index: 1), text: rest))
            } else if trimmed.hasPrefix(">> ") {
                let rest = String(trimmed.dropFirst(3))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .toggle(isExpanded: false), text: rest))
            } else if trimmed == "---" || trimmed == "___" {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .divider, text: ""))
            } else if trimmed.hasPrefix("> ") {
                let rest = String(trimmed.dropFirst(2))
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .quote, text: rest))
            } else if trimmed.hasPrefix("[bookmark] ") {
                let rest = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces)
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .bookmark(url: rest), text: rest))
            } else if trimmed.hasPrefix("![") && trimmed.contains("](") && trimmed.hasSuffix(")") {
                // Markdown image: ![caption](url)
                if let closeBracket = trimmed.firstIndex(of: "]"),
                   let openParen = trimmed.range(of: "](", range: closeBracket..<trimmed.endIndex) {
                    let caption = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
                    let url = String(trimmed[openParen.upperBound..<trimmed.index(before: trimmed.endIndex)])
                    items.append(UIBlockItem(id: "blk_\(counter)", kind: .image(url: url, caption: caption), text: caption))
                } else {
                    items.append(UIBlockItem(id: "blk_\(counter)", kind: .paragraph, text: trimmed))
                }
            } else if trimmed.hasPrefix("$$") && trimmed.hasSuffix("$$") && trimmed.count >= 4 {
                let expr = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .math(expression: expr), text: expr))
            } else if trimmed.hasPrefix("[grid]") && trimmed.hasSuffix("[/grid]") {
                let inner = String(trimmed.dropFirst(6).dropLast(7))
                let cols = inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                let headers = cols.isEmpty ? ["Column 1", "Column 2", "Column 3"] : cols
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .grid(headers: headers, rows: [Array(repeating: "", count: headers.count)]), text: inner))
            } else if trimmed.hasPrefix(":info ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "💡", theme: .blue), text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix(":warn ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "⚠️", theme: .red), text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix(":tip ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "✅", theme: .green), text: String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix(":idea ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "🎯", theme: .standard), text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix("[subpage] ") {
                let subId = String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces)
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .subpage(pageId: subId), text: ""))
            } else if trimmed.hasPrefix(":callout ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "💬", theme: .standard), text: String(trimmed.dropFirst(9))))
            } else if trimmed.hasPrefix(", ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .todo(checked: false), text: String(trimmed.dropFirst(2))))
            } else {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .paragraph, text: trimmed))
            }
        }

        if inCode {
            counter += 1
            items.append(UIBlockItem(
                id: "blk_\(counter)",
                kind: .code(lang: codeLang.isEmpty ? "text" : codeLang),
                text: codeLines.joined(separator: "\n")
            ))
        }

        if inTable {
            flushTable()
        }

        if items.isEmpty {
            items.append(UIBlockItem(id: "blk_1", kind: .paragraph, text: ""))
        }

        return items
    }

    func uiBlocksToPfs(blocks: [UIBlockItem]) -> String {
        var lines: [String] = []
        for block in blocks {
            let text = block.text.trimmingCharacters(in: .whitespaces)

            switch block.kind {
            case .heading(let level):
                if !text.isEmpty {
                    let prefix = String(repeating: ".", count: level)
                    lines.append("\(prefix) \(text)")
                }
            case .paragraph:
                if !text.isEmpty {
                    lines.append(text)
                }
            case .bullet:
                if !text.isEmpty {
                    lines.append("- \(text)")
                }
            case .numbered(let idx):
                if !text.isEmpty {
                    lines.append("\(idx). \(text)")
                }
            case .toggle:
                if !text.isEmpty {
                    lines.append(">> \(text)")
                }
            case .quote:
                if !text.isEmpty {
                    lines.append("> \(text)")
                }
            case .divider:
                lines.append("---")
            case .bookmark(let url):
                let validUrl = url.trimmingCharacters(in: .whitespaces)
                if !validUrl.isEmpty {
                    lines.append("[bookmark] \(validUrl)")
                } else if !text.isEmpty {
                    lines.append("[bookmark] \(text)")
                }
            case .image(let url, let caption):
                let cap = caption.isEmpty ? text : caption
                if !url.isEmpty {
                    lines.append("![\(cap)](\(url))")
                }
            case .math(let expression):
                let expr = expression.isEmpty ? text : expression
                if !expr.isEmpty {
                    lines.append("$$ \(expr) $$")
                }
            case .callout(_, let theme):
                if !text.isEmpty {
                    switch theme {
                    case .blue: lines.append(":info \(text)")
                    case .red: lines.append(":warn \(text)")
                    case .green: lines.append(":tip \(text)")
                    case .standard: lines.append(":callout \(text)")
                    }
                }
            case .todo:
                if !text.isEmpty {
                    lines.append(", \(text)")
                }
            case .code(let lang):
                lines.append("```\(lang)")
                lines.append(block.text)
                lines.append("```")
            case .grid(let headers, let rows):
                var tLines: [String] = []
                let cleanHeaders = headers.isEmpty ? ["Column 1", "Column 2"] : headers
                let hLine = "| " + cleanHeaders.joined(separator: " | ") + " |"
                let sLine = "| " + cleanHeaders.map { _ in "---" }.joined(separator: " | ") + " |"
                tLines.append(hLine)
                tLines.append(sLine)
                for r in rows {
                    var padded = r
                    while padded.count < cleanHeaders.count { padded.append("") }
                    tLines.append("| " + padded.prefix(cleanHeaders.count).joined(separator: " | ") + " |")
                }
                lines.append(tLines.joined(separator: "\n"))
            case .subpage(let pageId):
                lines.append("[subpage] \(pageId)")
            }
        }
        return lines.joined(separator: "\n\n")
    }
}
