import SwiftUI
import AppKit

// MARK: - Native Document-Identical Trash Page View

struct TrashPageView: View {
    @ObservedObject var store: WorkspaceStore

    @State private var searchText: String = ""
    @State private var selectedCategoryFilter: String? = nil
    @State private var sortOption: TrashSortOption = .newestDeleted
    @State private var isConfirmingEmptyTrash: Bool = false
    @State private var pageToDeletePermanently: DocumentPage? = nil
    @State private var inspectingPage: DocumentPage? = nil
    @State private var lastRestoredInfo: (title: String, category: String, id: String)? = nil
    @State private var showRestoreToast: Bool = false
    @State private var hoveredBlockId: String? = nil
    @State private var currentCoverUrl: String = "gradient:midnight"
    @State private var isCoverHovered: Bool = false
    @State private var isHeaderHovered: Bool = false

    enum TrashSortOption: String, CaseIterable {
        case newestDeleted = "Recently Deleted"
        case oldestDeleted = "Oldest Deleted"
        case titleAsc = "Title (A–Z)"
        case titleDesc = "Title (Z–A)"
    }

    private var filteredTrashPages: [DocumentPage] {
        var list = store.trashPages

        // 1. Category Filter
        if let catId = selectedCategoryFilter {
            list = list.filter { $0.categoryId == catId }
        }

        // 2. Search Text Filter
        if !searchText.isEmpty {
            list = list.filter { page in
                page.title.localizedCaseInsensitiveContains(searchText) ||
                page.rawContent.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 3. Sorting
        switch sortOption {
        case .newestDeleted:
            return list.sorted { $0.lastModified > $1.lastModified }
        case .oldestDeleted:
            return list.sorted { $0.lastModified < $1.lastModified }
        case .titleAsc:
            return list.sorted {
                let t1 = $0.title.isEmpty ? "Untitled" : $0.title
                let t2 = $1.title.isEmpty ? "Untitled" : $1.title
                return t1.localizedCaseInsensitiveCompare(t2) == .orderedAscending
            }
        case .titleDesc:
            return list.sorted {
                let t1 = $0.title.isEmpty ? "Untitled" : $0.title
                let t2 = $1.title.isEmpty ? "Untitled" : $1.title
                return t1.localizedCaseInsensitiveCompare(t2) == .orderedDescending
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Document Canvas Scroll Area (100% Identical to DocumentCanvasView)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    if !currentCoverUrl.isEmpty {
                        pageCoverBannerView
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        // Notion Page Header (Icon & 34pt Bold Title)
                        notionPageHeaderView

                        // Block 1: Callout Block (Vault Info & Explanations)
                        vaultInfoCalloutBlock
                            .padding(.leading, 48)

                        // Block 2: Divider Block
                        Divider()
                            .opacity(0.35)
                            .padding(.leading, 48)

                        // Block 3: Search & Folder Filter Toolbar
                        if !store.trashPages.isEmpty {
                            searchAndFilterToolbar
                                .padding(.leading, 48)
                        }

                        // Block 4: Section Heading Block
                        sectionHeadingBlock
                            .padding(.leading, 48)

                        // Block 5: Deleted Notes List (Styled as Native Pustaka Blocks)
                        if store.trashPages.isEmpty {
                            emptyTrashCalloutBlock
                                .padding(.leading, 48)
                        } else if filteredTrashPages.isEmpty {
                            emptyFilterResultCalloutBlock
                                .padding(.leading, 48)
                        } else {
                            deletedNotesBlockList
                        }

                        // Bottom Spacer matching regular documents
                        Spacer(minLength: 140)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, currentCoverUrl.isEmpty ? 24 : 14)
                    .frame(maxWidth: .infinity)
                }
            }

            // Floating Bottom Action Island (Identical to DocumentCanvasView floating island)
            floatingTrashIsland
                .padding(.bottom, 22)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if showRestoreToast, let info = lastRestoredInfo {
                restoreToastView(info: info)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 72)
            }
        }
        .confirmationDialog(
            "Empty Trash?",
            isPresented: $isConfirmingEmptyTrash,
            titleVisibility: .visible
        ) {
            Button("Empty Trash (\(store.trashPages.count) items)", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    store.emptyTrash()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete all \(store.trashPages.count) notes from disk? This cannot be undone.")
        }
        .confirmationDialog(
            "Permanently Delete Note?",
            isPresented: Binding(
                get: { pageToDeletePermanently != nil },
                set: { if !$0 { pageToDeletePermanently = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let p = pageToDeletePermanently {
                Button("Delete Permanently", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        store.permanentlyDelete(id: p.id)
                    }
                    pageToDeletePermanently = nil
                }
                Button("Cancel", role: .cancel) {
                    pageToDeletePermanently = nil
                }
            }
        } message: {
            if let p = pageToDeletePermanently {
                let title = p.title.isEmpty ? "Untitled Note" : p.title
                Text("Are you sure you want to permanently delete \"\(title)\" from disk? This cannot be undone.")
            }
        }
        .sheet(item: $inspectingPage) { page in
            TrashNoteInspectorSheet(
                page: page,
                store: store,
                onRestore: { andOpen in
                    handleRestore(page: page, andOpen: andOpen)
                    inspectingPage = nil
                },
                onDeletePermanently: {
                    store.permanentlyDelete(id: page.id)
                    inspectingPage = nil
                },
                onDismiss: {
                    inspectingPage = nil
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PromptEmptyTrash"))) { _ in
            isConfirmingEmptyTrash = true
        }
    }

    // MARK: - Notion Cover Banner (Identical 270pt Banner to DocumentCanvasView)

    private var pageCoverBannerView: some View {
        ZStack(alignment: .bottomTrailing) {
            coverImageContent
                .frame(height: 270)
                .clipped()

            // Hover action controls
            HStack(spacing: 6) {
                Menu {
                    Section("Preset Gradients") {
                        ForEach(PresetGradientCover.allCases) { preset in
                            Button(preset.title) {
                                currentCoverUrl = preset.rawValue
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Text("Change cover")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                Button(action: {
                    currentCoverUrl = ""
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Remove")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .opacity(isCoverHovered ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isCoverHovered)
        }
        .contentShape(Rectangle())
        .onHover { isCoverHovered = $0 }
    }

    @ViewBuilder
    private var coverImageContent: some View {
        if currentCoverUrl.hasPrefix("gradient:") {
            LinearGradient(
                colors: PresetGradientCover.colors(for: currentCoverUrl),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.12, blue: 0.28), Color(red: 0.38, green: 0.18, blue: 0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Notion Page Header (Identical 48pt Indentation & Typography to DocumentCanvasView)

    private var notionPageHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header buttons row: "Add cover" if removed
            HStack(spacing: 10) {
                if currentCoverUrl.isEmpty {
                    Button(action: {
                        currentCoverUrl = "gradient:midnight"
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.caption)
                            Text("Add cover")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(height: 24)

            // 44pt Big Document Emoji Icon
            Text("🗑️")
                .font(.system(size: 44))
                .padding(4)

            // 34pt Bold Page Title (Identical to TitleEditorField style)
            Text("Trash")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 2)
        }
        .padding(.leading, 48)
        .contentShape(Rectangle())
        .onHover { isHeaderHovered = $0 }
    }

    // MARK: - Block 1: Callout Box (Exact Pustaka Callout Design)

    private var vaultInfoCalloutBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("💡")
                .font(.system(size: 18))
                .frame(width: 22, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text("**Vault Trash (`~/.trash/`)** — Catatan dan subpage yang dihapus tersimpan di direktori lokal vault Anda. Merestore catatan akan mengembalikannya beserta seluruh struktur subpage.")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Block 3: Search & Folder Filter Toolbar

    private var searchAndFilterToolbar: some View {
        HStack(spacing: 10) {
            // Search Input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                TextField("Search deleted notes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )

            // Folder Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    filterPill(title: "All", count: store.trashPages.count, isSelected: selectedCategoryFilter == nil) {
                        selectedCategoryFilter = nil
                    }

                    ForEach(store.categories) { cat in
                        let count = store.trashPages.filter { $0.categoryId == cat.id }.count
                        if count > 0 {
                            filterPill(title: "\(cat.icon) \(cat.name)", count: count, isSelected: selectedCategoryFilter == cat.id) {
                                selectedCategoryFilter = cat.id
                            }
                        }
                    }
                }
            }

            // Sort Menu
            Menu {
                ForEach(TrashSortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.rawValue)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                    Text(sortOption.rawValue)
                        .font(.system(size: 11.5, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func filterPill(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                Text("(\(count))").font(.caption2).opacity(0.8)
            }
            .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Block 4: Section Heading Block (20pt Bold)

    private var sectionHeadingBlock: some View {
        HStack(spacing: 8) {
            Text("Deleted Pages")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            if !store.trashPages.isEmpty {
                Text("\(filteredTrashPages.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }

            Spacer()
        }
        .padding(.top, 6)
    }

    // MARK: - Block 5: Deleted Notes (100% Identical to SubpageBlockView in BlockListView)

    private var deletedNotesBlockList: some View {
        VStack(spacing: 2) {
            ForEach(filteredTrashPages) { page in
                deletedSubpageBlockRow(page: page)
            }
        }
    }

    private func deletedSubpageBlockRow(page: DocumentPage) -> some View {
        let isHovered = (hoveredBlockId == page.id)
        let categoryName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
        let parentTitle = page.parentPageId.flatMap { pId in
            store.pages.first(where: { $0.id == pId })?.title
        }

        return HStack(spacing: 6) {
            // Gutter: 6-dots handle visible on hover (identical to BlockRowView)
            Image(systemName: "circle.grid.2x3.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 20)
                .opacity(isHovered ? 0.6 : 0.0)

            // Subpage Link Block Body (Identical to SubpageBlockView)
            HStack(spacing: 8) {
                // Document Icon
                if !page.icon.isEmpty {
                    Text(page.icon)
                        .font(.system(size: 15))
                        .frame(width: 20)
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 20)
                }

                // Page Title
                Text(page.title.isEmpty ? "Untitled Note" : page.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .underline(isHovered, color: .primary.opacity(0.45))
                    .lineLimit(1)

                // Subpage parent badge (if nested)
                if let parent = parentTitle {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8))
                        Text("Subpage of \(parent)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Category folder label
                Text(categoryName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // Time ago
                Text("•  \(relativeTimeString(from: page.lastModified))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Actions visible on hover (or subtle preview button)
                if isHovered {
                    HStack(spacing: 6) {
                        // Preview Button
                        Button(action: { inspectingPage = page }) {
                            Image(systemName: "eye")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Preview note content")

                        // Restore Action
                        Button(action: { handleRestore(page: page, andOpen: false) }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10))
                                Text("Restore")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Restore back to original folder")

                        // Delete Permanently Action
                        Button(action: { pageToDeletePermanently = page }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Delete permanently")
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.secondary.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                inspectingPage = page
            }
        }
        .padding(.leading, 28)
        .contentShape(Rectangle())
        .onHover { h in
            hoveredBlockId = h ? page.id : nil
        }
    }

    private func handleRestore(page: DocumentPage, andOpen: Bool) {
        let catName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
        let title = page.title.isEmpty ? "Untitled Note" : page.title
        withAnimation(.easeInOut(duration: 0.18)) {
            store.restoreFromTrash(id: page.id, andOpen: andOpen)
        }
        if !andOpen {
            lastRestoredInfo = (title: title, category: catName, id: page.id)
            withAnimation {
                showRestoreToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation {
                    showRestoreToast = false
                }
            }
        }
    }

    // MARK: - Empty State Callout Blocks (Clean & Minimalist)

    private var emptyTrashCalloutBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("✨")
                .font(.system(size: 18))
                .frame(width: 22, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tempat sampah kosong. Tidak ada catatan yang dihapus.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var emptyFilterResultCalloutBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .top)

            VStack(alignment: .leading, spacing: 4) {
                Text("Tidak ditemukan catatan yang cocok dengan \"\(searchText)\".")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Button("Clear filter") {
                    searchText = ""
                    selectedCategoryFilter = nil
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Floating Glassmorphic Trash Island (Identical to DocumentCanvasView)

    private var floatingTrashIsland: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(store.trashPages.isEmpty ? Color.secondary : Color.red.opacity(0.85))

                Text("\(store.trashPages.count) items in Trash")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }

            Divider()
                .frame(height: 14)

            Button(action: { store.revealTrashInFinder() }) {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                    Text("Reveal in Finder")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open .trash/ folder in Finder")

            if !store.trashPages.isEmpty {
                Divider()
                    .frame(height: 14)

                Button(action: { isConfirmingEmptyTrash = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Empty Trash...")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.red.opacity(0.9))
                }
                .buttonStyle(.plain)
                .help("Permanently empty all items")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Restore Toast View

    private func restoreToastView(info: (title: String, category: String, id: String)) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)

            Text("Restored \"\(info.title)\" to \(info.category)")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.primary)

            Button(action: {
                store.selectPage(id: info.id)
                showRestoreToast = false
            }) {
                Text("Open Note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)

            Button(action: { showRestoreToast = false }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Read-Only Inspection Sheet for a Deleted Note

struct TrashNoteInspectorSheet: View {
    let page: DocumentPage
    @ObservedObject var store: WorkspaceStore
    let onRestore: (Bool) -> Void
    let onDeletePermanently: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 10) {
                if !page.icon.isEmpty {
                    Text(page.icon)
                        .font(.title2)
                } else {
                    Image(systemName: "doc.text")
                        .font(.title3)
                        .foregroundStyle(Color.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title.isEmpty ? "Untitled Note" : page.title)
                        .font(.headline.weight(.semibold))

                    let catName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
                    Text("Originally in \(catName) • Deleted \(relativeTimeString(from: page.lastModified))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Note Content Preview (Scrollable Read-Only)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    if !page.coverUrl.isEmpty {
                        AsyncImage(url: URL(string: page.coverUrl)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 140)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }

                    Text(page.rawContent.isEmpty ? "(Empty note)" : page.rawContent)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(page.rawContent.isEmpty ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(20)
            }

            Divider()

            // Bottom Actions Footer
            HStack(spacing: 10) {
                Button(role: .destructive, action: onDeletePermanently) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete Permanently")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(action: { onRestore(false) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Restore Note")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button(action: { onRestore(true) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.forward.app")
                        Text("Restore and Open")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 620, height: 480)
    }
}
