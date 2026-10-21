import SwiftUI

struct CustomizeCategorySheet: View {
    @ObservedObject var store: WorkspaceStore
    let category: SidebarCategory
    let onDismiss: () -> Void

    @State private var nameBuffer: String = ""
    @State private var iconBuffer: String = ""
    @State private var showCountBuffer: Bool = true

    private let availableEmojis = [
        "⭐️", "🤖", "👥", "🔒", "📁", "📚", "🚀", "💡",
        "🎯", "🎨", "🛠️", "⚡️", "📝", "📊", "🧩", "🔬",
        "📌", "💼", "✨", "🔥", "💻", "📦", "🏷️", "☕️"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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

            // Name & Selected Icon
            VStack(alignment: .leading, spacing: 6) {
                Text("Category Name")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(iconBuffer)
                        .font(.title2)
                        .frame(width: 38, height: 38)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

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

            // Emoji Icon Picker with Native macOS Character Palette
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon Emoji")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("Emoji...", text: $iconBuffer)
                        .textFieldStyle(.plain)
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .frame(width: 48, height: 38)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                    Button(action: {
                        NSApp.orderFrontCharacterPalette(nil)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "face.smiling")
                            Text("Open macOS Emoji Palette...")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
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
            self.iconBuffer = category.icon
            self.showCountBuffer = category.showPageCount
        }
    }
}
