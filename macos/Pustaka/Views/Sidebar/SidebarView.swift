import SwiftUI
import UniformTypeIdentifiers

// MARK: - Relative Time Formatting Helper

func relativeTimeString(from date: Date) -> String {
    let now = Date()
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 0 { return "Just now" }
    if seconds < 60 {
        return "Just now"
    } else if seconds < 3600 {
        return "\(seconds / 60)m ago"
    } else if seconds < 86400 {
        return "\(seconds / 3600)h ago"
    } else if seconds < 172800 {
        return "Yesterday"
    } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Main Sidebar View

struct SidebarView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var categoryToCustomize: SidebarCategory? = nil
    @State private var isAddingCategory: Bool = false
    @State private var newCategoryName: String = ""

    // Collapsible navigation states
    @State private var isFavoritesExpanded: Bool = true
    @State private var isRecentExpanded: Bool = false
    @State private var isTrashSheetPresented: Bool = false

    var body: some View {
        ZStack {
            // Native macOS Translucent Sidebar Background
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Notion/Obsidian Vault Identity Header
                vaultHeaderView
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                // 2. Minimalist Search Bar (Shortcut: ⌘K)
                searchBarView
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)

                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.35)

                // 3. Main Content: Search Results OR Categorized Vault Tree
                if !searchText.isEmpty {
                    searchResultsView
                } else {
                    vaultNavigationScrollView
                }

                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.35)

                // 4. Bottom Action Bar
                bottomActionBar
                    .padding(.horizontal, 10)
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
        .sheet(isPresented: $isTrashSheetPresented) {
            TrashManagerSheet(
                store: store,
                onDismiss: { isTrashSheetPresented = false }
            )
        }
    }

    // MARK: - Vault Identity Header

    private var vaultHeaderView: some View {
        HStack(spacing: 8) {
            // Vault Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.accentColor.opacity(0.25), radius: 2, y: 1)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Pustaka Vault")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.primary)

                Button(action: {
                    store.revealInFinder()
                }) {
                    HStack(spacing: 3) {
                        Text("~/Documents/Pustaka")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .help("Reveal ~/Documents/Pustaka in Finder (⇧⌘R)")
            }

            Spacer()

            // Quick Vault Action Buttons
            HStack(spacing: 2) {
                Button(action: {
                    store.revealInFinder()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder (⇧⌘R)")
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button(action: {
                    store.addNewPage(in: "cat_notes")
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(5)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("New Document (⌘N)")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    // MARK: - Minimal Search Bar

    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            TextField("Search notes... (⌘K)", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSearchFocused ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .background(
            // Invisible button for ⌘K shortcut to focus search
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        )
    }

    // MARK: - Live Search Results View

    private var searchResultsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 3) {
                let matching = store.activePages.filter { page in
                    page.title.localizedCaseInsensitiveContains(searchText) ||
                    page.rawContent.localizedCaseInsensitiveContains(searchText)
                }

                if matching.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                        Text("No documents matching \"\(searchText)\"")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    HStack {
                        Text("\(matching.count) MATCH\(matching.count == 1 ? "" : "ES")")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    ForEach(matching) { page in
                        SearchResultItemRow(
                            store: store,
                            page: page,
                            isSelected: store.selectedPageId == page.id,
                            searchText: searchText
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Vault Navigation Scroll View

    private var vaultNavigationScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                // Top Pinned Navigation Group (Favorites, Recent, Trash)
                pinnedNavigationGroup

                Divider()
                    .opacity(0.3)
                    .padding(.horizontal, 4)

                // Folders / Categories Section
                foldersSection
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Pinned Navigation Group (Favorites, Recent, Trash)

    private var pinnedNavigationGroup: some View {
        VStack(spacing: 3) {
            // 1. Favorites Collapsible Section
            favoritesPinnedSection

            // 2. Recent Collapsible Section
            recentPinnedSection

            // 3. Trash Section Row
            trashPinnedRow
        }
    }

    // MARK: - Favorites Pinned Section

    private var favoritesPinnedSection: some View {
        VStack(spacing: 2) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isFavoritesExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.yellow)
                        .frame(width: 14)

                    Text("Favorites")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Image(systemName: isFavoritesExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if !store.favoritePages.isEmpty {
                        Text("\(store.favoritePages.count)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isFavoritesExpanded {
                if store.favoritePages.isEmpty {
                    Text("No favorites yet. Star notes to pin them here.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                } else {
                    ForEach(store.favoritePages) { favPage in
                        SidebarDocumentItemRow(
                            store: store,
                            pageId: favPage.id,
                            isSelected: store.selectedPageId == favPage.id,
                            depth: 0
                        )
                    }
                }
            }
        }
    }

    // MARK: - Recent Pinned Section

    private var recentPinnedSection: some View {
        VStack(spacing: 2) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isRecentExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.blue.opacity(0.85))
                        .frame(width: 14)

                    Text("Recent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Image(systemName: isRecentExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Text("\(store.recentPages.count)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isRecentExpanded {
                ForEach(store.recentPages) { recentPage in
                    RecentDocumentRow(
                        store: store,
                        page: recentPage,
                        isSelected: store.selectedPageId == recentPage.id
                    )
                }
            }
        }
    }

    // MARK: - Trash Pinned Row

    private var trashPinnedRow: some View {
        Button(action: {
            isTrashSheetPresented = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: store.trashPages.isEmpty ? "trash" : "trash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(store.trashPages.isEmpty ? Color.secondary.opacity(0.8) : Color.red.opacity(0.85))
                    .frame(width: 14)

                Text("Trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if !store.trashPages.isEmpty {
                    Text("\(store.trashPages.count)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.red.opacity(0.75)))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("View deleted documents (.trash/)")
    }

    // MARK: - Folders / Categories Section

    private var foldersSection: some View {
        VStack(spacing: 8) {
            // Folders Header
            HStack {
                Text("FOLDERS")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.tertiary)

                Spacer()

                Button(action: {
                    isAddingCategory = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .help("Add Folder")
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            // Category Sections
            ForEach(store.sortedCategories.filter { $0.id != "cat_fav" }) { category in
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
                    TextField("Folder name...", text: $newCategoryName)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .onSubmit {
                            commitNewCategory()
                        }

                    Button("Add") {
                        commitNewCategory()
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
                .padding(.horizontal, 6)
            }
        }
    }

    private func commitNewCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.addCategory(name: trimmed, icon: "📁")
            newCategoryName = ""
            isAddingCategory = false
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            Button(action: {
                store.addNewPage(in: "cat_notes")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("New Document")
                        .font(.system(size: 12, weight: .medium))
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
            .help("New Folder")
        }
    }
}

// MARK: - Category Section View (Supports Drag-and-Drop Reorganization)

struct CategorySectionView: View {
    @ObservedObject var store: WorkspaceStore
    let category: SidebarCategory
    let searchText: String
    let onCustomize: () -> Void

    @State private var isHovered: Bool = false
    @State private var isDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            // Category Header with Collapse, Count, and Drop Target
            categoryHeader
                .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
                    guard let provider = providers.first else { return false }
                    _ = provider.loadObject(ofClass: String.self) { string, _ in
                        if let pageId = string {
                            DispatchQueue.main.async {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    store.movePage(id: pageId, toCategory: category.id)
                                }
                            }
                        }
                    }
                    return true
                }

            // Category Items
            if category.isExpanded {
                let pagesToDisplay = store.rootPages(in: category.id)

                ForEach(pagesToDisplay) { page in
                    SidebarDocumentItemRow(
                        store: store,
                        pageId: page.id,
                        isSelected: store.selectedPageId == page.id,
                        depth: 0
                    )
                }

                if pagesToDisplay.isEmpty {
                    Text("Empty folder. Drag notes here.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                }
            }
        }
    }

    private var categoryHeader: some View {
        HStack(spacing: 5) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.16)) {
                    store.toggleCategoryExpanded(id: category.id)
                }
            }) {
                HStack(spacing: 5) {
                    Text(category.icon)
                        .font(.system(size: 12))

                    Text(category.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 10, height: 10)
                }
            }
            .buttonStyle(.plain)

            if category.showPageCount {
                let count = store.pages(in: category.id).count
                Text("\(count)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 2) {
                if isHovered {
                    Button(action: {
                        store.addNewPage(in: category.id)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Add note to \(category.name)")
                }

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
                            category.showPageCount ? "Hide Note Count" : "Show Note Count",
                            systemImage: category.showPageCount ? "checkmark" : "number"
                        )
                    }
                    Divider()
                    Button(action: onCustomize) {
                        Label("Customize (Rename & Emoji)...", systemImage: "pencil.and.outline")
                    }
                    Button(action: { store.addNewPage(in: category.id) }) {
                        Label("New Note in \(category.name)", systemImage: "plus")
                    }
                    if category.id != "cat_notes" {
                        Divider()
                        Button(role: .destructive, action: { store.deleteCategory(id: category.id) }) {
                            Label("Delete Folder", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(isHovered ? Color.primary : Color.clear)
                        .padding(3)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 16)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Individual Document Row (Supports Drag, Inline Rename, Icon Popover, Context Menu)

struct SidebarDocumentItemRow: View {
    @ObservedObject var store: WorkspaceStore
    let pageId: String
    let isSelected: Bool
    var depth: Int = 0

    @State private var isHovered: Bool = false
    @State private var isSubpagesExpanded: Bool = true
    @State private var isRenaming: Bool = false
    @State private var renameTitle: String = ""
    @FocusState private var isRenameFocused: Bool
    @State private var isIconPickerPresented: Bool = false

    private var page: DocumentPage {
        store.pages.first(where: { $0.id == pageId }) ?? DocumentPage(
            id: pageId,
            title: "Untitled",
            icon: "",
            coverUrl: "",
            categoryId: "cat_notes",
            parentPageId: nil,
            rawContent: "",
            isFavorite: false,
            isDeleted: false,
            lastModified: Date(),
            boardTasks: []
        )
    }

    private var subpages: [DocumentPage] {
        store.subpages(of: page.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button(action: {
                if !isRenaming {
                    store.selectPage(id: page.id)
                }
            }) {
                HStack(spacing: 5) {
                    // Tree Indentation
                    if depth > 0 {
                        Spacer()
                            .frame(width: CGFloat(depth * 12))
                    }

                    // Expand / Collapse Chevron for Subpages
                    if !subpages.isEmpty {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isSubpagesExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isSubpagesExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .frame(width: 11, height: 11)
                        }
                        .buttonStyle(.plain)
                    } else if depth > 0 {
                        Circle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 2.5, height: 2.5)
                            .frame(width: 11, height: 11)
                    }

                    // Document Icon
                    if !page.icon.isEmpty {
                        Text(page.icon)
                            .font(.system(size: 12.5))
                            .frame(width: 14)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 11.5))
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.8))
                            .frame(width: 14)
                    }

                    // Title OR Inline Rename TextField
                    if isRenaming {
                        TextField("Document Title", text: $renameTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .focused($isRenameFocused)
                            .onSubmit {
                                commitRename()
                            }
                    } else {
                        Text(page.title.isEmpty ? "Untitled" : page.title)
                            .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(page.title.isEmpty ? .secondary.opacity(0.6) : (isSelected ? Color.primary : Color.primary.opacity(0.85)))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Hover Quick Actions
                    if !isRenaming && (isHovered || isSelected) {
                        HStack(spacing: 3) {
                            // Add Subpage Quick Button
                            Button(action: {
                                store.addNewSubpage(parentPageId: page.id)
                                isSubpagesExpanded = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(2)
                            }
                            .buttonStyle(.plain)
                            .help("Add subpage")

                            // Star / Unstar Favorite
                            Button(action: { store.toggleFavorite(id: page.id) }) {
                                Image(systemName: page.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(page.isFavorite ? Color.yellow : Color.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .help(page.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                            // Context Menu Button
                            Menu {
                                documentContextMenuContent
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 12)
                        }
                    }
                }
                .padding(.vertical, 3.5)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            // Native macOS Drag Provider
            .onDrag {
                NSItemProvider(object: page.id as NSString)
            }
            // Rich Right-Click Context Menu
            .contextMenu {
                documentContextMenuContent
            }
            .popover(isPresented: $isIconPickerPresented, arrowEdge: .trailing) {
                EmojiPickerPopover(
                    currentIcon: page.icon,
                    onSelectEmoji: { emoji in
                        store.updatePageIcon(pageId: page.id, newIcon: emoji)
                        isIconPickerPresented = false
                    },
                    onRemoveIcon: {
                        store.updatePageIcon(pageId: page.id, newIcon: "")
                        isIconPickerPresented = false
                    }
                )
            }

            // Child Subpages (Indented Hierarchy)
            if isSubpagesExpanded && !subpages.isEmpty {
                ForEach(subpages) { child in
                    SidebarDocumentItemRow(
                        store: store,
                        pageId: child.id,
                        isSelected: store.selectedPageId == child.id,
                        depth: depth + 1
                    )
                }
            }
        }
    }

    private func commitRename() {
        let trimmed = renameTitle.trimmingCharacters(in: .whitespaces)
        store.updatePageTitle(pageId: page.id, newTitle: trimmed)
        isRenaming = false
    }

    @ViewBuilder
    private var documentContextMenuContent: some View {
        Button(action: {
            renameTitle = page.title
            isRenaming = true
            isRenameFocused = true
        }) {
            Label("Rename Note", systemImage: "pencil")
        }

        Button(action: {
            isIconPickerPresented = true
        }) {
            Label("Change Icon...", systemImage: "face.smiling")
        }

        Divider()

        Button(action: {
            store.addNewSubpage(parentPageId: page.id)
            isSubpagesExpanded = true
        }) {
            Label("Add Subpage", systemImage: "doc.badge.plus")
        }

        Menu("Move to Folder") {
            ForEach(store.sortedCategories.filter { $0.id != "cat_fav" }) { cat in
                Button(action: {
                    store.movePage(id: page.id, toCategory: cat.id)
                }) {
                    HStack {
                        Text(cat.icon)
                        Text(cat.name)
                        if page.categoryId == cat.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Button(action: {
            store.duplicatePage(id: page.id)
        }) {
            Label("Duplicate Note", systemImage: "plus.square.on.square")
        }

        Divider()

        Button(action: {
            store.toggleFavorite(id: page.id)
        }) {
            Label(
                page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: page.isFavorite ? "star.slash" : "star"
            )
        }

        Button(action: {
            store.revealInFinder(pageId: page.id)
        }) {
            Label("Reveal in Finder", systemImage: "folder")
        }

        Divider()

        Button(role: .destructive, action: {
            store.moveToTrash(id: page.id)
        }) {
            Label("Move to Trash", systemImage: "trash")
        }
    }
}

// MARK: - Recent Document Row

struct RecentDocumentRow: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    let isSelected: Bool

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            store.selectPage(id: page.id)
        }) {
            HStack(spacing: 5) {
                if !page.icon.isEmpty {
                    Text(page.icon)
                        .font(.system(size: 11.5))
                        .frame(width: 14)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.8))
                        .frame(width: 14)
                }

                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 11.5))
                    .foregroundStyle(page.title.isEmpty ? .secondary.opacity(0.6) : (isSelected ? Color.primary : Color.primary.opacity(0.85)))
                    .lineLimit(1)

                Spacer()

                Text(relativeTimeString(from: page.lastModified))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Open Note") {
                store.selectPage(id: page.id)
            }
            Button(page.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                store.toggleFavorite(id: page.id)
            }
            Button("Reveal in Finder") {
                store.revealInFinder(pageId: page.id)
            }
            Divider()
            Button(role: .destructive, action: { store.moveToTrash(id: page.id) }) {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
}

// MARK: - Search Result Item Row

struct SearchResultItemRow: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    let isSelected: Bool
    let searchText: String

    @State private var isHovered: Bool = false

    private var categoryName: String {
        store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
    }

    var body: some View {
        Button(action: {
            store.selectPage(id: page.id)
        }) {
            HStack(spacing: 6) {
                if !page.icon.isEmpty {
                    Text(page.icon)
                        .font(.system(size: 12))
                        .frame(width: 14)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11.5))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 14)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(page.title.isEmpty ? "Untitled" : page.title)
                        .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                        .lineLimit(1)

                    Text(categoryName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(relativeTimeString(from: page.lastModified))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Emoji Picker Popover

struct EmojiPickerPopover: View {
    let currentIcon: String
    let onSelectEmoji: (String) -> Void
    let onRemoveIcon: () -> Void

    private let emojis = [
        "⭐️", "💡", "📝", "🚀", "🔥", "✨", "🎯", "⚡️",
        "📁", "📚", "🎨", "🧩", "💼", "💻", "🏷️", "☕️",
        "📄", "🌲", "🌻", "🍎", "🏖️", "⚽️", "🎹", "📖",
        "💡", "🔍", "📌", "⚙️", "🛠️", "💬", "❤️", "🎉"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select Icon")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !currentIcon.isEmpty {
                    Button("Remove", action: onRemoveIcon)
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 8), spacing: 6) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        onSelectEmoji(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(currentIcon == emoji ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .frame(width: 270)
    }
}

// MARK: - Trash Manager Sheet (Obsidian .trash/ Compatible)

struct TrashManagerSheet: View {
    @ObservedObject var store: WorkspaceStore
    let onDismiss: () -> Void

    @State private var trashSearchText: String = ""
    @State private var isConfirmingEmptyTrash: Bool = false

    private var filteredTrashPages: [DocumentPage] {
        if trashSearchText.isEmpty {
            return store.trashPages
        }
        return store.trashPages.filter { page in
            page.title.localizedCaseInsensitiveContains(trashSearchText) ||
            page.rawContent.localizedCaseInsensitiveContains(trashSearchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Trash")
                        .font(.headline.weight(.semibold))

                    Text("\(store.trashPages.count) items preserved in ~/Documents/Pustaka/.trash/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !store.trashPages.isEmpty {
                    Button(role: .destructive, action: {
                        isConfirmingEmptyTrash = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Empty Trash...")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Filter bar
            if !store.trashPages.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Filter trash...", text: $trashSearchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)

                    if !trashSearchText.isEmpty {
                        Button(action: { trashSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()
            }

            // Trash Content List
            if store.trashPages.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.system(size: 42))
                        .foregroundStyle(.tertiary)
                    Text("Trash is Empty")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Deleted documents will appear here before being permanently destroyed.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTrashPages.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No deleted notes matching \"\(trashSearchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredTrashPages) { page in
                        HStack(spacing: 10) {
                            if !page.icon.isEmpty {
                                Text(page.icon)
                                    .font(.title3)
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(page.title.isEmpty ? "Untitled Note" : page.title)
                                    .font(.system(size: 13, weight: .medium))

                                HStack(spacing: 8) {
                                    Text("Deleted \(relativeTimeString(from: page.lastModified))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)

                                    let catName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
                                    Text("Folder: \(catName)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer()

                            // Restore Button
                            Button(action: {
                                withAnimation {
                                    store.restoreFromTrash(id: page.id)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Restore")
                                }
                                .font(.system(size: 11.5, weight: .medium))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Restore to active notes")

                            // Permanent Delete Button
                            Button(action: {
                                withAnimation {
                                    store.permanentlyDelete(id: page.id)
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.red)
                                    .padding(5)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Permanently delete")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 580, height: 440)
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $isConfirmingEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Empty Trash (\(store.trashPages.count) items)", role: .destructive) {
                store.emptyTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete all \(store.trashPages.count) notes from disk? This cannot be undone.")
        }
    }
}
