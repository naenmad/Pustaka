import SwiftUI

struct QuickSearchPaletteView: View {
    @ObservedObject var store: WorkspaceStore
    @Binding var isPresented: Bool

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFieldFocused: Bool
    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"

    private var primaryColor: Color {
        Color(hex: appPrimaryColorHex)
    }

    private var results: [DocumentPage] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            let active = store.activePages
            // Prioritize favorites then recent
            let favs = active.filter { $0.isFavorite }
            let nonFavs = active.filter { !$0.isFavorite }.sorted(by: { $0.lastModified > $1.lastModified })
            return Array((favs + nonFavs).prefix(14))
        }

        return store.activePages.filter { page in
            page.title.localizedCaseInsensitiveContains(q) ||
            page.rawContent.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            // 1. Semi-translucent dark blur backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // 2. Center Floating Command Palette (Raycast / Spotlight style)
            VStack(spacing: 0) {
                // Search Input Header
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(primaryColor)

                    TextField("Search all notes by title or content...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .regular))
                        .focused($isFieldFocused)
                        .onSubmit {
                            selectCurrent()
                        }
                        .onChange(of: query) { _, _ in
                            selectedIndex = 0
                        }

                    if !query.isEmpty {
                        Button(action: {
                            query = ""
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

                // Results List / Empty State
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 4)

                        Text("No matching documents found")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("Try searching for different keywords or page titles.")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, page in
                                    paletteRow(page: page, isSelected: index == selectedIndex)
                                        .id(index)
                                        .onTapGesture {
                                            openPage(page)
                                        }
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                        }
                        .frame(maxHeight: 330)
                        .onChange(of: selectedIndex) { _, newIndex in
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }

                Divider()
                    .opacity(0.2)

                // Footer Command Bar
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
                        Text("Open")
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

                    Text(query.isEmpty ? "\(results.count) recent notes" : "\(results.count) results")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.015))
            }
            .frame(width: 580)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.35), radius: 30, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .onKeyPress(.downArrow) {
                if selectedIndex < results.count - 1 {
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
            isFieldFocused = true
            selectedIndex = 0
        }
    }

    // MARK: - Palette Row

    private func paletteRow(page: DocumentPage, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            // Icon
            DynamicIconView(icon: page.icon, size: 14, defaultSymbol: "doc.text")
                .frame(width: 18)

            // Title and Snippet
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(page.title.isEmpty ? "Untitled Document" : page.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(page.title.isEmpty ? .secondary : .primary)
                        .lineLimit(1)

                    if page.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.yellow)
                    }
                }

                // Snippet or category info
                if let snippet = extractSnippet(from: page.rawContent, query: query) {
                    Text(snippet)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    let catName = store.categories.first(where: { $0.id == page.categoryId })?.name ?? "Notes"
                    Text("in \(catName) • Modified \(formattedDate(page.lastModified))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let cat = store.categories.first(where: { $0.id == page.categoryId }) {
                Text(cat.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
            }

            if isSelected {
                Image(systemName: "return")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primaryColor)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? primaryColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func extractSnippet(from content: String, query: String) -> String? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        guard let range = content.range(of: q, options: .caseInsensitive) else {
            return nil
        }

        let start = content.index(range.lowerBound, offsetBy: -25, limitedBy: content.startIndex) ?? content.startIndex
        let end = content.index(range.upperBound, offsetBy: 45, limitedBy: content.endIndex) ?? content.endIndex

        var excerpt = String(content[start..<end])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)

        if start > content.startIndex { excerpt = "..." + excerpt }
        if end < content.endIndex { excerpt = excerpt + "..." }

        return excerpt
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func selectCurrent() {
        if selectedIndex >= 0 && selectedIndex < results.count {
            openPage(results[selectedIndex])
        }
    }

    private func openPage(_ page: DocumentPage) {
        store.selectPage(id: page.id)
        dismiss()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            isPresented = false
        }
    }
}
