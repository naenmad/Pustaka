import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkspaceStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow))
        } detail: {
            if let page = store.selectedPage {
                DocumentCanvasView(store: store, page: page)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("No Document Selected")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Choose a document from the sidebar or create a new one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: {
                        store.addNewPage()
                    }) {
                        Label("New Document", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
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
