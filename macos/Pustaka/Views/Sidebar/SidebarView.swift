import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var searchText: String = ""
    @State private var isWorkspaceMenuOpen: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Workspace Header
            workspaceHeaderView
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Search Filter
            searchBarView
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()
                .padding(.horizontal, 8)

            // Sidebar List
            List(selection: $store.selectedPageId) {
                // Section 1: Favorites
                let favs = store.pages.filter { $0.isFavorite && matchesSearch($0) }
                if !favs.isEmpty {
                    Section {
                        ForEach(favs) { page in
                            SidebarPageRow(page: page, isSelected: store.selectedPageId == page.id)
                                .tag(page.id)
                        }
                    } header: {
                        Label("Favorites", systemImage: "star.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                // Section 2: AI Agents (ACP Protocol)
                Section {
                    ForEach(store.agents) { agent in
                        SidebarAgentRow(agent: agent)
                    }
                } header: {
                    HStack {
                        Label("ACP Agents", systemImage: "bolt.horizontal.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                    }
                }

                // Section 3: Teamspaces
                let teamDocs = store.pages.filter { $0.section == .teamspaces && matchesSearch($0) }
                Section {
                    ForEach(teamDocs) { page in
                        SidebarPageRow(page: page, isSelected: store.selectedPageId == page.id)
                            .tag(page.id)
                    }
                } header: {
                    Label("Teamspaces", systemImage: "person.2.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                // Section 4: Private Pages
                let privDocs = store.pages.filter { $0.section == .privateDocs && matchesSearch($0) }
                Section {
                    ForEach(privDocs) { page in
                        SidebarPageRow(page: page, isSelected: store.selectedPageId == page.id)
                            .tag(page.id)
                    }
                } header: {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Bottom Bar: Quick Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    store.addNewPage(section: .privateDocs)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                        Text("New Page")
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button(action: {
                    store.isPreviewDrawerPresented.toggle()
                }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(7)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Toggle Typst Vector Preview (Cmd+P)")
            }
            .padding(10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var workspaceHeaderView: some View {
        Menu {
            Button("Personal Workspace") {}
            Button("Engineering Hub") {}
            Divider()
            Button("Workspace Settings...") {}
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 26, height: 26)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tint)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pustaka")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Local Workspace")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
    }

    private var searchBarView: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Search pages...", text: $searchText)
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
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func matchesSearch(_ page: DocumentPage) -> Bool {
        if searchText.isEmpty { return true }
        return page.title.localizedCaseInsensitiveContains(searchText) ||
               page.rawContent.localizedCaseInsensitiveContains(searchText)
    }
}

// MARK: - Row Views

struct SidebarPageRow: View {
    let page: DocumentPage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: page.icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .frame(width: 16)

            Text(page.title)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            if page.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SidebarAgentRow: View {
    let agent: AgentItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: agent.icon)
                .font(.system(size: 13))
                .foregroundStyle(.tint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(agent.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}
