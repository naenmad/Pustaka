import SwiftUI
import AppKit

// MARK: - Dedicated Full-Page Trash View (Obsidian .trash/ Compatible)

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

    enum TrashSortOption: String, CaseIterable {
        case newestDeleted = "Recently Deleted"
        case oldestDeleted = "Oldest Deleted"
        case titleAsc = "Title (A-Z)"
        case titleDesc = "Title (Z-A)"
    }

    private var filteredTrashPages: [DocumentPage] {
        var list = store.trashPages

        // 1. Category Filter
        if let catId = selectedCategoryFilter {
            list = list.filter { $0.categoryId == catId }
        }

        // 2. Search Text
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
            VStack(alignment: .leading, spacing: 0) {
                // Header Banner
                headerBanner
                    .padding(.top, 28)
                    .padding(.bottom, 24)

                if !store.trashPages.isEmpty {
                    // Search and Filter Bar
                    filterAndSortBar
                        .padding(.bottom, 18)

                    // Trash Item Cards List
                    if filteredTrashPages.isEmpty {
                        emptyFilterResultView
                    } else {
                        itemsListView
                    }
                } else {
                    // Completely Empty State
                    emptyTrashStateView
                }
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, alignment: .top)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerEmptyTrash"))) { _ in
            isConfirmingEmptyTrash = true
        }
    }

    // MARK: - Header Banner

    private var headerBanner: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: "trash.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.red)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Trash")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.primary)

                    if !store.trashPages.isEmpty {
                        Text("\(store.trashPages.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red.opacity(0.85)))
                    }
                }

                Text("Deleted documents are safely preserved in ~/Documents/Pustaka/.trash/ until permanently cleared.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                // Reveal in Finder
                Button(action: {
                    let trashDir = store.trashURL
                    NSWorkspace.shared.activateFileViewerSelecting([trashDir])
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Reveal in Finder")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .foregroundStyle(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Open .trash folder in macOS Finder")

                // Empty Trash Button
                if !store.trashPages.isEmpty {
                    Button(action: {
                        isConfirmingEmptyTrash = true
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Empty Trash...")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.red.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Permanently delete all items")
                }

                // Done / Back Button
                Button(action: {
                    store.closeTrash()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Done")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06))
                    .foregroundStyle(Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Return to documents")
            }
        }
    }

    // MARK: - Filter and Sort Bar

    private var filterAndSortBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Search Input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)

                    TextField("Filter deleted notes by title or content...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
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
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .foregroundStyle(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
            }

            // Category Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(title: "All Folders", isSelected: selectedCategoryFilter == nil) {
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

    // MARK: - Items List View

    private var itemsListView: some View {
        VStack(spacing: 8) {
            ForEach(filteredTrashPages) { page in
                trashCardItem(page: page)
            }
        }
    }

    private func trashCardItem(page: DocumentPage) -> some View {
        let categoryName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Documents"
        let parentTitle = page.parentPageId.flatMap { pId in
            store.pages.first(where: { $0.id == pId })?.title
        }

        return HStack(alignment: .center, spacing: 14) {
            // Document Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                if !page.icon.isEmpty {
                    Text(page.icon)
                        .font(.system(size: 18))
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
            }

            // Note Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(page.title.isEmpty ? "Untitled Note" : page.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    if let parent = parentTitle {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 9))
                            Text("Subpage of \(parent)")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                // Snippet preview
                let snippet = plainTextSnippet(from: page.rawContent)
                if !snippet.isEmpty {
                    Text(snippet)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                // Metadata Row
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                            .font(.system(size: 9.5))
                        Text(categoryName)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.secondary)

                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9.5))
                        Text("Deleted \(relativeTimeString(from: page.lastModified))")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.secondary)
                }
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 8) {
                // Quick Preview Button
                Button(action: {
                    inspectingPage = page
                }) {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                        .padding(6)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Preview note content")

                // Restore Button (with menu option to open directly)
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
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Restore")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .help("Restore document back to active notes")

                // Permanent Delete Button
                Button(action: {
                    pageToDeletePermanently = page
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .padding(6)
                        .background(Color.red.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Delete permanently from disk")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            inspectingPage = page
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

    // MARK: - Empty Filter Result State

    private var emptyFilterResultView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 36)
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 34))
                .foregroundStyle(Color.secondary.opacity(0.5))

            Text("No deleted notes matching \"\(searchText)\"")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary)

            Button("Clear Search") {
                searchText = ""
                selectedCategoryFilter = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer().frame(height: 36)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Completely Empty State

    private var emptyTrashStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 48)

            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 80, height: 80)

                Image(systemName: "trash")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text("Trash is Empty")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text("Documents you delete will appear here before being permanently removed from your vault.\nYou can restore any document back to its original folder at any time.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            Button(action: {
                store.closeTrash()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back to Notes")
                        .font(.system(size: 13, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)

            Spacer().frame(height: 60)
        }
        .frame(maxWidth: .infinity)
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
