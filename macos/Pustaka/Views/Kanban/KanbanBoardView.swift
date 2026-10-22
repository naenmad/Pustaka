import SwiftUI

struct KanbanBoardView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    @State private var newTaskTitles: [TaskStatus: String] = [:]
    @State private var activeAddingStatus: TaskStatus? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(TaskStatus.allCases) { status in
                    KanbanColumnView(
                        store: store,
                        page: page,
                        status: status,
                        tasks: page.boardTasks.filter { $0.status == status },
                        isAddingTask: activeAddingStatus == status,
                        onStartAdd: { activeAddingStatus = status },
                        onCancelAdd: { activeAddingStatus = nil }
                    )
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
    }
}

struct KanbanColumnView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    let status: TaskStatus
    let tasks: [TaskCard]
    let isAddingTask: Bool
    let onStartAdd: () -> Void
    let onCancelAdd: () -> Void

    @State private var newTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column Header
            HStack(spacing: 8) {
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)

                Text(status.rawValue)
                    .font(.subheadline.weight(.semibold))

                Text("\(tasks.count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())

                Spacer()

                Button(action: onStartAdd) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // New Task Inline Input
            if isAddingTask {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Task title...", text: $newTitle)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    HStack(spacing: 8) {
                        Button("Add") {
                            let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty {
                                store.addTask(to: page.id, title: trimmed, status: status)
                                newTitle = ""
                                onCancelAdd()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Cancel") {
                            newTitle = ""
                            onCancelAdd()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(status.color.opacity(0.3), lineWidth: 1)
                )
            }

            // Cards Scroll
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(tasks) { task in
                        KanbanCardView(store: store, pageId: page.id, task: task)
                    }

                    if tasks.isEmpty && !isAddingTask {
                        VStack(spacing: 6) {
                            Image(systemName: "tray")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("No cards")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                }
            }
        }
        .frame(width: 270)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct KanbanCardView: View {
    @ObservedObject var store: WorkspaceStore
    let pageId: String
    let task: TaskCard

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title & Delete
            HStack(alignment: .top) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                Spacer()

                Menu {
                    ForEach(TaskStatus.allCases, id: \.self) { targetStatus in
                        if targetStatus != task.status {
                            Button("Move to \(targetStatus.rawValue)") {
                                store.updateTaskStatus(pageId: pageId, taskId: task.id, newStatus: targetStatus)
                            }
                        }
                    }
                    Divider()
                    Button("Delete Card", role: .destructive) {
                        store.deleteTask(pageId: pageId, taskId: task.id)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
            }

            // Badges & Assignee
            HStack(spacing: 6) {
                Text(task.tag)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appPrimary.opacity(0.12))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(task.priority.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(task.priority.color.opacity(0.12))
                    .foregroundStyle(task.priority.color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(task.assignee.prefix(1)))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        )

                    Text(task.assignee)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
