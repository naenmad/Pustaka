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
    @Binding var isQuickSearchPresented: Bool
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("sidebarFontSize") private var sidebarFontSize: Double = 14.0
    @AppStorage("appUiScale") private var appUiScale: Double = 1.0
    @AppStorage("sidebarSortOption") private var sidebarSortOption: SidebarSortOption = .modifiedDesc
    @AppStorage("sidebarFilterOption") private var sidebarFilterOption: SidebarFilterOption = .all

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    @State private var categoryToCustomize: SidebarCategory? = nil
    @State private var isAddingCategory: Bool = false
    @State private var newCategoryName: String = ""

    // Drag-and-drop & interaction states
    @State private var isFavoritesDropTargeted: Bool = false
    @State private var isTrashDropTargeted: Bool = false
    @State private var isTrashHovered: Bool = false
    @State private var isSearchBtnHovered: Bool = false
    @State private var isSettingsSheetPresented: Bool = false
    @State private var isFullScreen: Bool = false

    init(
        store: WorkspaceStore,
        columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all),
        isQuickSearchPresented: Binding<Bool> = .constant(false)
    ) {
        self.store = store
        self._columnVisibility = columnVisibility
        self._isQuickSearchPresented = isQuickSearchPresented
    }

    var body: some View {
        ZStack {
            // Elegant neutral macOS window background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Vault Identity Header (Beside macOS Traffic Lights)
                vaultHeaderView
                    .padding(.bottom, 2)

                // 2. Modern Quick Search Trigger Bar (Command Palette ⌘K)
                quickSearchTriggerBar
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)

                // 3. Main Navigation Tree Scroll View
                vaultNavigationScrollView

                // 4. Dedicated Trash Drop Zone (Anchored at Bottom)
                trashPinnedRow
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                // 5. Bottom Action Bar (New Document, Settings, Theme)
                bottomActionBar
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            isFullScreen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            isFullScreen = false
        }
    }

    // MARK: - Vault Header (Beside macOS Traffic Lights)

    private var vaultHeaderView: some View {
        HStack(spacing: 8) {
            // Space reserved for the 3 Traffic Light Buttons only in windowed mode
            if !isFullScreen {
                Spacer()
                    .frame(width: 70)
            } else {
                Spacer()
                    .frame(width: 12)
            }

            // App Brand Logo
            if let logoImg = NSImage(named: "AppLogo") ?? Bundle.main.url(forResource: "AppLogo", withExtension: "png").flatMap({ NSImage(contentsOf: $0) }) ?? NSApplication.shared.applicationIconImage {
                Image(nsImage: logoImg)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26 * appUiScale, height: 26 * appUiScale)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * appUiScale, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [primaryColor, primaryColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22 * appUiScale, height: 22 * appUiScale)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 11 * appUiScale, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Pustaka")
                    .font(.system(size: 15 * appUiScale, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Button(action: {
                    store.revealInFinder()
                }) {
                    HStack(spacing: 3) {
                        Text("~/Documents/Pustaka")
                            .font(.system(size: 11 * appUiScale, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 9 * appUiScale))
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Reveal in Finder (⇧⌘R)")
        }
        .padding(.trailing, 10)
        .frame(height: 46 * appUiScale)
        .background(WindowDragView())
    }

    // MARK: - Quick Search Trigger Bar (Command Palette ⌘K & Filter Menu)

    private var isFilterOrSortCustom: Bool {
        sidebarSortOption != .modifiedDesc || sidebarFilterOption != .all
    }

    private var quickSearchTriggerBar: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                    isQuickSearchPresented = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("Quick Search...")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("⌘K")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7.5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(isSearchBtnHovered ? 0.07 : 0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .onHover { isSearchBtnHovered = $0 }
            .help("Spotlight Search Notes (⌘K)")

            filterAndSortMenuButton
        }
    }

    private var filterAndSortMenuButton: some View {
        Menu {
            Picker("Order By", selection: $sidebarSortOption) {
                ForEach(SidebarSortOption.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option)
                }
            }

            Divider()

            Picker("Filter", selection: $sidebarFilterOption) {
                ForEach(SidebarFilterOption.allCases) { filter in
                    Label(filter.label, systemImage: filter.icon).tag(filter)
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
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(isFilterOrSortCustom ? primaryColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(isFilterOrSortCustom ? primaryColor.opacity(0.12) : Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                if isFilterOrSortCustom {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 5.5, height: 5.5)
                        .offset(x: -2, y: 2)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28, height: 28)
        .help("Order By: \(sidebarSortOption.label)\(sidebarFilterOption != .all ? " • Filter: \(sidebarFilterOption.label)" : "")")
    }

    // MARK: - Vault Navigation Scroll View

    private var vaultNavigationScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // 1. Pinned Favorites Quick Access Group
                favoritesPinnedSection

                // 2. Workspaces & Documents Tree
                foldersSection
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
        }
    }

    // MARK: - Favorites Pinned Section (With Dedicated Card & Drop Zone)

    private var favoritesPinnedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section Header
            HStack(spacing: 5) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11 * appUiScale, weight: .bold))
                    .foregroundStyle(Color.yellow.opacity(0.95))

                Text("FAVORITES")
                    .font(.system(size: 11.5 * appUiScale, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Spacer()

                if isFavoritesDropTargeted {
                    Text("Drop to star")
                        .font(.system(size: 10.5 * appUiScale, weight: .semibold))
                        .foregroundStyle(primaryColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(primaryColor.opacity(0.12))
                        .clipShape(Capsule())
                } else if !store.favoritePages.isEmpty {
                    Text("\(store.favoritePages.count)")
                        .font(.system(size: 10.5 * appUiScale, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            let favs = store.sortedFavoritePages(by: sidebarSortOption)

            if favs.isEmpty {
                // Empty drop placeholder
                HStack(spacing: 6) {
                    Image(systemName: "star")
                        .font(.system(size: 12 * appUiScale))
                        .foregroundStyle(isFavoritesDropTargeted ? primaryColor : Color.secondary.opacity(0.4))

                    Text(isFavoritesDropTargeted ? "Drop note here to star" : "Drag notes here to favorite")
                        .font(.system(size: 12 * appUiScale, weight: .regular))
                        .foregroundStyle(isFavoritesDropTargeted ? primaryColor : Color.secondary.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isFavoritesDropTargeted ? primaryColor.opacity(0.08) : Color.primary.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isFavoritesDropTargeted ? primaryColor : Color.primary.opacity(0.06),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                        )
                )
            } else {
                VStack(spacing: 2) {
                    ForEach(favs) { favPage in
                        FavoriteItemCardRow(
                            store: store,
                            page: favPage,
                            isSelected: store.selectedPageId == favPage.id,
                            appUiScale: appUiScale,
                            sidebarFontSize: sidebarFontSize,
                            primaryColor: primaryColor
                        )
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isFavoritesDropTargeted ? primaryColor.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isFavoritesDropTargeted ? primaryColor : Color.clear,
                            style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                        )
                )
            }
        }
        .padding(.horizontal, 2)
        .onDrop(of: [.text], isTargeted: $isFavoritesDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                if let pageId = string {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            store.setFavorite(id: pageId, isFavorite: true)
                        }
                    }
                }
            }
            return true
        }
    }

    // MARK: - Dedicated Trash Drop Zone

    private var trashPinnedRow: some View {
        Button(action: {
            store.openTrash()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isTrashDropTargeted ? "trash.fill" : "trash")
                    .font(.system(size: 14 * appUiScale, weight: .medium))
                    .foregroundStyle(isTrashDropTargeted ? Color.red : (store.isShowingTrash ? primaryColor : Color.secondary))
                    .frame(width: 18)

                Text(isTrashDropTargeted ? "Drop to Move to Trash" : "Trash")
                    .font(.system(size: sidebarFontSize, weight: (isTrashDropTargeted || store.isShowingTrash) ? .semibold : .medium))
                    .foregroundStyle(isTrashDropTargeted ? Color.red : (store.isShowingTrash ? Color.primary : Color.secondary))

                Spacer()

                if !store.trashPages.isEmpty {
                    Text("\(store.trashPages.count)")
                        .font(.system(size: 11 * appUiScale, weight: .semibold))
                        .foregroundStyle(isTrashDropTargeted ? Color.red : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isTrashDropTargeted ? Color.red.opacity(0.18) : Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7.5 * appUiScale)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isTrashDropTargeted
                            ? Color.red.opacity(0.14)
                            : (store.isShowingTrash ? primaryColor.opacity(0.14) : (isTrashHovered ? Color.primary.opacity(0.045) : Color.clear))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isTrashDropTargeted ? Color.red.opacity(0.6) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isTrashHovered = $0 }
        .onDrop(of: [.text], isTargeted: $isTrashDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                if let pageId = string {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            store.moveToTrash(id: pageId)
                        }
                    }
                }
            }
            return true
        }
        .help("Drag notes here to move to Trash, or click to open Trash")
    }

    // MARK: - Folders / Workspaces Section

    private var foldersSection: some View {
        VStack(spacing: 8) {
            // Workspaces Header
            HStack {
                Text("WORKSPACES")
                    .font(.system(size: 11.5 * appUiScale, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Spacer()

                Button(action: {
                    isAddingCategory = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11 * appUiScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Add Workspace Folder")
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            // Category Sections
            ForEach(store.sortedCategories.filter { $0.id != "cat_fav" }) { category in
                CategorySectionView(
                    store: store,
                    category: category,
                    searchText: "",
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
        isDarkModeActive ? "sun.max" : "moon"
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
        VStack(spacing: 7) {
            // Primary Action: New Document
            Button(action: {
                store.addNewPage(in: "cat_notes")
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(primaryColor)
                    Text("New Document")
                        .font(.system(size: max(13.5, sidebarFontSize), weight: .semibold))
                    Spacer()
                    Text("⌘N")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8.5 * appUiScale)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            // Secondary Action Row: Settings (⌘,) & Exactly 1 Single Quick Theme Button
            HStack(spacing: 7) {
                Button(action: {
                    isSettingsSheetPresented = true
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                        Text("Settings")
                            .font(.system(size: max(13, sidebarFontSize), weight: .medium))
                        Spacer()
                        Text("⌘,")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7.5 * appUiScale)
                    .background(Color.primary.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Settings & Vault Preferences (⌘,)")
                .keyboardShortcut(",", modifiers: .command)

                // Exactly ONE single button to change theme mode
                Button(action: {
                    toggleTheme()
                }) {
                    Image(systemName: themeToggleIcon)
                        .font(.system(size: 13.5 * appUiScale, weight: .medium))
                        .foregroundStyle(isDarkModeActive ? primaryColor : Color.secondary)
                        .frame(width: 36 * appUiScale, height: 34 * appUiScale)
                        .background(Color.primary.opacity(0.045))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(themeToggleTooltip)
                .contextMenu {
                    Button(action: { appAppearance = "light" }) {
                        HStack {
                            Label("Light Mode", systemImage: "sun.max")
                            if appAppearance == "light" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { appAppearance = "dark" }) {
                        HStack {
                            Label("Dark Mode", systemImage: "moon")
                            if appAppearance == "dark" {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Divider()
                    Button(action: { appAppearance = "system" }) {
                        HStack {
                            Label("System Default", systemImage: "circle.lefthalf.striped.horizontal")
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

// MARK: - Favorite Item Card Row (Distinct Pinned Style with Drag Support)

struct FavoriteItemCardRow: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    let isSelected: Bool
    let appUiScale: Double
    let sidebarFontSize: Double
    let primaryColor: Color

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            store.selectPage(id: page.id)
        }) {
            HStack(spacing: 8) {
                // Gold star badge + Document Icon
                Image(systemName: "star.fill")
                    .font(.system(size: 10.5 * appUiScale))
                    .foregroundStyle(Color.yellow.opacity(0.95))

                DynamicIconView(icon: page.icon, size: sidebarFontSize, defaultSymbol: "doc.text")
                    .foregroundStyle(isSelected ? primaryColor : primaryColor.opacity(0.85))
                    .frame(width: max(16, sidebarFontSize + 2))

                Text(page.title.isEmpty ? "Untitled Document" : page.title)
                    .font(.system(size: sidebarFontSize, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.88))
                    .lineLimit(1)

                Spacer()

                if isHovered || isSelected {
                    Button(action: {
                        store.setFavorite(id: page.id, isFavorite: false)
                    }) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove from Favorites")
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? primaryColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.045) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDrag {
            NSItemProvider(object: page.id as NSString)
        }
        .contextMenu {
            Button(action: { store.setFavorite(id: page.id, isFavorite: false) }) {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
            Divider()
            Button(role: .destructive, action: { store.moveToTrash(id: page.id) }) {
                Label("Move to Trash", systemImage: "trash")
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

    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("sidebarFontSize") private var sidebarFontSize: Double = 14.0
    @State private var isHovered: Bool = false
    @State private var isDropTargeted: Bool = false

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

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
        HStack(spacing: 6) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.16)) {
                    store.toggleCategoryExpanded(id: category.id)
                }
            }) {
                HStack(spacing: 6) {
                    DynamicIconView(icon: category.icon, size: sidebarFontSize, defaultSymbol: "folder")
                        .foregroundStyle(primaryColor.opacity(0.85))

                    Text(category.name)
                        .font(.system(size: sidebarFontSize, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Image(systemName: category.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12, height: 12)
                }
            }
            .buttonStyle(.plain)

            if category.showPageCount {
                let count = store.pages(in: category.id).count
                Text("\(count)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.045))
                    .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 3) {
                if isHovered {
                    Button(action: {
                        store.addNewPage(in: category.id)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(3.5)
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isHovered ? Color.primary : Color.clear)
                        .padding(3)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 18)
            }
        }
        .padding(.vertical, 5.5)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isDropTargeted ? primaryColor.opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isDropTargeted ? primaryColor : Color.clear, lineWidth: 1.5)
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

    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("sidebarFontSize") private var sidebarFontSize: Double = 14.0

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    @State private var isHovered: Bool = false
    @State private var isRowDropTargeted: Bool = false
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
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .frame(width: 13, height: 13)
                        }
                        .buttonStyle(.plain)
                    } else if depth > 0 {
                        Circle()
                            .fill(Color.secondary.opacity(0.25))
                            .frame(width: 3, height: 3)
                            .frame(width: 13, height: 13)
                    }

                    // Document Icon (Follows primary color)
                    DynamicIconView(icon: page.icon, size: sidebarFontSize, defaultSymbol: "doc.text")
                        .foregroundStyle(isSelected ? primaryColor : primaryColor.opacity(0.85))
                        .frame(width: max(16, sidebarFontSize + 2))

                    // Title OR Inline Rename TextField
                    if isRenaming {
                        TextField("Document Title", text: $renameTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: sidebarFontSize))
                            .focused($isRenameFocused)
                            .onSubmit {
                                commitRename()
                            }
                    } else {
                        Text(page.title.isEmpty ? "Untitled" : page.title)
                            .font(.system(size: sidebarFontSize, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(page.title.isEmpty ? .secondary.opacity(0.6) : (isSelected ? Color.primary : Color.primary.opacity(0.85)))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Hover Quick Actions
                    if !isRenaming && (isHovered || isSelected) {
                        HStack(spacing: 4) {
                            // Add Subpage Quick Button
                            Button(action: {
                                store.addNewSubpage(parentPageId: page.id)
                                isSubpagesExpanded = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .padding(2.5)
                            }
                            .buttonStyle(.plain)
                            .help("Add subpage")

                            // Star / Unstar Favorite (Follows primary color)
                            Button(action: { store.toggleFavorite(id: page.id) }) {
                                Image(systemName: page.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: max(11.0, sidebarFontSize - 1.5), weight: page.isFavorite ? .bold : .regular))
                                    .foregroundStyle(page.isFavorite ? primaryColor : Color.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .help(page.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                            // Context Menu Button
                            Menu {
                                documentContextMenuContent
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 16)
                        }
                    }
                }
                .padding(.vertical, 5.5)
                .padding(.horizontal, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            isRowDropTargeted
                                ? primaryColor.opacity(0.18)
                                : (isSelected ? primaryColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.045) : Color.clear))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(isRowDropTargeted ? primaryColor : Color.clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            // Native macOS Drag Provider
            .onDrag {
                NSItemProvider(object: page.id as NSString)
            }
            // Drop target: drop another document here to nest it as a subpage
            .onDrop(of: [.text], isTargeted: $isRowDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: String.self) { string, _ in
                    if let draggedPageId = string, draggedPageId != page.id {
                        DispatchQueue.main.async {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                store.movePage(id: draggedPageId, toParentPage: page.id)
                                isSubpagesExpanded = true
                            }
                        }
                    }
                }
                return true
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

    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("sidebarFontSize") private var sidebarFontSize: Double = 14.0

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: {
            store.selectPage(id: page.id)
        }) {
            HStack(spacing: 7) {
                DynamicIconView(icon: page.icon, size: sidebarFontSize, defaultSymbol: "doc.text")
                    .foregroundStyle(isSelected ? primaryColor : primaryColor.opacity(0.85))
                    .frame(width: max(16, sidebarFontSize + 2))

                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: sidebarFontSize))
                    .foregroundStyle(page.title.isEmpty ? .secondary.opacity(0.6) : (isSelected ? Color.primary : Color.primary.opacity(0.85)))
                    .lineLimit(1)

                Spacer()

                Text(relativeTimeString(from: page.lastModified))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.045))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.vertical, 5.5)
            .padding(.horizontal, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? primaryColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.045) : Color.clear))
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

    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @AppStorage("sidebarFontSize") private var sidebarFontSize: Double = 14.0

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    @State private var isHovered: Bool = false

    private var categoryName: String {
        store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
    }

    var body: some View {
        Button(action: {
            store.selectPage(id: page.id)
        }) {
            HStack(spacing: 8) {
                DynamicIconView(icon: page.icon, size: sidebarFontSize, defaultSymbol: "doc.text")
                    .foregroundStyle(isSelected ? primaryColor : primaryColor.opacity(0.85))
                    .frame(width: max(16, sidebarFontSize + 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title.isEmpty ? "Untitled" : page.title)
                        .font(.system(size: sidebarFontSize, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.9))
                        .lineLimit(1)

                    Text(categoryName)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(relativeTimeString(from: page.lastModified))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 5.5)
            .padding(.horizontal, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? primaryColor.opacity(0.14) : (isHovered ? Color.primary.opacity(0.045) : Color.clear))
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

    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"
    @State private var customSymbolText: String = ""

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

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
                                .fill(isSelected ? primaryColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? primaryColor : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                )
                            Image(systemName: sym)
                                .font(.system(size: 13))
                                .foregroundStyle(isSelected ? primaryColor : Color.primary)
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



