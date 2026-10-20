import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var searchText: String = ""
    @State private var categoryToCustomize: SidebarCategory? = nil
    @State private var isAddingCategory: Bool = false
    @State private var newCategoryName: String = ""

    var body: some View {
        ZStack {
            // Native macOS Translucent Sidebar Background
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Workspace Switcher
                workspaceHeaderView
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // Quick Search Bar
                searchBarView
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 8)
                    .opacity(0.6)

                // Scrollable Category Sections
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(store.sortedCategories) { category in
                            CategorySectionView(
                                store: store,
                                category: category,
                                searchText: searchText,
                                onCustomize: {
                                    categoryToCustomize = category
                                }
                            )
                        }

                        // Inline Add New Category Box
                        if isAddingCategory {
                            HStack(spacing: 6) {
                                Text("📁")
                                    .font(.subheadline)
                                TextField("New Category...", text: $newCategoryName)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline)

                                Button("Add") {
                                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
                                    if !trimmed.isEmpty {
                                        store.addCategory(name: trimmed, icon: "📁")
                                        newCategoryName = ""
                                        isAddingCategory = false
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)

                                Button("Cancel") {
                                    isAddingCategory = false
                                    newCategoryName = ""
                                }
                                .buttonStyle(.plain)
                                .font(.caption2)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.horizontal, 10)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Divider()
                    .padding(.horizontal, 8)
                    .opacity(0.6)

                // Bottom Action Bar
                bottomActionBar
                    .padding(10)
            }
        }
        .sheet(item: $categoryToCustomize) { cat in
            CustomizeCategorySheet(
                store: store,
                category: cat,
                onDismiss: { categoryToCustomize = nil }
            )
        }
    }

    // MARK: - Workspace Header

    private var workspaceHeaderView: some View {
        Menu {
            Button("Personal Workspace") {}
            Button("Engineering & Specs Hub") {}
            Divider()
            Button("Add Category...") {
                isAddingCategory = true
            }
            Button("Workspace Settings...") {}
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 24, height: 24)

                    Text("P")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.tint)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pustaka Workspace")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Local-First • Typst Core")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search or jump to...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                store.addNewPage(in: "cat_personal")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                    Text("New Page")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: { isAddingCategory = true }) {
                    Label("Add New Category...", systemImage: "folder.badge.plus")
                }
                Button(action: { store.isPreviewDrawerPresented.toggle() }) {
                    Label("Toggle Typst Preview (Cmd+P)", systemImage: "sparkles")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.bold())
                    .padding(7)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 26)
        }
    }
}

// MARK: - Collapsible Category Section

struct CategorySectionView: View {
    @ObservedObject var store: WorkspaceStore
    let category: SidebarCategory
    let searchText: String
    let onCustomize: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            // Category Header with Collapse & Customize
            categoryHeader

            // Category Items (Collapsible)
            if category.isExpanded {
                if category.isAgentsCategory {
                    // ACP AI Agents list
                    ForEach(store.agents) { agent in
                        SidebarAgentItemRow(agent: agent)
                    }
                } else {
                    let matchingPages = store.pages(in: category.id).filter { page in
                        searchText.isEmpty ||
                        page.title.localizedCaseInsensitiveContains(searchText) ||
                        page.rawContent.localizedCaseInsensitiveContains(searchText)
                    }

                    ForEach(matchingPages) { page in
                        SidebarDocumentItemRow(
                            store: store,
                            page: page,
                            isSelected: store.selectedPageId == page.id
                        )
                    }

                    if matchingPages.isEmpty {
                        Text("No pages")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 34)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var categoryHeader: some View {
        HStack(spacing: 6) {
            // Chevron to expand/collapse (kecil / besarkan)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggleCategoryExpanded(id: category.id)
                }
            }) {
                Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)

            // Category Icon (Emoji) & Name
            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    store.toggleCategoryExpanded(id: category.id)
                }
            }) {
                HStack(spacing: 5) {
                    Text(category.icon)
                        .font(.caption)

                    Text(category.name.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            // Show page count if enabled
            if category.showPageCount {
                let count = category.isAgentsCategory ? store.agents.count : store.pages(in: category.id).count
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
            }

            Spacer()

            // Hover Controls: "+" and "..." (Three dots) menu
            HStack(spacing: 2) {
                if isHovered && !category.isAgentsCategory {
                    Button(action: {
                        store.addNewPage(in: category.id)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Add page in \(category.name)")
                }

                // Three-dots menu for customizing category
                Menu {
                    Button(action: { store.moveCategoryUp(id: category.id) }) {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                    Button(action: { store.moveCategoryDown(id: category.id) }) {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                    Divider()
                    Button(action: { store.toggleShowPageCount(id: category.id) }) {
                        Label(
                            category.showPageCount ? "Hide Page Count" : "Show Page Count",
                            systemImage: category.showPageCount ? "checkmark" : "number"
                        )
                    }
                    Divider()
                    Button(action: onCustomize) {
                        Label("Customize (Rename & Emoji)...", systemImage: "pencil.and.outline")
                    }
                    if !category.isAgentsCategory {
                        Button(action: { store.addNewPage(in: category.id) }) {
                            Label("Add Page Here", systemImage: "plus")
                        }
                    }
                    if !["cat_fav", "cat_agents", "cat_personal"].contains(category.id) {
                        Divider()
                        Button(role: .destructive, action: { store.deleteCategory(id: category.id) }) {
                            Label("Delete Category", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovered ? Color.primary : Color.clear)
                        .padding(3)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 18)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Individual Document Row

struct SidebarDocumentItemRow: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    let isSelected: Bool

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            store.selectPage(id: page.id)
        }) {
            HStack(spacing: 8) {
                Image(systemName: page.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 14)

                Text(page.title)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                if isHovered || isSelected {
                    HStack(spacing: 4) {
                        Button(action: { store.toggleFavorite(id: page.id) }) {
                            Image(systemName: page.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundStyle(page.isFavorite ? Color.yellow : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button("Open in Tab") {}
                            Button(page.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                store.toggleFavorite(id: page.id)
                            }
                            Divider()
                            Button("Delete Page", role: .destructive) {
                                store.deletePage(id: page.id)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 14)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - ACP Agent Row

struct SidebarAgentItemRow: View {
    let agent: AgentItem
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: agent.icon)
                .font(.system(size: 12))
                .foregroundStyle(.tint)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(agent.role)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Circle()
                .fill(agent.status.contains("Active") ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
                .help("Status: \(agent.status) (\(agent.endpoint))")
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}
