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
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var categoryToCustomize: SidebarCategory? = nil
    @State private var isAddingCategory: Bool = false
    @State private var newCategoryName: String = ""

    // Collapsible navigation states
    @State private var isFavoritesExpanded: Bool = true
    @State private var isRecentExpanded: Bool = false
    @State private var isTrashSheetPresented: Bool = false
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
                // 1. Minimalist Search Bar (Shortcut: ⌘K)
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
        }
        .background(TitlebarVaultHeaderAccessor(store: store))
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
        .sheet(isPresented: $isSettingsSheetPresented) {
            SettingsSheet(
                store: store,
                onDismiss: { isSettingsSheetPresented = false }
            )
        }
    }

    // MARK: - Native Window Titlebar Identity (Positioned Beside Traffic Lights)

    struct TitlebarVaultIdentityView: View {
        @ObservedObject var store: WorkspaceStore

        var body: some View {
            HStack(spacing: 7) {
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
        }
    }

    struct TitlebarVaultHeaderAccessor: NSViewRepresentable {
        @ObservedObject var store: WorkspaceStore

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                setupHeader(from: view)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                setupHeader(from: nsView)
            }
        }

        private func setupHeader(from view: NSView) {
            guard let window = view.window,
                  let titlebarView = window.standardWindowButton(.closeButton)?.superview else {
                return
            }

            let headerId = NSUserInterfaceItemIdentifier("PustakaVaultTitlebarHeader")
            if titlebarView.subviews.contains(where: { $0.identifier == headerId }) {
                return
            }

            let hostingView = NSHostingView(rootView: TitlebarVaultIdentityView(store: store))
            hostingView.identifier = headerId
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            titlebarView.addSubview(hostingView)

            if let zoomButton = window.standardWindowButton(.zoomButton) {
                NSLayoutConstraint.activate([
                    hostingView.leadingAnchor.constraint(equalTo: zoomButton.trailingAnchor, constant: 10),
                    hostingView.centerYAnchor.constraint(equalTo: zoomButton.centerYAnchor),
                    hostingView.heightAnchor.constraint(equalToConstant: 26)
                ])
            } else {
                NSLayoutConstraint.activate([
                    hostingView.leadingAnchor.constraint(equalTo: titlebarView.leadingAnchor, constant: 75),
                    hostingView.centerYAnchor.constraint(equalTo: titlebarView.centerYAnchor),
                    hostingView.heightAnchor.constraint(equalToConstant: 26)
                ])
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
                if store.favoritePages.isEmpty {
                    Text("No favorites yet. Star notes to pin them here.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 24)
                        .padding(.vertical, 2)
                } else {
                    SidebarTreeContainer {
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

    // MARK: - Bottom Action Bar (New Document, Settings, New Folder)

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

            // Secondary Action Row: Settings & New Folder
            HStack(spacing: 6) {
                Button(action: {
                    isSettingsSheetPresented = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("Settings")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Settings & Vault Preferences (⌘,)")
                .keyboardShortcut(",", modifiers: .command)

                Button(action: {
                    isAddingCategory = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 11))
                        Text("Folder")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Create New Folder")
            }
        }
    }
}

// MARK: - Category Section View (Supports Drag-and-Drop & Tree Guide Lines)

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

            // Category Items with Vertical Tree Guide Lines
            if category.isExpanded {
                let pagesToDisplay = store.rootPages(in: category.id)

                if pagesToDisplay.isEmpty {
                    Text("Empty folder. Drag notes here.")
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
                                depth: 0
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
                NativeEmojiPickerPopover(
                    currentEmoji: page.icon,
                    onEmojiSelected: { emoji in
                        store.updatePageIcon(pageId: page.id, newIcon: emoji)
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
                            depth: depth + 1
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
            Label(page.icon.isEmpty ? "Add Icon..." : "Change Icon...", systemImage: "face.smiling")
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

// MARK: - Native macOS Emoji Picker Popover

struct NativeEmojiPickerPopover: View {
    let currentEmoji: String
    let onEmojiSelected: (String) -> Void
    let onRemove: (() -> Void)?

    @State private var text: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Emoji...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26))
                    .multilineTextAlignment(.center)
                    .frame(width: 46, height: 44)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .focused($isFieldFocused)
                    .onChange(of: text) { _, newText in
                        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let lastChar = trimmed.last {
                            let emoji = String(lastChar)
                            onEmojiSelected(emoji)
                        }
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Button(action: {
                        isFieldFocused = true
                        DispatchQueue.main.async {
                            NSApp.orderFrontCharacterPalette(nil)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "face.smiling")
                            Text("macOS Emoji Palette")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Text("Press ⌃⌘Space or pick an emoji")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            if let onRemove = onRemove, !currentEmoji.isEmpty {
                Divider()
                Button(role: .destructive, action: onRemove) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Remove Icon")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(width: 250)
        .onAppear {
            isFieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.orderFrontCharacterPalette(nil)
            }
        }
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

// MARK: - Settings & Workspace Preferences Sheet

struct SettingsSheet: View {
    @ObservedObject var store: WorkspaceStore
    let onDismiss: () -> Void

    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @State private var selectedTab: SettingsTab = .appearance

    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case vault = "Vault & Storage"
        case shortcuts = "Shortcuts"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: return "circle.lefthalf.filled"
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
        .frame(width: 520, height: 440)
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
