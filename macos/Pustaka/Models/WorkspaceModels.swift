import Foundation
import SwiftUI

// MARK: - Customizable Sidebar Category / Folder

struct SidebarCategory: Identifiable, Hashable {
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

struct DocumentPage: Identifiable, Hashable {
    let id: String
    var title: String
    var icon: String // Default to "doc.text", user can customize
    var categoryId: String // References SidebarCategory.id
    var rawContent: String
    var isFavorite: Bool
    var lastModified: Date
    var boardTasks: [TaskCard]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: DocumentPage, rhs: DocumentPage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Kanban Board Models

enum TaskStatus: String, CaseIterable, Identifiable {
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

enum TaskPriority: String, CaseIterable {
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

struct TaskCard: Identifiable, Hashable {
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
    case callout(icon: String, theme: BlockColorTheme)
    case todo(checked: Bool)
    case code(lang: String)
    case grid(columns: [String])
}

struct UIBlockItem: Identifiable, Equatable {
    let id: String
    var kind: UIBlockKind
    var text: String
}
