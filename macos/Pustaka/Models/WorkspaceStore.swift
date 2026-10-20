import Foundation
import SwiftUI
import Combine

class WorkspaceStore: ObservableObject {
    @Published var categories: [SidebarCategory] = []
    @Published var pages: [DocumentPage] = []
    @Published var selectedPageId: String? = nil
    @Published var agents: [AgentItem] = []
    @Published var currentViewMode: CanvasViewMode = .document
    @Published var isPreviewDrawerPresented: Bool = false
    @Published var engineInfo: String = "Connecting..."
    @Published var currentRon: String = ""
    @Published var currentSvg: String = ""

    init() {
        // Default customizable categories with emojis
        self.categories = [
            SidebarCategory(id: "cat_fav", name: "Favorites", icon: "⭐️", isExpanded: true, showPageCount: true, orderIndex: 0),
            SidebarCategory(id: "cat_agents", name: "ACP Agents", icon: "🤖", isExpanded: true, showPageCount: true, orderIndex: 1, isAgentsCategory: true),
            SidebarCategory(id: "cat_team", name: "Teamspaces", icon: "👥", isExpanded: true, showPageCount: true, orderIndex: 2),
            SidebarCategory(id: "cat_personal", name: "Private", icon: "🔒", isExpanded: true, showPageCount: true, orderIndex: 3)
        ]

        self.pages = [
            DocumentPage(
                id: "doc_architecture",
                title: "Engineering Architecture & Typst Pipeline",
                icon: "cpu.fill",
                categoryId: "cat_fav",
                rawContent: """
                . Engineering Architecture & Typst Pipeline
                .. High-Speed Vector Typesetting for Notion-like Workspaces
                :info All documents are stored as typed RON-RS block trees and compiled in-memory via Typst.
                :warn Zero cloud transmission. Complete offline data privacy.

                ### Core Pipeline
                User Input (PFS / MD) -> Normalizer -> RON Block Tree -> Typst Compiler -> SVG -> SwiftUI

                [grid] Step 1: Normalization | Step 2: In-Memory Typst | Step 3: Native Vector Render [/grid]

                ```rust
                pub fn compile_typst_to_svg(typst_code: &str) -> Result<String, String> {
                    let world = InMemoryWorld::new(typst_code);
                    let doc = typst::compile::<PagedDocument>(&world)?;
                    Ok(typst_svg::svg(&doc.pages()[0], &SvgOptions::default()))
                }
                ```

                , Ultra-low latency < 10ms for typical pages.
                , Cross-platform UniFFI Swift C-ABI bridge.
                """,
                isFavorite: true,
                lastModified: Date(),
                boardTasks: [
                    TaskCard(id: "t1", title: "Implement in-memory Typst SVG compiler", status: .done, tag: "Core", assignee: "Rust Team", priority: .high),
                    TaskCard(id: "t2", title: "Build UniFFI C-ABI bridge for Swift 6", status: .done, tag: "FFI", assignee: "Systems Eng", priority: .high),
                    TaskCard(id: "t3", title: "Design Notion-style macOS Sidebar", status: .inProgress, tag: "UI/UX", assignee: "SwiftUI Dev", priority: .high),
                    TaskCard(id: "t4", title: "Add Drag-and-Drop to Kanban View", status: .inReview, tag: "UI/UX", assignee: "Frontend", priority: .medium),
                    TaskCard(id: "t5", title: "Implement Multi-tab Document Workspace", status: .todo, tag: "Feature", assignee: "Design Team", priority: .low),
                ]
            ),
            DocumentPage(
                id: "doc_sprint",
                title: "Sprint 24: Desktop MVP & ACP Server",
                icon: "bolt.fill",
                categoryId: "cat_fav",
                rawContent: """
                . Sprint 24: Desktop MVP & ACP Server
                .. Deliverables & Weekly Goals
                :tip ACP WebSocket server is active on ws://127.0.0.1:8080.
                :info AI agents can mutate blocks in real-time while user edits.

                ### Objectives
                - Ship Native macOS NavigationSplitView sidebar
                - Enable WYSIWYG inline block edits
                - Interactive Kanban view with task status management

                , ACP protocol handler tested with 100% test pass rate.
                """,
                isFavorite: true,
                lastModified: Date().addingTimeInterval(-3600),
                boardTasks: [
                    TaskCard(id: "t6", title: "Configure Cargo Workspace & Crates", status: .done, tag: "Infra", assignee: "Rust Eng", priority: .high),
                    TaskCard(id: "t7", title: "JSON-RPC 2.0 ACP Server", status: .done, tag: "ACP", assignee: "Tokio Team", priority: .high),
                    TaskCard(id: "t8", title: "Release Build Optimization", status: .inProgress, tag: "Deploy", assignee: "macOS Eng", priority: .medium),
                    TaskCard(id: "t9", title: "Keyboard Shortcut Navigation (Cmd+P)", status: .todo, tag: "UI", assignee: "SwiftUI Dev", priority: .low),
                ]
            ),
            DocumentPage(
                id: "doc_product",
                title: "Product Requirements & Notion Comparison",
                icon: "doc.plaintext.fill",
                categoryId: "cat_team",
                rawContent: """
                . Product Requirements & Notion Comparison
                .. Why Local-First Matters
                :info Traditional SaaS workspaces suffer from 200ms+ network roundtrips.
                :callout Pustaka achieves 60+ FPS locally with native Apple Silicon speed.

                ### Key Advantages
                1. Pure native macOS SwiftUI rendering (no Electron bloat)
                2. Vector-sharp Typst printing & PDF export
                3. First-class AI Agent Communication Protocol (ACP)
                """,
                isFavorite: false,
                lastModified: Date().addingTimeInterval(-86400),
                boardTasks: [
                    TaskCard(id: "t10", title: "Benchmark launch time against Notion Mac", status: .todo, tag: "QA", assignee: "Perf Team", priority: .medium),
                    TaskCard(id: "t11", title: "Write Whitepaper on ACP JSON-RPC", status: .todo, tag: "Docs", assignee: "Product", priority: .low),
                ]
            ),
            DocumentPage(
                id: "doc_personal",
                title: "Daily Notes & Scratchpad",
                icon: "note.text",
                categoryId: "cat_personal",
                rawContent: """
                . Daily Notes & Scratchpad
                .. Quick ideas and reminders
                :tip Press Cmd+N to create a fresh page anytime.

                Remember to test ACP WebSocket ping/pong and verify Typst font rendering.
                """,
                isFavorite: false,
                lastModified: Date().addingTimeInterval(-7200),
                boardTasks: []
            )
        ]

        self.agents = [
            AgentItem(
                id: "agent_antigravity",
                name: "Antigravity Assistant",
                role: "Primary Pair Programmer & Architect",
                status: "Active (ACP Connected)",
                icon: "brain.head.profile",
                endpoint: "ws://127.0.0.1:8080"
            ),
            AgentItem(
                id: "agent_reviewer",
                name: "Doc Reviewer Agent",
                role: "Typo & Typography Consistency",
                status: "Idle",
                icon: "character.magnifyingglass",
                endpoint: "ws://127.0.0.1:8080"
            ),
            AgentItem(
                id: "agent_research",
                name: "Deep Research Subagent",
                role: "Knowledge Base & Docs Indexer",
                status: "Listening",
                icon: "sparkles",
                endpoint: "ws://127.0.0.1:8080"
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
        // Move pages in this category to private
        for i in 0..<pages.count {
            if pages[i].categoryId == id {
                pages[i].categoryId = "cat_personal"
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

    func addNewPage(in categoryId: String = "cat_personal") {
        let newId = "doc_\(UUID().uuidString.prefix(8).lowercased())"
        let newPage = DocumentPage(
            id: newId,
            title: "Untitled Page",
            icon: "doc.text",
            categoryId: categoryId,
            rawContent: ". Untitled Page\n.. Start typing your content here\n:info Press + to add structured blocks.",
            isFavorite: categoryId == "cat_fav",
            lastModified: Date(),
            boardTasks: []
        )
        pages.append(newPage)
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

    func updatePageTitle(_ newTitle: String) {
        guard let id = selectedPageId,
              let idx = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[idx].title = newTitle
        pages[idx].lastModified = Date()
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
        let ron = parsePfsToRon(input: page.rawContent)
        self.currentRon = ron
        let svg = renderRonToSvg(ronStr: ron)
        self.currentSvg = svg
    }

    // Task Board mutation methods
    func addTask(to pageId: String, title: String, status: TaskStatus) {
        guard let idx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        let newTask = TaskCard(
            id: "t_\(UUID().uuidString.prefix(6))",
            title: title,
            status: status,
            tag: "Feature",
            assignee: "You",
            priority: .medium
        )
        pages[idx].boardTasks.append(newTask)
    }

    func updateTaskStatus(pageId: String, taskId: String, newStatus: TaskStatus) {
        guard let pIdx = pages.firstIndex(where: { $0.id == pageId }),
              let tIdx = pages[pIdx].boardTasks.firstIndex(where: { $0.id == taskId }) else { return }
        pages[pIdx].boardTasks[tIdx].status = newStatus
    }

    func deleteTask(pageId: String, taskId: String) {
        guard let pIdx = pages.firstIndex(where: { $0.id == pageId }) else { return }
        pages[pIdx].boardTasks.removeAll { $0.id == taskId }
    }

    // Helper: Convert raw PFS text to UIBlockItem list for WYSIWYG in-place editing
    func parseToUIBlocks(content: String) -> [UIBlockItem] {
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
            } else if trimmed.hasPrefix("[grid]") && trimmed.hasSuffix("[/grid]") {
                let inner = String(trimmed.dropFirst(6).dropLast(7))
                let cols = inner.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                items.append(UIBlockItem(id: "blk_\(counter)", kind: .grid(columns: cols), text: inner))
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

        return items
    }

    // Helper: Convert UIBlockItem list back to PFS string
    func uiBlocksToPfs(blocks: [UIBlockItem]) -> String {
        var lines: [String] = []
        for block in blocks {
            switch block.kind {
            case .heading(let level):
                let prefix = String(repeating: ".", count: level)
                lines.append("\(prefix) \(block.text)")
            case .paragraph:
                lines.append(block.text)
            case .callout(_, let theme):
                switch theme {
                case .blue: lines.append(":info \(block.text)")
                case .red: lines.append(":warn \(block.text)")
                case .green: lines.append(":tip \(block.text)")
                case .standard: lines.append(":callout \(block.text)")
                }
            case .todo:
                lines.append(", \(block.text)")
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
