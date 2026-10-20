import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkspaceStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let page = store.selectedPage {
                DocumentCanvasView(store: store, page: page)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.tint.opacity(0.8))

                    Text("No Document Selected")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text("Choose a page from the sidebar or create a new one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        store.addNewPage()
                    }) {
                        Label("Create New Page", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .navigationTitle(store.selectedPage?.title ?? "Pustaka")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    withAnimation {
                        columnVisibility = (columnVisibility == .all) ? .detailOnly : .all
                    }
                }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
            }
        }
    }
}

#Preview {
    ContentView()
}
