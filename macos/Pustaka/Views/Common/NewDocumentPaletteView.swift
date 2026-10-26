import SwiftUI

// MARK: - Template Definition

struct DocumentTemplateItem: Identifiable {
    let id: String
    let type: DocumentPageType
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    let searchTerms: [String]
    let defaultTitle: String
    let badgeText: String
}

// MARK: - New Document Command Palette View (Raycast / Spotlight style)

struct NewDocumentPaletteView: View {
    @ObservedObject var store: WorkspaceStore
    @Binding var isPresented: Bool
    var targetCategoryId: String? = nil

    @State private var queryOrTitle: String = ""
    @State private var selectedIndex: Int = 0
    @State private var selectedCategoryId: String = "cat_notes"
    @FocusState private var isFieldFocused: Bool
    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    private var templates: [DocumentTemplateItem] {
        [
            DocumentTemplateItem(
                id: "blank_document",
                type: .document,
                title: "Blank Document",
                subtitle: "Standard writing canvas with Markdown, checklists, tables & code blocks",
                iconName: "doc.text.fill",
                iconColor: primaryColor,
                searchTerms: ["doc", "document", "notes", "blank", "markdown", "text", "normal", "default"],
                defaultTitle: "Untitled Document",
                badgeText: "Note"
            ),
            DocumentTemplateItem(
                id: "kanban_board",
                type: .kanban,
                title: "Kanban Board",
                subtitle: "Visual workflow with To Do, In Progress, and Done cards with drag-and-drop",
                iconName: "square.grid.3x2.fill",
                iconColor: Color.purple,
                searchTerms: ["kanban", "board", "task", "cards", "project", "todo", "workflow", "scrum", "agile"],
                defaultTitle: "Kanban Board",
                badgeText: "Workflow"
            )
        ]
    }

    private var filteredTemplates: [DocumentTemplateItem] {
        let q = queryOrTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return templates
        }

        // Check if query directly matches any search keywords of templates
        let matches = templates.filter { item in
            item.title.localizedCaseInsensitiveContains(q) ||
            item.searchTerms.contains(where: { $0.localizedCaseInsensitiveContains(q) || q.localizedCaseInsensitiveContains($0) })
        }

        if !matches.isEmpty {
            return matches
        }

        // If the query is a custom title (e.g. "Sprint 42" or "Recipe Ideas"), show both templates with title applied
        return templates
    }

    private var currentCategory: SidebarCategory? {
        store.categories.first(where: { $0.id == selectedCategoryId }) ?? store.categories.first
    }

    var body: some View {
        ZStack {
            // 1. Semi-translucent dark blur backdrop
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // 2. Centered Floating Command Palette (Raycast / Spotlight style)
            VStack(spacing: 0) {
                // Search & Title Input Header
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(primaryColor)

                    TextField("Type title or choose template (e.g., Kanban, Notes)...", text: $queryOrTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular))
                        .focused($isFieldFocused)
                        .onSubmit {
                            selectCurrent()
                        }
                        .onChange(of: queryOrTitle) { _, _ in
                            selectedIndex = 0
                        }

                    if !queryOrTitle.isEmpty {
                        Button(action: {
                            queryOrTitle = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // ESC Badge
                    Button(action: {
                        dismiss()
                    }) {
                        Text("esc")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Close palette")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Divider()
                    .opacity(0.2)

                // Subtitle / Title preview indicator if user typed custom title
                let trimmed = queryOrTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let isPureSearch = templates.contains(where: { $0.searchTerms.contains(trimmed.lowercased()) })

                HStack {
                    Text("SELECT TEMPLATE")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if !trimmed.isEmpty && !isPureSearch {
                        HStack(spacing: 4) {
                            Text("Title:")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text("\"\(trimmed)\"")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(primaryColor)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)

                // Template Cards List
                VStack(spacing: 6) {
                    ForEach(Array(filteredTemplates.enumerated()), id: \.element.id) { index, item in
                        templateRow(item: item, isSelected: index == selectedIndex)
                            .onTapGesture {
                                selectedIndex = index
                                selectCurrent()
                            }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                Divider()
                    .opacity(0.2)
                    .padding(.top, 4)

                // Footer Command Bar: Hints on Left, Destination Folder on Right
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 10))
                        Text("Navigate")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)

                    HStack(spacing: 4) {
                        Text("↵")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Create")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)

                    HStack(spacing: 4) {
                        Text("esc")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Text("Dismiss")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.tertiary)

                    Spacer()

                    // Category / Folder Destination Selector
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)

                        Menu {
                            ForEach(store.categories) { cat in
                                Button(action: {
                                    selectedCategoryId = cat.id
                                }) {
                                    HStack {
                                        Text("\(cat.icon) \(cat.name)")
                                        if selectedCategoryId == cat.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentCategory?.name ?? "Notes")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.015))
            }
            .frame(width: 560)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.35), radius: 32, y: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onKeyPress(.downArrow) {
                if selectedIndex < filteredTemplates.count - 1 {
                    selectedIndex += 1
                }
                return .handled
            }
            .onKeyPress(.upArrow) {
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return .handled
            }
            .onKeyPress(.return) {
                selectCurrent()
                return .handled
            }
            .onKeyPress(.escape) {
                dismiss()
                return .handled
            }
        }
        .onAppear {
            if let targetCategoryId = targetCategoryId, !targetCategoryId.isEmpty {
                selectedCategoryId = targetCategoryId
            } else if let pageCat = store.selectedPage?.categoryId {
                selectedCategoryId = pageCat
            } else {
                selectedCategoryId = "cat_notes"
            }
            selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFieldFocused = true
            }
        }
    }

    // MARK: - Template Row

    private func templateRow(item: DocumentTemplateItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Icon Squircle
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.iconColor.opacity(isSelected ? 0.2 : 0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: item.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(item.iconColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(.primary)

                    Text(item.badgeText)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(isSelected ? item.iconColor : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(item.iconColor.opacity(isSelected ? 0.18 : 0.08))
                        .clipShape(Capsule())
                }

                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action Indicator
            if isSelected {
                HStack(spacing: 4) {
                    Text("↵")
                        .font(.system(size: 11, weight: .bold))
                    Text("Create")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(item.iconColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.iconColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? primaryColor.opacity(0.08) : Color.primary.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? primaryColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func selectCurrent() {
        guard !filteredTemplates.isEmpty, selectedIndex < filteredTemplates.count else { return }
        let template = filteredTemplates[selectedIndex]
        let trimmed = queryOrTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        let isSearchWord = template.searchTerms.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame })
        let titleToUse = isSearchWord ? "" : trimmed

        withAnimation(.easeInOut(duration: 0.15)) {
            store.addNewPage(in: selectedCategoryId, type: template.type, title: titleToUse)
        }

        dismiss()
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
            isPresented = false
        }
    }
}
