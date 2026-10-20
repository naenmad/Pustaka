import Foundation
import SwiftUI

// MARK: - Customizable Sidebar Category / Folder

struct SidebarCategory: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var icon: String // Emoji or symbol
    var isExpanded: Bool = true
    var showPageCount: Bool = true
    var orderIndex: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SidebarCategory, rhs: SidebarCategory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Document Page

struct DocumentPage: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var icon: String // Emoji or symbol
    var coverUrl: String // Curated free Unsplash cover image URL
    var categoryId: String // References SidebarCategory.id
    var parentPageId: String? = nil // Optional parent page id for nested subpages
    var rawContent: String
    var isFavorite: Bool
    var lastModified: Date
    var boardTasks: [TaskCard]

    enum CodingKeys: String, CodingKey {
        case id, title, icon, coverUrl, categoryId, parentPageId, rawContent, isFavorite, lastModified, boardTasks
    }

    init(
        id: String,
        title: String,
        icon: String,
        coverUrl: String,
        categoryId: String,
        parentPageId: String? = nil,
        rawContent: String,
        isFavorite: Bool,
        lastModified: Date,
        boardTasks: [TaskCard]
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.coverUrl = coverUrl
        self.categoryId = categoryId
        self.parentPageId = parentPageId
        self.rawContent = rawContent
        self.isFavorite = isFavorite
        self.lastModified = lastModified
        self.boardTasks = boardTasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        icon = try container.decode(String.self, forKey: .icon)
        coverUrl = try container.decode(String.self, forKey: .coverUrl)
        categoryId = try container.decode(String.self, forKey: .categoryId)
        parentPageId = try container.decodeIfPresent(String.self, forKey: .parentPageId)
        rawContent = try container.decode(String.self, forKey: .rawContent)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        boardTasks = try container.decodeIfPresent([TaskCard].self, forKey: .boardTasks) ?? []
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DocumentPage, rhs: DocumentPage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Kanban Board Models

enum TaskStatus: String, CaseIterable, Identifiable, Equatable, Hashable, Codable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case inReview = "In Review"
    case done = "Done"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .todo: return .secondary
        case .inProgress: return .blue
        case .inReview: return .orange
        case .done: return .green
        }
    }

    var icon: String {
        switch self {
        case .todo: return "circle"
        case .inProgress: return "arrow.triangle.2.circlepath.circle.fill"
        case .inReview: return "magnifyingglass.circle.fill"
        case .done: return "checkmark.circle.fill"
        }
    }
}

enum TaskPriority: String, CaseIterable, Codable {
    case high = "High"
    case medium = "Med"
    case low = "Low"

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .secondary
        }
    }
}

struct TaskCard: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var status: TaskStatus
    var tag: String
    var assignee: String
    var priority: TaskPriority
}

// MARK: - View Mode

enum CanvasViewMode: String, CaseIterable, Identifiable {
    case document = "Document"
    case board = "Board / Kanban"
    case preview = "Typst Preview"
    case source = "Source (RON)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .document: return "doc.text"
        case .board: return "square.grid.3x2"
        case .preview: return "sparkles"
        case .source: return "curlybraces"
        }
    }
}

// MARK: - WYSIWYG Block Representation

enum BlockColorTheme: String, CaseIterable {
    case standard = "Default"
    case blue = "Blue"
    case red = "Red"
    case green = "Green"

    var bg: Color {
        switch self {
        case .standard: return Color(nsColor: .controlBackgroundColor).opacity(0.6)
        case .blue: return Color.blue.opacity(0.08)
        case .red: return Color.red.opacity(0.08)
        case .green: return Color.green.opacity(0.08)
        }
    }

    var stroke: Color {
        switch self {
        case .standard: return Color.secondary.opacity(0.3)
        case .blue: return Color.blue
        case .red: return Color.red
        case .green: return Color.green
        }
    }
}

enum UIBlockKind: Equatable {
    case heading(level: Int)
    case paragraph
    case bullet
    case numbered(index: Int)
    case toggle(isExpanded: Bool)
    case quote
    case divider
    case todo(checked: Bool)
    case callout(icon: String, theme: BlockColorTheme)
    case code(lang: String)
    case bookmark(url: String)
    case image(url: String, caption: String)
    case math(expression: String)
    case grid(headers: [String], rows: [[String]])

    var accessibilityName: String {
        switch self {
        case .paragraph: return "Paragraph"
        case .heading(let level): return "Heading \(level)"
        case .bullet: return "Bullet item"
        case .numbered(let idx): return "Numbered item \(idx)"
        case .toggle: return "Toggle list"
        case .quote: return "Quote"
        case .divider: return "Divider"
        case .todo(let checked): return checked ? "Completed task" : "Incomplete task"
        case .callout: return "Callout note"
        case .code(let lang): return "\(lang) code snippet"
        case .bookmark: return "Web bookmark"
        case .image: return "Image block"
        case .math: return "Math equation"
        case .grid: return "Data table"
        }
    }
}

enum BlockActionCommand: Equatable {
    case deleteSelected
    case duplicateSelected
    case transformSelected(UIBlockKind)
    case selectAll
    case clearSelection
    case insertBlock(UIBlockKind)
    case formatActiveBlock(String)
}

struct UIBlockItem: Identifiable, Equatable {
    let id: String
    var kind: UIBlockKind
    var text: String
}

// MARK: - Live Text Formatting State (Bold, Italic, Strikethrough, Code)

struct EditorFormattingState: Equatable {
    var isBold: Bool = false
    var isItalic: Bool = false
    var isStrike: Bool = false
    var isCode: Bool = false
}
