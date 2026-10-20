import SwiftUI

struct BlockListView: View {
    @ObservedObject var store: WorkspaceStore
    let page: DocumentPage
    @State private var blocks: [UIBlockItem] = []
    @State private var hoveredBlockId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                BlockRowView(
                    block: block,
                    isHovered: hoveredBlockId == block.id,
                    onUpdateText: { newText in
                        blocks[index].text = newText
                        syncBackToStore()
                    },
                    onToggleTodo: {
                        if case .todo(let checked) = blocks[index].kind {
                            blocks[index].kind = .todo(checked: !checked)
                            syncBackToStore()
                        }
                    },
                    onDelete: {
                        blocks.remove(at: index)
                        syncBackToStore()
                    }
                )
                .onHover { isHovered in
                    hoveredBlockId = isHovered ? block.id : nil
                }
            }

            // Quick "+ Add Block" Inserter Toolbar
            addBlockToolbar
                .padding(.top, 16)
        }
        .onAppear {
            self.blocks = store.parseToUIBlocks(content: page.rawContent)
        }
        .onChange(of: page.id) { _, _ in
            self.blocks = store.parseToUIBlocks(content: page.rawContent)
        }
    }

    private var addBlockToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                Button(action: { addBlock(.paragraph, text: "") }) {
                    Label("Text Paragraph", systemImage: "text.alignleft")
                }
                Button(action: { addBlock(.heading(level: 1), text: "Heading 1") }) {
                    Label("Heading 1", systemImage: "number")
                }
                Button(action: { addBlock(.heading(level: 2), text: "Heading 2") }) {
                    Label("Heading 2", systemImage: "number")
                }
                Button(action: { addBlock(.heading(level: 3), text: "Heading 3") }) {
                    Label("Heading 3", systemImage: "number")
                }
                Divider()
                Button(action: { addBlock(.callout(icon: "💡", theme: .blue), text: "New callout note") }) {
                    Label("Info Callout", systemImage: "lightbulb.fill")
                }
                Button(action: { addBlock(.callout(icon: "⚠️", theme: .red), text: "Important caution") }) {
                    Label("Warning Callout", systemImage: "exclamationmark.triangle.fill")
                }
                Button(action: { addBlock(.todo(checked: false), text: "New task") }) {
                    Label("To-do Checkbox", systemImage: "checkmark.square")
                }
                Button(action: { addBlock(.code(lang: "rust"), text: "// code here") }) {
                    Label("Code Block", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                    Text("Add Block")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)

            Spacer()
        }
    }

    private func addBlock(_ kind: UIBlockKind, text: String) {
        let newBlock = UIBlockItem(id: "blk_\(UUID().uuidString.prefix(6))", kind: kind, text: text)
        blocks.append(newBlock)
        syncBackToStore()
    }

    private func syncBackToStore() {
        let newPfs = store.uiBlocksToPfs(blocks: blocks)
        store.updatePageContent(newPfs)
    }
}

// MARK: - Individual In-Place Block Row

struct BlockRowView: View {
    let block: UIBlockItem
    let isHovered: Bool
    let onUpdateText: (String) -> Void
    let onToggleTodo: () -> Void
    let onDelete: () -> Void

    @State private var textBuffer: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Left hover handle
            Group {
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete block")
                } else {
                    Color.clear
                }
            }
            .frame(width: 18, height: 18)
            .padding(.top, 4)

            // Content according to block kind
            VStack(alignment: .leading, spacing: 4) {
                switch block.kind {
                case .heading(let level):
                    TextField("Heading \(level)...", text: $textBuffer)
                        .textFieldStyle(.plain)
                        .font(headingFont(level))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .onChange(of: textBuffer) { _, newVal in
                            onUpdateText(newVal)
                        }

                case .paragraph:
                    TextField("Type something...", text: $textBuffer, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.primary)
                        .onChange(of: textBuffer) { _, newVal in
                            onUpdateText(newVal)
                        }

                case .callout(let icon, let theme):
                    HStack(alignment: .top, spacing: 10) {
                        Text(icon)
                            .font(.title3)

                        TextField("Callout note...", text: $textBuffer, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .onChange(of: textBuffer) { _, newVal in
                                onUpdateText(newVal)
                            }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.stroke.opacity(0.4), lineWidth: 1)
                    )

                case .todo(let checked):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Button(action: onToggleTodo) {
                            Image(systemName: checked ? "checkmark.square.fill" : "square")
                                .font(.body)
                                .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        TextField("To-do task...", text: $textBuffer)
                            .textFieldStyle(.plain)
                            .font(.body)
                            .strikethrough(checked, color: .secondary)
                            .foregroundStyle(checked ? .secondary : .primary)
                            .onChange(of: textBuffer) { _, newVal in
                                onUpdateText(newVal)
                            }
                    }

                case .code(let lang):
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(lang.uppercased())
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(textBuffer, forType: .string)
                            }
                            .buttonStyle(.borderless)
                            .font(.caption2)
                        }

                        TextEditor(text: $textBuffer)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .onChange(of: textBuffer) { _, newVal in
                                onUpdateText(newVal)
                            }
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                case .grid(let columns):
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(columns, id: \.self) { col in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(col)
                                    .font(.subheadline)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(nsColor: .controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            self.textBuffer = block.text
        }
        .onChange(of: block.text) { _, newVal in
            if self.textBuffer != newVal {
                self.textBuffer = newVal
            }
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .bold)
        case 2: return .system(size: 19, weight: .bold)
        default: return .system(size: 16, weight: .bold)
        }
    }
}
