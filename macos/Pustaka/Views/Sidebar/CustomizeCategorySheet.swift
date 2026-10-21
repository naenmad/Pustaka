import SwiftUI

struct CustomizeCategorySheet: View {
    @ObservedObject var store: WorkspaceStore
    let category: SidebarCategory
    let onDismiss: () -> Void

    @State private var nameBuffer: String = ""
    @State private var iconBuffer: String = "folder"
    @State private var showCountBuffer: Bool = true

    private let availableSymbols = [
        "folder", "folder.badge.gearshape", "book.closed", "doc.text",
        "tray", "archivebox", "tag", "bookmark",
        "star", "sparkles", "bolt", "terminal",
        "cpu", "hammer", "wrench.and.screwdriver", "lightbulb",
        "checkmark.seal", "chart.bar", "briefcase", "person.2",
        "lock", "shield", "cup.and.saucer", "paperplane"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Customize Category")
                    .font(.headline.weight(.semibold))

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Name & Selected Icon Preview
            VStack(alignment: .leading, spacing: 6) {
                Text("Category Name & Icon")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 38, height: 38)
                        DynamicIconView(icon: iconBuffer, size: 18, defaultSymbol: "folder")
                            .foregroundStyle(Color.accentColor)
                    }

                    TextField("Category name...", text: $nameBuffer)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            // SF Symbol Grid Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Select SF Symbol")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(availableSymbols, id: \.self) { sym in
                        let isSelected = iconBuffer == sym
                        Button(action: {
                            iconBuffer = sym
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                    )
                                Image(systemName: sym)
                                    .font(.system(size: 14))
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                            }
                            .frame(height: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Options Toggle
            Toggle(isOn: $showCountBuffer) {
                Text("Show Page Count in Sidebar")
                    .font(.subheadline)
            }
            .toggleStyle(.checkbox)

            Divider()

            // Action Buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button("Save Changes") {
                    let trimmed = nameBuffer.trimmingCharacters(in: .whitespaces)
                    let finalName = trimmed.isEmpty ? category.name : trimmed
                    store.updateCategory(id: category.id, newName: finalName, newIcon: iconBuffer)
                    if category.showPageCount != showCountBuffer {
                        store.toggleShowPageCount(id: category.id)
                    }
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            self.nameBuffer = category.name
            let rawIcon = category.icon.trimmingCharacters(in: .whitespaces)
            self.iconBuffer = rawIcon.isEmpty || rawIcon == "📁" ? "folder" : rawIcon
            self.showCountBuffer = category.showPageCount
        }
    }
}
