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
                // Top App Header
                appHeaderView
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Minimalist Search Bar
                searchBarView
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.4)

                // Scrollable Categories / Folders
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
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

                        // Inline New Category Input Box
                        if isAddingCategory {
                            HStack(spacing: 6) {
                                Text("📁")
                                    .font(.subheadline)
                                TextField("Folder / Category Name...", text: $newCategoryName)
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
                    .padding(.vertical, 10)
                }

                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.4)

                // Bottom Minimal Action Bar
                bottomActionBar
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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

    // MARK: - App Header

    private var appHeaderView: some View {
        HStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Pustaka")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: {
                store.addNewPage(in: "cat_notes")
            }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("New Document (Cmd+N)")
        }
    }

    // MARK: - Minimal Search Bar

    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search documents...", text: $searchText)
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
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                store.addNewPage(in: "cat_notes")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                    Text("New Document")
                        .font(.subheadline.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button(action: {
                isAddingCategory = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("New Category / Folder")
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

            // Category Items (Collapsible / expandable)
            if category.isExpanded {
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
                    Text("No documents")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 28)
                        .padding(.vertical, 3)
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
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
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

                    Text(category.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            // Show page count if enabled
            if category.showPageCount {
                let count = store.pages(in: category.id).count
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
                if isHovered {
                    Button(action: {
                        store.addNewPage(in: category.id)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Add document to \(category.name)")
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
                            category.showPageCount ? "Hide Document Count" : "Show Document Count",
                            systemImage: category.showPageCount ? "checkmark" : "number"
                        )
                    }
                    Divider()
                    Button(action: onCustomize) {
                        Label("Customize (Rename & Emoji)...", systemImage: "pencil.and.outline")
                    }
                    Button(action: { store.addNewPage(in: category.id) }) {
                        Label("New Document Here", systemImage: "plus")
                    }
                    if !["cat_fav", "cat_notes"].contains(category.id) {
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

// MARK: - Individual Document Row (Always Simple Document Icon)

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
                // Simple, consistent document icon
                Image(systemName: "doc.text")
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.8))
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
                                .foregroundStyle(page.isFavorite ? Color.yellow : Color.secondary.opacity(0.6))
                        }
                        .buttonStyle(.plain)

                        Menu {
                            Button(page.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                                store.toggleFavorite(id: page.id)
                            }
                            Divider()
                            Button("Delete Document", role: .destructive) {
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
