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

// MARK: - Tree Indentation & Branch Guide Container

struct SidebarTreeContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Subtle vertical tree guide line
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
                .padding(.leading, 12)
                .padding(.trailing, 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 1) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Main Sidebar View

struct SidebarView: View {
    @ObservedObject var store: WorkspaceStore
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @AppStorage("sidebarSortOption") private var sidebarSortOption: SidebarSortOption = .modifiedDesc
    @AppStorage("sidebarFilterOption") private var sidebarFilterOption: SidebarFilterOption = .all
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var categoryToCustomize: SidebarCategory? = nil
    @State private var isAddingCategory: Bool = false
    @State private var newCategoryName: String = ""

    // Collapsible navigation states
    @State private var isFavoritesExpanded: Bool = true
    @State private var isRecentExpanded: Bool = false
    @State private var isTrashHovered: Bool = false
    @State private var isSettingsSheetPresented: Bool = false

    init(store: WorkspaceStore, columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all)) {
        self.store = store
        self._columnVisibility = columnVisibility
    }

    var body: some View {
        ZStack {
            // Solid, elegant neutral macOS gray background (never tints blue in fullscreen)
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Vault Identity Header (Beside macOS Traffic Lights)
                vaultHeaderView

                Divider()
                    .padding(.horizontal, 10)
                    .opacity(0.35)

                // 2. Minimalist Search Bar (Shortcut: ⌘K)
                searchBarView
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
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

                // 4. Bottom Action Bar (New Document, Settings, New Folder)
                bottomActionBar
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .sheet(item: $categoryToCustomize) { cat in
            CustomizeCategorySheet(
                store: store,
                category: cat,
                onDismiss: { categoryToCustomize = nil }
            )
        }
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsSheet(
                store: store,
                onDismiss: { isSettingsSheetPresented = false }
            )
        }
    }

    // MARK: - Vault Header (Beside macOS Traffic Lights)

    private var vaultHeaderView: some View {
        HStack(spacing: 7) {
            // Space reserved for the 3 Traffic Light Buttons (Close, Minimize, Maximize)
            Spacer()
                .frame(width: 70)

            // Vault Badge Icon
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 18, height: 18)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 1, y: 0.5)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Pustaka Vault")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Button(action: {
                    store.revealInFinder()
                }) {
                    HStack(spacing: 2) {
                        Text("~/Documents/Pustaka")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .help("Reveal ~/Documents/Pustaka in Finder (⇧⌘R)")
            }

            Spacer()

            // Quick Reveal in Finder Button
            Button(action: {
                store.revealInFinder()
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder (⇧⌘R)")
        }
        .padding(.trailing, 10)
        .frame(height: 40)
        .background(WindowDragView())
    }

    // MARK: - Minimal Search & Order / Filter Bar

    private var isFilterOrSortCustom: Bool {
        sidebarSortOption != .modifiedDesc || sidebarFilterOption != .all
    }

    private var searchBarView: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                // Main search input field
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

                // Order By & Filter Menu
                filterAndSortMenuButton
            }

            // Active Filter Chip (Visible only when filtering is active)
            if sidebarFilterOption != .all {
                HStack(spacing: 5) {
                    Image(systemName: sidebarFilterOption.icon)
                        .font(.system(size: 9))
                    Text("Filter: \(sidebarFilterOption.label)")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            sidebarFilterOption = .all
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .background(
            // Invisible button for ⌘K shortcut to focus search
            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        )
    }

    private var filterAndSortMenuButton: some View {
        Menu {
            Section("Order By") {
                ForEach(SidebarSortOption.allCases) { option in
                    Button(action: {
                        sidebarSortOption = option
                    }) {
                        HStack {
                            Text(option.label)
                            if sidebarSortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Section("Filter") {
                ForEach(SidebarFilterOption.allCases) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            sidebarFilterOption = filter
                        }
                    }) {
                        HStack {
                            Label(filter.label, systemImage: filter.icon)
                            if sidebarFilterOption == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if isFilterOrSortCustom {
                Divider()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        sidebarSortOption = .modifiedDesc
                        sidebarFilterOption = .all
                    }
                }) {
                    Label("Reset Default", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isFilterOrSortCustom ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isFilterOrSortCustom ? Color.accentColor : Color.secondary)
                    .frame(width: 25, height: 25)
                    .background(isFilterOrSortCustom ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .menuStyle(.borderlessButton)
        .frame(width: 25, height: 25)
        .help("Order By: \(sidebarSortOption.label)\(sidebarFilterOption != .all ? " • Filter: \(sidebarFilterOption.label)" : "")")
    }

    // MARK: - Live Search Results View

    private var searchResultsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 3) {
                let matching = store.activePages.filter { page in
                    (page.title.localizedCaseInsensitiveContains(searchText) ||
                    page.rawContent.localizedCaseInsensitiveContains(searchText)) &&
                    store.pageMatchesFilter(page, filter: sidebarFilterOption)
                }
                let sortedMatching = store.sortPages(matching, by: sidebarSortOption)

                if sortedMatching.isEmpty {
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
                        Text("\(sortedMatching.count) MATCH\(sortedMatching.count == 1 ? "" : "ES") • \(sidebarSortOption.label.uppercased())")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                    ForEach(sortedMatching) { page in
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

    // MARK: - Favorites Pinned Section (With Visible Tree Branches)

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
                let favs = store.sortedFavoritePages(by: sidebarSortOption)
                if favs.isEmpty {
                    Text("No favorites yet. Star notes to pin them here.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                } else {
                    SidebarTreeContainer {
                        ForEach(favs) { favPage in
                            SidebarDocumentItemRow(
                                store: store,
                                pageId: favPage.id,
                                isSelected: store.selectedPageId == favPage.id,
                                depth: 0,
                                sortOption: sidebarSortOption,
                                filterOption: sidebarFilterOption
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Pinned Section (With Visible Tree Branches)

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
                if store.recentPages.isEmpty {
                    Text("No recent notes.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                } else {
                    SidebarTreeContainer {
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
        }
    }

    // MARK: - Trash Pinned Row

    private var trashPinnedRow: some View {
        Button(action: {
            store.openTrash()
        }) {
            HStack(spacing: 6) {
                Image(systemName: store.trashPages.isEmpty ? "trash" : "trash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(store.isShowingTrash ? Color.accentColor : (store.trashPages.isEmpty ? Color.secondary.opacity(0.8) : Color.red.opacity(0.85)))
                    .frame(width: 14)

                Text("Trash")
                    .font(.system(size: 12, weight: store.isShowingTrash ? .semibold : .medium))
                    .foregroundStyle(store.isShowingTrash ? Color.primary : Color.secondary)

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
                    .fill(store.isShowingTrash ? Color.accentColor.opacity(0.14) : (isTrashHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isTrashHovered = $0 }
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
                    sortOption: sidebarSortOption,
                    filterOption: sidebarFilterOption,
                    onCustomize: {
                        categoryToCustomize = category
                    }
                )
            }

            // Inline New Category Input Box
            if isAddingCategory {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            store.addCategory(name: trimmed, icon: "folder")
            newCategoryName = ""
            isAddingCategory = false
        }
    }

    // MARK: - Bottom Action Bar (New Document, Settings, Single Quick Theme Toggle)

    private var isDarkModeActive: Bool {
        if appAppearance == "dark" { return true }
        if appAppearance == "light" { return false }
        return colorScheme == .dark
    }

    private var themeToggleIcon: String {
        isDarkModeActive ? "sun.max.fill" : "moon.fill"
    }

    private var themeToggleTooltip: String {
        isDarkModeActive
            ? "Switch to Light Mode (Right-click for options)"
            : "Switch to Dark Mode (Right-click for options)"
    }

    private func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isDarkModeActive {
                appAppearance = "light"
            } else {
                appAppearance = "dark"
            }
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 6) {
            // Primary Action: New Document
            Button(action: {
                store.addNewPage(in: "cat_notes")
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("New Document")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("⌘N")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            // Secondary Action Row: Settings (⌘,) & Exactly 1 Single Quick Theme Button
            HStack(spacing: 6) {
                Button(action: {
                    isSettingsSheetPresented = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("Settings")
                            .font(.system(size: 11.5, weight: .medium))
                        Spacer()
                        Text("⌘,")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Settings & Vault Preferences (⌘,)")
                .keyboardShortcut(",", modifiers: .command)

                // Exactly ONE single button to change theme mode
                Button(action: {
                    toggleTheme()
                }) {
                    Image(systemName: themeToggleIcon)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(isDarkModeActive ? Color.yellow.opacity(0.9) : Color.primary.opacity(0.75))
                        .frame(width: 28, height: 25)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help(themeToggleTooltip)
                .contextMenu {
                    Button(action: { appAppearance = "light" }) {
                        HStack {
                            Label("Light Mode", systemImage: "sun.max.fill")
                            if appAppearance == "light" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { appAppearance = "dark" }) {
                        HStack {
                            Label("Dark Mode", systemImage: "moon.fill")
                            if appAppearance == "dark" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                    Button(action: { appAppearance = "system" }) {
                        HStack {
                            Label("System Default", systemImage: "circle.lefthalf.filled")
                            if appAppearance == "system" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Category Section View (Supports Drag-and-Drop & Tree Guide Lines)

struct CategorySectionView: View {
    @ObservedObject var store: WorkspaceStore
    let category: SidebarCategory
    let searchText: String
    var sortOption: SidebarSortOption = .modifiedDesc
    var filterOption: SidebarFilterOption = .all
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

            // Category Items with Vertical Tree Guide Lines
            if category.isExpanded {
                let pagesToDisplay = store.filteredAndSortedRootPages(in: category.id, sort: sortOption, filter: filterOption)

                if pagesToDisplay.isEmpty {
                    Text(filterOption == .all ? "Empty folder. Drag notes here." : "No matching notes in folder.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                } else {
                    SidebarTreeContainer {
                        ForEach(pagesToDisplay) { page in
                            SidebarDocumentItemRow(
                                store: store,
                                pageId: page.id,
                                isSelected: store.selectedPageId == page.id,
                                depth: 0,
                                sortOption: sortOption,
                                filterOption: filterOption
                            )
                        }
                    }
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
                    DynamicIconView(icon: category.icon, size: 12, defaultSymbol: "folder")
                        .foregroundStyle(.secondary)

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
                    Image(systemName: "slider.horizontal.3")
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

// MARK: - Individual Document Row (Supports Drag, Inline Rename, Icon Popover, Context Menu, Subpages Tree)

struct SidebarDocumentItemRow: View {
    @ObservedObject var store: WorkspaceStore
    let pageId: String
    let isSelected: Bool
    var depth: Int = 0
    var sortOption: SidebarSortOption = .modifiedDesc
    var filterOption: SidebarFilterOption = .all

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
        store.filteredAndSortedSubpages(of: page.id, sort: sortOption, filter: filterOption)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button(action: {
                if !isRenaming {
                    store.selectPage(id: page.id)
                }
            }) {
                HStack(spacing: 5) {
                    // Tree Indentation (for deeper nested subpages)
                    if depth > 0 {
                        Spacer()
                            .frame(width: CGFloat(depth * 8))
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
                    DynamicIconView(icon: page.icon, size: 12, defaultSymbol: "doc.text")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(width: 14)

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
                                Image(systemName: "slider.horizontal.3")
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
                NativeIconPickerPopover(
                    currentIcon: page.icon,
                    onIconSelected: { icon in
                        store.updatePageIcon(pageId: page.id, newIcon: icon)
                        isIconPickerPresented = false
                    },
                    onRemove: {
                        store.updatePageIcon(pageId: page.id, newIcon: "")
                        isIconPickerPresented = false
                    }
                )
            }

            // Child Subpages (Nested Tree Container)
            if isSubpagesExpanded && !subpages.isEmpty {
                SidebarTreeContainer {
                    ForEach(subpages) { child in
                        SidebarDocumentItemRow(
                            store: store,
                            pageId: child.id,
                            isSelected: store.selectedPageId == child.id,
                            depth: depth + 1,
                            sortOption: sortOption,
                            filterOption: filterOption
                        )
                    }
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
            store.selectPage(id: page.id)
        }) {
            Label("Open Note", systemImage: "doc.text")
        }

        Divider()

        Button(action: {
            store.addNewSubpage(parentPageId: page.id)
            isSubpagesExpanded = true
        }) {
            Label("Add Subpage", systemImage: "doc.badge.plus")
        }

        Button(action: {
            store.selectPage(id: page.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("OpenCoverPicker"), object: nil)
            }
        }) {
            Label(page.coverUrl.isEmpty ? "Add Cover..." : "Change Cover...", systemImage: "photo")
        }

        Button(action: {
            store.selectPage(id: page.id)
            isIconPickerPresented = true
        }) {
            Label(page.icon.isEmpty ? "Add Icon..." : "Change Icon...", systemImage: "sparkles")
        }

        Button(action: {
            renameTitle = page.title
            isRenaming = true
            isRenameFocused = true
        }) {
            Label("Rename Note", systemImage: "pencil")
        }

        Divider()

        Menu("Move to Folder") {
            ForEach(store.sortedCategories.filter { $0.id != "cat_fav" }) { cat in
                Button(action: {
                    store.movePage(id: page.id, toCategory: cat.id)
                }) {
                    let sym = NSImage(systemSymbolName: cat.icon, accessibilityDescription: nil) != nil ? cat.icon : "folder"
                    Label(cat.name, systemImage: sym)
                }
            }
        }

        Button(action: {
            store.duplicatePage(id: page.id)
        }) {
            Label("Duplicate Note", systemImage: "plus.square.on.square")
        }

        Button(action: {
            store.toggleFavorite(id: page.id)
        }) {
            Label(
                page.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                systemImage: page.isFavorite ? "star.slash" : "star"
            )
        }

        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(page.title.isEmpty ? "Untitled" : page.title, forType: .string)
        }) {
            Label("Copy Note Title", systemImage: "text.quote")
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
                DynamicIconView(icon: page.icon, size: 11.5, defaultSymbol: "doc.text")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.8))
                    .frame(width: 14)

                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 11.5))
                    .foregroundStyle(page.title.isEmpty ? .secondary.opacity(0.6) : (isSelected ? Color.primary : Color.primary.opacity(0.85)))
                    .lineLimit(1)

                Spacer()

                Text(relativeTimeString(from: page.lastModified))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
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
                DynamicIconView(icon: page.icon, size: 12, defaultSymbol: "doc.text")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 14)

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

// MARK: - Native macOS Icon Picker Popover (Curated SF Symbols)

typealias NativeEmojiPickerPopover = NativeIconPickerPopover

struct NativeIconPickerPopover: View {
    let currentIcon: String
    let onIconSelected: (String) -> Void
    let onRemove: (() -> Void)?

    @State private var customSymbolText: String = ""

    init(currentIcon: String, onIconSelected: @escaping (String) -> Void, onRemove: (() -> Void)?) {
        self.currentIcon = currentIcon
        self.onIconSelected = onIconSelected
        self.onRemove = onRemove
    }

    // Backwards-compatible init
    init(currentEmoji: String, onEmojiSelected: @escaping (String) -> Void, onRemove: (() -> Void)?) {
        self.currentIcon = currentEmoji
        self.onIconSelected = onEmojiSelected
        self.onRemove = onRemove
    }

    private let symbols = [
        "doc.text", "book.closed", "bookmark", "pencil.and.outline", "note.text", "quote.bubble",
        "terminal", "cpu", "hammer", "wrench.and.screwdriver", "sparkles", "bolt",
        "lightbulb", "flame", "star", "pin", "tag", "flag",
        "folder", "tray", "archivebox", "briefcase", "person.2", "lock"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Select Document Icon")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onRemove = onRemove, !currentIcon.isEmpty {
                    Button(role: .destructive, action: onRemove) {
                        Text("Remove")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Grid of SF Symbols
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(symbols, id: \.self) { sym in
                    let isSelected = currentIcon == sym
                    Button(action: {
                        onIconSelected(sym)
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                )
                            Image(systemName: sym)
                                .font(.system(size: 13))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                        }
                        .frame(height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Custom SF Symbol Input
            HStack(spacing: 6) {
                TextField("Custom SF symbol name...", text: $customSymbolText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit {
                        let trimmed = customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onIconSelected(trimmed)
                        }
                    }

                Button("Set") {
                    let trimmed = customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onIconSelected(trimmed)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(customSymbolText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(10)
        .frame(width: 250)
    }
}



// MARK: - Settings & Workspace Preferences Sheet

struct SettingsSheet: View {
    @ObservedObject var store: WorkspaceStore
    var initialTab: SettingsTab = .appearance
    let onDismiss: () -> Void

    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @AppStorage("sidebarSortOption") private var sidebarSortOption: SidebarSortOption = .modifiedDesc
    @AppStorage("sidebarFilterOption") private var sidebarFilterOption: SidebarFilterOption = .all
    @AppStorage("aiProviderType") private var aiProviderType: String = AIProviderType.antigravity.rawValue
    @AppStorage("aiAgentCliPath") private var aiAgentCliPath: String = ACPAgentService.defaultAgyPath
    @AppStorage("aiAgentModel") private var aiAgentModel: String = "gemini-3.8-flash-high"
    @AppStorage("aiAgentEffort") private var aiAgentEffort: String = "high"
    @AppStorage("claudeCliPath") private var claudeCliPath: String = ACPAgentService.defaultClaudePath
    @AppStorage("claudeCliModel") private var claudeCliModel: String = "claude-3-7-sonnet"
    @AppStorage("geminiCliPath") private var geminiCliPath: String = ACPAgentService.defaultGeminiCliPath
    @AppStorage("geminiCliModel") private var geminiCliModel: String = "gemini-2.5-flash"
    @AppStorage("customAcpPath") private var customAcpPath: String = ""
    @AppStorage("customAcpArgs") private var customAcpArgs: String = "--print {prompt}"
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("geminiModel") private var geminiModel: String = "gemini-2.5-flash"
    @AppStorage("openaiApiKey") private var openaiApiKey: String = ""
    @AppStorage("openaiEndpoint") private var openaiEndpoint: String = "https://api.openai.com/v1"
    @AppStorage("openaiModel") private var openaiModel: String = "gpt-4o"
    @AppStorage("claudeApiKey") private var claudeApiKey: String = ""
    @AppStorage("claudeApiModel") private var claudeApiModel: String = "claude-3-7-sonnet-20250219"

    @State private var selectedTab: SettingsTab = .appearance

    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case ai = "AI & ACP"
        case vault = "Vault & Storage"
        case shortcuts = "Shortcuts"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: return "circle.lefthalf.filled"
            case .ai: return "sparkles"
            case .vault: return "folder.badge.gearshape"
            case .shortcuts: return "command"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Settings & Preferences")
                        .font(.headline.weight(.semibold))
                    Text("Pustaka Workspace Configuration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

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

            // Segmented Tab Picker
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Tab Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .appearance:
                        appearanceSettingsSection
                    case .ai:
                        aiSettingsSection
                    case .vault:
                        vaultSettingsSection
                    case .shortcuts:
                        shortcutsSettingsSection
                    case .about:
                        aboutSettingsSection
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 490)
        .onAppear {
            selectedTab = initialTab
        }
    }

    private var appearanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("THEME & INTERFACE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            HStack(spacing: 12) {
                themeChoiceCard(title: "System", mode: "system", icon: "circle.lefthalf.filled")
                themeChoiceCard(title: "Light", mode: "light", icon: "sun.max.fill")
                themeChoiceCard(title: "Dark", mode: "dark", icon: "moon.fill")
            }

            Text("Choose your preferred visual theme for the Pustaka workspace. System matches your macOS Appearance settings automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Divider().padding(.vertical, 4)

            Text("SIDEBAR & NAVIGATION")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Note Order")
                        .font(.system(size: 12, weight: .medium))
                    Text("Order documents appear in sidebar categories")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $sidebarSortOption) {
                    ForEach(SidebarSortOption.allCases) { opt in
                        Text(opt.label).tag(opt)
                    }
                }
                .frame(width: 170)
            }
        }
    }

    private func themeChoiceCard(title: String, mode: String, icon: String) -> some View {
        let isSelected = appAppearance == mode
        return Button(action: {
            appAppearance = mode
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var aiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI ASSISTANT & ACP PROVIDER")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            // Provider Picker
            Picker("Provider", selection: $aiProviderType) {
                ForEach(AIProviderType.allCases) { p in
                    Label(p.label, systemImage: p.icon).tag(p.rawValue)
                }
            }
            .pickerStyle(.menu)

            Divider().opacity(0.3)

            switch AIProviderType.from(raw: aiProviderType) {
            case .antigravity:
                antigravityConfigSection
            case .claudeCode:
                claudeCodeConfigSection
            case .geminiCli:
                geminiCliConfigSection
            case .customAcp:
                customAcpConfigSection
            case .geminiApi:
                geminiApiConfigSection
            case .openai:
                openAiConfigSection
            case .claudeApi:
                claudeApiConfigSection
            }
        }
    }

    // MARK: - Antigravity ACP Config

    private var antigravityConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isFound = ACPAgentService.resolveExecutablePath(command: "agy", preferredPath: aiAgentCliPath) != nil

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.purple, Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dedicated Antigravity Agent (Local ACP)")
                            .font(.system(size: 12, weight: .bold))
                        Text("Subprocess stream-json protocol via stdio • Zero-config local auth")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isFound ? Color.green : Color.red)
                            .frame(width: 5.5, height: 5.5)
                        Text(isFound ? "Ready" : "Missing")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isFound ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isFound ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("Pustaka communicates with your local Antigravity CLI directly on macOS. Fast, intelligent, and private.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Executable Path
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CLI Executable Path")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button("Auto-Detect") {
                        if let resolved = ACPAgentService.resolveExecutablePath(command: "agy") {
                            aiAgentCliPath = resolved
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }

                TextField("Path to agy binary...", text: $aiAgentCliPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("Default location: ~/.local/bin/agy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Default Model Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Default Model")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $aiAgentModel) {
                    ForEach(AIModelRegistry.models(for: .antigravity)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }

            // Reasoning Effort Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Reasoning Effort")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $aiAgentEffort) {
                    Text("Auto / Inherit").tag("default")
                    Text("Low (Fastest)").tag("low")
                    Text("Medium (Balanced)").tag("medium")
                    Text("High (Deep Thinking)").tag("high")
                    Text("Max (Maximum Intelligence)").tag("max")
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Claude Code CLI Config

    private var claudeCodeConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isFound = ACPAgentService.resolveExecutablePath(command: "claude", preferredPath: claudeCliPath) != nil

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "terminal")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Claude Code CLI Agent")
                            .font(.system(size: 12, weight: .bold))
                        Text("Local subprocess terminal execution")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isFound ? Color.green : Color.red)
                            .frame(width: 5.5, height: 5.5)
                        Text(isFound ? "Ready" : "Missing")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isFound ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isFound ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("Interacts with Anthropic's local CLI assistant on your macOS system.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Claude CLI Path")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button("Auto-Detect") {
                        if let resolved = ACPAgentService.resolveExecutablePath(command: "claude") {
                            claudeCliPath = resolved
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }

                TextField("Path to claude binary...", text: $claudeCliPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $claudeCliModel) {
                    ForEach(AIModelRegistry.models(for: .claudeCode)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Gemini CLI Config

    private var geminiCliConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isFound = ACPAgentService.resolveExecutablePath(command: "gemini", preferredPath: geminiCliPath) != nil

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "command")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Gemini CLI Agent")
                            .font(.system(size: 12, weight: .bold))
                        Text("Official Google Gemini command line utility")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(isFound ? Color.green : Color.red)
                            .frame(width: 5.5, height: 5.5)
                        Text(isFound ? "Ready" : "Missing")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isFound ? Color.green : Color.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isFound ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Gemini CLI Path")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button("Auto-Detect") {
                        if let resolved = ACPAgentService.resolveExecutablePath(command: "gemini") {
                            geminiCliPath = resolved
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                }

                TextField("Path to gemini binary...", text: $geminiCliPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $geminiCliModel) {
                    ForEach(AIModelRegistry.models(for: .geminiCli)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Custom ACP Config

    private var customAcpConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.teal, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Custom Agent Subprocess")
                            .font(.system(size: 12, weight: .bold))
                        Text("Run any custom CLI or ACP script")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Executable Command or Path")
                    .font(.system(size: 11.5, weight: .medium))
                TextField("e.g. /usr/local/bin/my-agent or bun run agent.ts", text: $customAcpPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments Template")
                    .font(.system(size: 11.5, weight: .medium))
                TextField("e.g. --print {prompt}", text: $customAcpArgs)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                Text("{prompt} is replaced with the user query & context")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Direct Google Gemini API Config

    private var geminiApiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let hasKey = !geminiApiKey.trimmingCharacters(in: .whitespaces).isEmpty

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Google Gemini Direct API")
                            .font(.system(size: 12, weight: .bold))
                        Text("Cloud connection via Google AI Studio")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(hasKey ? Color.green : Color.orange)
                            .frame(width: 5.5, height: 5.5)
                        Text(hasKey ? "Key Set" : "No Key")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(hasKey ? Color.green : Color.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(hasKey ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }

                Text("Fast cloud access using your Google AI Studio API key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Gemini API Key")
                    .font(.system(size: 11.5, weight: .medium))
                SecureField("Paste your AI Studio API key...", text: $geminiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))

                Button("Get free API Key from Google AI Studio ↗") {
                    if let url = URL(string: "https://aistudio.google.com/app/apikey") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $geminiModel) {
                    ForEach(AIModelRegistry.models(for: .geminiApi)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - OpenAI / Compatible API Config

    private var openAiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let hasKey = !openaiApiKey.trimmingCharacters(in: .whitespaces).isEmpty
            let isLocal = openaiEndpoint.contains("localhost") || openaiEndpoint.contains("127.0.0.1")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "bolt.circle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("OpenAI / Compatible Endpoint")
                            .font(.system(size: 12, weight: .bold))
                        Text("Supports OpenAI, DeepSeek, Ollama, Groq, OpenRouter")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill((hasKey || isLocal) ? Color.green : Color.orange)
                            .frame(width: 5.5, height: 5.5)
                        Text((hasKey || isLocal) ? "Ready" : "No Key")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle((hasKey || isLocal) ? Color.green : Color.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((hasKey || isLocal) ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Base API Endpoint")
                    .font(.system(size: 11.5, weight: .medium))
                TextField("https://api.openai.com/v1 or http://localhost:11434/v1", text: $openaiEndpoint)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key (leave blank for local Ollama)")
                    .font(.system(size: 11.5, weight: .medium))
                SecureField("Paste API key...", text: $openaiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Identifier")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $openaiModel) {
                    ForEach(AIModelRegistry.models(for: .openai)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Anthropic Claude API Config

    private var claudeApiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let hasKey = !claudeApiKey.trimmingCharacters(in: .whitespaces).isEmpty

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 22, height: 22)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Anthropic Claude Direct API")
                            .font(.system(size: 12, weight: .bold))
                        Text("Direct HTTP connection to api.anthropic.com")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(hasKey ? Color.green : Color.orange)
                            .frame(width: 5.5, height: 5.5)
                        Text(hasKey ? "Key Set" : "No Key")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(hasKey ? Color.green : Color.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(hasKey ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("Anthropic API Key")
                    .font(.system(size: 11.5, weight: .medium))
                SecureField("Paste your Anthropic API key...", text: $claudeApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $claudeApiModel) {
                    ForEach(AIModelRegistry.models(for: .claudeApi)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var vaultSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Vault Location Card
            VStack(alignment: .leading, spacing: 8) {
                Text("VAULT LOCATION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("~/Documents/Pustaka")
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        Text("Standard local Markdown vault with YAML frontmatter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Reveal in Finder") {
                        store.revealInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Vault Statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("WORKSPACE METRICS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    metricCard(title: "Active Notes", value: "\(store.activePages.count)", icon: "doc.text")
                    metricCard(title: "Folders", value: "\(store.categories.count)", icon: "folder")
                    metricCard(title: "In Trash", value: "\(store.trashPages.count)", icon: "trash")
                }
            }

            // Sync Information
            VStack(alignment: .leading, spacing: 6) {
                Text("STORAGE INTEGRITY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Auto-save is active. Every keystroke is saved atomically to disk.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Deleted notes are preserved in ~/.trash/ folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var shortcutsSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KEYBOARD SHORTCUTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            shortcutRow(key: "⌘N", description: "Create new document")
            shortcutRow(key: "⌘K", description: "Focus search bar")
            shortcutRow(key: "⇧⌘R", description: "Reveal vault in Finder")
            shortcutRow(key: "⌘,", description: "Open Settings")
            shortcutRow(key: "⌘J", description: "Toggle AI Assistant panel")
            shortcutRow(key: "⌘B / ⌘I", description: "Format Bold / Italic")
            shortcutRow(key: "⌘D", description: "Duplicate selected block or note")
            shortcutRow(key: "/subpage", description: "Insert inline subpage block")
            shortcutRow(key: "/table", description: "Insert 2D grid table")
            shortcutRow(key: "1. / -", description: "Auto format numbered or bullet list")
        }
    }

    private func shortcutRow(key: String, description: String) -> some View {
        HStack {
            Text(description)
                .font(.system(size: 12))
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
    }

    private var aboutSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APPLICATION")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Pustaka for macOS")
                    .font(.headline.bold())
                Text("Version 1.0 (Build 2026.10)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Zero cloud lock-in. 100% private and offline.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Local-First Architecture")
                    .font(.subheadline.bold())
                Text("Native Swift + AppKit desktop application. Fast, lightweight, and fully offline.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
