import Foundation
import SwiftUI
import Combine

class WorkspaceStore: ObservableObject {
    @Published var categories: [SidebarCategory] = []
    @Published var pages: [DocumentPage] = []
    @Published var selectedPageId: String? = nil
    @Published var isPreviewDrawerPresented: Bool = false
    @Published var engineInfo: String = "Ready"
    @Published var currentRon: String = ""
    @Published var currentSvg: String = ""

    init() {
        // Minimal, personal categories / folders
        self.categories = [
            SidebarCategory(id: "cat_fav", name: "Favorites", icon: "⭐️", isExpanded: true, showPageCount: true, orderIndex: 0),
            SidebarCategory(id: "cat_notes", name: "Documents", icon: "📁", isExpanded: true, showPageCount: true, orderIndex: 1)
        ]

        self.pages = [
            DocumentPage(
                id: "doc_welcome",
                title: "Welcome to Pustaka",
                icon: "👋",
                coverUrl: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1400&q=80",
                categoryId: "cat_fav",
                rawContent: """
                . Welcome to Pustaka
                A minimal, ultra-fast local workspace for your thoughts and documents.

                :info Everything here is saved locally. Zero cloud lock-in. Powered by Typst for vector typesetting.

                Hover on the left of any block to add new blocks or drag to reorder.
                """,
                isFavorite: true,
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
                lastModified: Date().addingTimeInterval(-3600),
                boardTasks: []
            )
        ]

        if let first = pages.first {
            self.selectedPageId = first.id
        }

        self.engineInfo = getEngineInfo()
        recompileCurrentPage()
    }

    var sortedCategories: [SidebarCategory] {
        categories.sorted { $0.orderIndex < $1.orderIndex }
    }

    var selectedPage: DocumentPage? {
        get {
            pages.first { $0.id == selectedPageId }
        }
        set {
            if let newValue = newValue,
               let index = pages.firstIndex(where: { $0.id == newValue.id }) {
                pages[index] = newValue
            }
        }
    }

    func selectPage(id: String) {
        self.selectedPageId = id
        recompileCurrentPage()
    }

    func pages(in categoryId: String) -> [DocumentPage] {
        if categoryId == "cat_fav" {
            return pages.filter { $0.isFavorite }
        }
        return pages.filter { $0.categoryId == categoryId }
    }

    // MARK: - Category Management & Customization

    func toggleCategoryExpanded(id: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].isExpanded.toggle()
        }
    }

    func toggleShowPageCount(id: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].showPageCount.toggle()
        }
    }

    func updateCategory(id: String, newName: String, newIcon: String) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].name = newName
            categories[idx].icon = newIcon
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
    }

    func deleteCategory(id: String) {
        for i in 0..<pages.count {
            if pages[i].categoryId == id {
                pages[i].categoryId = "cat_notes"
            }
        }
        categories.removeAll { $0.id == id }
    }

    // MARK: - Page Actions

    func toggleFavorite(id: String) {
        if let idx = pages.firstIndex(where: { $0.id == id }) {
            pages[idx].isFavorite.toggle()
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
        recompileCurrentPage()
    }

    func deletePage(id: String) {
        pages.removeAll { $0.id == id }
        if selectedPageId == id {
            selectedPageId = pages.first?.id
            recompileCurrentPage()
        }
    }

    func updatePageCover(pageId: String, newCoverUrl: String) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        objectWillChange.send()
        pages[idx].coverUrl = newCoverUrl
        pages[idx].lastModified = Date()
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
    }

    func updateTaskStatus(pageId: String, taskId: String, newStatus: TaskStatus) {
        guard let pageIdx = pages.firstIndex(where: { $0.id == pageId }),
              let taskIdx = pages[pageIdx].boardTasks.firstIndex(where: { $0.id == taskId }) else { return }
        pages[pageIdx].boardTasks[taskIdx].status = newStatus
    }

    func deleteTask(pageId: String, taskId: String) {
        guard let pageIdx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        pages[pageIdx].boardTasks.removeAll { $0.id == taskId }
    }

    func updatePageTitle(pageId: String, newTitle: String) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        objectWillChange.send()
        pages[idx].title = newTitle
        pages[idx].lastModified = Date()
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
            if trimmed.isEmpty { continue }

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
            } else if trimmed.hasPrefix(":info ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "💡", theme: .blue), text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix(":warn ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "⚠️", theme: .red), text: String(trimmed.dropFirst(6))))
            } else if trimmed.hasPrefix(":tip ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "✅", theme: .green), text: String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix(":callout ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "💬", theme: .standard), text: String(trimmed.dropFirst(9))))
            } else if trimmed.hasPrefix(", ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .todo(checked: false), text: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("> ") {
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .callout(icon: "💬", theme: .standard), text: String(trimmed.dropFirst(2))))
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

        if items.isEmpty {
            items.append(UIBlockItem(id: "blk_1", kind: .paragraph, text: ""))
        }

        return items
    }

    func uiBlocksToPfs(blocks: [UIBlockItem]) -> String {
        var lines: [String] = []
        for block in blocks {
            let text = block.text.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { continue }

            switch block.kind {
            case .heading(let level):
                let prefix = String(repeating: ".", count: level)
                lines.append("\(prefix) \(text)")
            case .paragraph:
                lines.append(text)
            case .callout(_, let theme):
                switch theme {
                case .blue: lines.append(":info \(text)")
                case .red: lines.append(":warn \(text)")
                case .green: lines.append(":tip \(text)")
                case .standard: lines.append(":callout \(text)")
                }
            case .todo:
                lines.append(", \(text)")
            case .code(let lang):
                lines.append("```\(lang)")
                lines.append(block.text)
                lines.append("```")
            case .grid(let columns):
                lines.append("[grid] \(columns.joined(separator: " | ")) [/grid]")
            }
        }
        return lines.joined(separator: "\n\n")
    }
}
