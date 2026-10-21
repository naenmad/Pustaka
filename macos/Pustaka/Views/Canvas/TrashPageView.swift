import SwiftUI
import AppKit

// MARK: - Dedicated Block-First Full-Page Trash View (Multi-Tab & Obsidian .trash/ Compatible)

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
    @State private var isCoverPickerOpen: Bool = false

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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                // 1. Page Cover Banner (Matches DocumentCanvasView Notion Header)
                if !currentCoverUrl.isEmpty {
                    pageCoverBannerView
                }

                // 2. Main Canvas Body Composed of Document Blocks
                VStack(alignment: .leading, spacing: 18) {
                    // Notion Document Page Header Block
                    notionPageHeaderBlock

                    // Block 1: Callout Block (Vault Info & Fast Actions)
                    vaultInfoCalloutBlock

                    // Block 2: Horizontal Divider Block
                    Divider().opacity(0.35)

                    // Block 3: Database Filter & Search Block
                    if !store.trashPages.isEmpty {
                        filterAndSortControlsBlock
                    }

                    // Block 4: Section Heading Block
                    sectionHeadingBlock

                    // Block 5: Deleted Notes Rendered as Blocks
                    if store.trashPages.isEmpty {
                        emptyTrashCalloutBlock
                    } else if filteredTrashPages.isEmpty {
                        emptyFilterResultCalloutBlock
                    } else {
                        deletedNotesBlockList
                    }

                    // Bottom Canvas Padding
                    Spacer(minLength: 120)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.top, currentCoverUrl.isEmpty ? 24 : 14)
                .frame(maxWidth: 880)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            if showRestoreToast, let info = lastRestoredInfo {
                restoreToastView(info: info)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
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

    // MARK: - Notion Cover Banner View (Identical to DocumentCanvasView)

    private var pageCoverBannerView: some View {
        ZStack(alignment: .bottomTrailing) {
            coverBannerImageContent
                .frame(height: 200)
                .clipped()

            // Normal Hover Action Buttons (Change Cover, Remove Cover)
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
                    .contentShape(Rectangle())
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .opacity((isCoverHovered || isCoverPickerOpen) ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.15), value: isCoverHovered || isCoverPickerOpen)
        }
        .contentShape(Rectangle())
        .onHover { isCoverHovered = $0 }
    }

    @ViewBuilder
    private var coverBannerImageContent: some View {
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

    // MARK: - Notion Page Header Block

    private var notionPageHeaderBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Breadcrumbs
            HStack(spacing: 4) {
                Text("Vault")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("/")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("🗑️ Trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 2)

            // Add cover button if cover was removed
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

            // Big Emoji Icon (Font size 44, matching DocumentCanvasView)
            Text("🗑️")
                .font(.system(size: 44))
                .padding(.vertical, 2)

            // Document Title (Font size 34 bold, matching TitleEditorField)
            Text("Trash")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)

            // Description Paragraph Block
            Text("Catatan yang dihapus disimpan di folder `.trash` vault Anda. Item di sini dapat dipulihkan kapan saja ke foldernya masing-masing atau dibersihkan secara permanen.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
    }

    // MARK: - Block 1: Callout Block (Vault Info & Fast Actions)

    private var vaultInfoCalloutBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("💡")
                .font(.system(size: 20))
                .frame(width: 24, alignment: .top)

            VStack(alignment: .leading, spacing: 8) {
                Text("**Vault Trash (`~/.trash/`)** — Catatan dan subpage yang dihapus tersimpan aman di direktori lokal. Merestore catatan akan mengembalikannya beserta seluruh struktur subpage.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.primary)
                    .lineSpacing(3)

                HStack(spacing: 8) {
                    // Reveal in Finder Button
                    Button(action: {
                        store.revealTrashInFinder()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                                .font(.system(size: 11))
                            Text("Reveal .trash in Finder")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open .trash directory in macOS Finder")

                    // Empty Trash Button
                    if !store.trashPages.isEmpty {
                        Button(action: {
                            isConfirmingEmptyTrash = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Empty Trash (\(store.trashPages.count) items)...")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Permanently delete all items from disk")
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Block 3: Database Filter & Search Block

    private var filterAndSortControlsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Search Input Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    TextField("Filter deleted notes by title or content...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )

                // Sort Dropdown
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
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 11))
                        Text(sortOption.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }

            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(title: "All Folders (\(store.trashPages.count))", isSelected: selectedCategoryFilter == nil) {
                        selectedCategoryFilter = nil
                    }

                    ForEach(store.categories) { cat in
                        let count = store.trashPages.filter { $0.categoryId == cat.id }.count
                        if count > 0 {
                            filterChip(title: "\(cat.icon) \(cat.name) (\(count))", isSelected: selectedCategoryFilter == cat.id) {
                                selectedCategoryFilter = cat.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color.primary.opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Block 4: Section Heading Block

    private var sectionHeadingBlock: some View {
        HStack(spacing: 8) {
            Text("Deleted Pages")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            if !store.trashPages.isEmpty {
                Text("\(filteredTrashPages.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Block 5: Deleted Notes Rendered as Native Pustaka Blocks

    private var deletedNotesBlockList: some View {
        VStack(spacing: 6) {
            ForEach(filteredTrashPages) { page in
                deletedNoteBlockRow(page: page)
            }
        }
    }

    private func deletedNoteBlockRow(page: DocumentPage) -> some View {
        let isHovered = (hoveredBlockId == page.id)
        let categoryName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
        let parentTitle = page.parentPageId.flatMap { pId in
            store.pages.first(where: { $0.id == pId })?.title
        }

        return HStack(alignment: .top, spacing: 6) {
            // Left Gutter: 6-dots handle visible on hover (identical to BlockListView)
            Image(systemName: "circle.grid.2x3.fill")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 14, height: 26)
                .opacity(isHovered ? 0.7 : 0.0)
                .animation(.easeInOut(duration: 0.12), value: isHovered)

            // Block Content Body
            VStack(alignment: .leading, spacing: 4) {
                // Header line: Icon, Title, Subpage badge, Category tag, Timestamp, and Actions
                HStack(alignment: .center, spacing: 8) {
                    // Document Icon
                    if !page.icon.isEmpty {
                        Text(page.icon)
                            .font(.system(size: 15))
                            .frame(width: 18)
                    } else {
                        Image(systemName: "doc.text")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 18)
                    }

                    // Title
                    Text(page.title.isEmpty ? "Untitled Note" : page.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Subpage badge
                    if let parent = parentTitle {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 8.5))
                            Text("Subpage of \(parent)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    // Category tag
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 8.5))
                        Text(categoryName)
                            .font(.system(size: 10.5))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Relative deletion time
                    Text("Deleted \(relativeTimeString(from: page.lastModified))")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    // Right-aligned Actions (Quick look, Restore, Delete)
                    HStack(spacing: 6) {
                        // Preview Button
                        Button(action: {
                            inspectingPage = page
                        }) {
                            Image(systemName: "eye")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Quick preview note content")

                        // Restore Menu
                        Menu {
                            Button(action: {
                                handleRestore(page: page, andOpen: false)
                            }) {
                                Label("Restore to \(categoryName)", systemImage: "arrow.uturn.backward")
                            }

                            Button(action: {
                                handleRestore(page: page, andOpen: true)
                            }) {
                                Label("Restore and Open Note", systemImage: "arrow.up.forward.app")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Restore")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .help("Restore document back to active notes")

                        // Permanent Delete Button
                        Button(action: {
                            pageToDeletePermanently = page
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .frame(width: 24, height: 24)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                        .help("Permanently delete from disk")
                    }
                    .opacity(isHovered ? 1.0 : 0.75)
                }

                // Snippet line (Clean 1-line text preview)
                let snippet = plainTextSnippet(from: page.rawContent)
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 26)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isHovered ? Color.secondary.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                inspectingPage = page
            }
        }
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

    private func plainTextSnippet(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("---") || trimmed.hasPrefix("![") {
                continue
            }
            let cleaned = trimmed
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: "`", with: "")
                .replacingOccurrences(of: "> ", with: "")
                .replacingOccurrences(of: "- ", with: "")
            if !cleaned.isEmpty {
                return String(cleaned.prefix(110))
            }
        }
        return ""
    }

    // MARK: - Empty State Callout Blocks

    private var emptyTrashCalloutBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("✨")
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 6) {
                Text("Tempat Sampah Kosong")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Tidak ada dokumen atau catatan di `.trash/`. Ketika Anda menghapus sebuah catatan dari sidebar atau menu dokumen, catatan tersebut akan muncul di sini.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        store.addNewPage()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Create New Document")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private var emptyFilterResultCalloutBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tidak Ada Catatan yang Cocok")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Tidak ditemukan catatan terhapus yang cocok dengan kata kunci \"\(searchText)\".")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button("Clear Search") {
                    searchText = ""
                    selectedCategoryFilter = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
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
