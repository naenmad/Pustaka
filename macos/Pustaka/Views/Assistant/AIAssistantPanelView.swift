import SwiftUI

// MARK: - AI Assistant Side Panel View (Zed ACP Inspired)

struct AIAssistantPanelView: View {
    @ObservedObject var store: WorkspaceStore
    @StateObject private var agentService = ACPAgentService()
    @Binding var isPresented: Bool

    @State private var inputPrompt: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var copiedMessageId: UUID? = nil

    private var activePage: DocumentPage? {
        store.selectedPage
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Assistant Header
            assistantHeader

            Divider().opacity(0.3)

            // 2. Active Note Context Bar
            contextBadgeBar

            Divider().opacity(0.2)

            // 3. Conversation ScrollView
            if agentService.messages.isEmpty {
                emptyStateSuggestionsView
            } else {
                conversationMessagesView
            }

            Divider().opacity(0.3)

            // 4. Prompt Input & Dispatch Area
            promptInputArea
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            agentService.checkAgentAvailability()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }

    // MARK: - Header

    private var assistantHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)

                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("Antigravity")
                        .font(.system(size: 12.5, weight: .bold))
                    Text("ACP")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(agentService.isAgentAvailable ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(agentService.statusMessage)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !agentService.messages.isEmpty {
                Button(action: { agentService.clearHistory() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Clear Chat History")
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close Assistant (⌘J)")
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
    }

    // MARK: - Context Badge Bar

    private var contextBadgeBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if let page = activePage {
                Text("Context:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                Text("No note selected (General Vault context)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Vault Mode")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Empty State Suggestions

    private var emptyStateSuggestionsView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer().frame(height: 12)

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 4) {
                    Text("How can I assist your writing?")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Ask questions, generate ideas, fix tone, or transform blocks.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 6) {
                    suggestionChip(title: "⚡ Summarize this note", prompt: "Please summarize the key takeaways of this note in 3 concise bullet points.")
                    suggestionChip(title: "✍️ Expand and elaborate", prompt: "Expand the ideas in this note with more depth, supporting arguments, and practical examples.")
                    suggestionChip(title: "✨ Polish grammar & diction", prompt: "Review and refine the diction and phrasing in this note to sound more professional and engaging.")
                    suggestionChip(title: "📐 Generate Typst math formula", prompt: "Show me an elegant mathematical formula written in Typst markup syntax for this topic.")
                    suggestionChip(title: "📑 Suggest subpage outline", prompt: "Suggest 3-4 structured subpages that would naturally expand on this document.")
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
        }
    }

    private func suggestionChip(title: String, prompt: String) -> some View {
        Button(action: {
            inputPrompt = prompt
            dispatchPrompt()
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Conversation Messages View

    private var conversationMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 12) {
                    ForEach(agentService.messages) { msg in
                        messageBubbleRow(msg)
                            .id(msg.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: agentService.messages.last?.content) { _ in
                if let lastId = agentService.messages.last?.id {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubbleRow(_ msg: AIChatMessage) -> some View {
        VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 5) {
                if msg.role == .assistant {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text("Antigravity")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Spacer()
                    Text("You")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Message Bubble Card
            VStack(alignment: .leading, spacing: 6) {
                if msg.content.isEmpty && msg.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Generating response...")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                } else {
                    Text(msg.content)
                        .font(.system(size: 12))
                        .lineSpacing(3)
                        .foregroundStyle(msg.role == .user ? Color.white : Color.primary)
                        .textSelection(.enabled)
                }

                // Assistant Action Bar
                if msg.role == .assistant && !msg.content.isEmpty && !msg.isStreaming {
                    HStack(spacing: 8) {
                        Button(action: {
                            appendContentToCurrentNote(msg.content)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Append to Note")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Append this text to the end of the active note")

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg.content, forType: .string)
                            copiedMessageId = msg.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedMessageId == msg.id { copiedMessageId = nil }
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: copiedMessageId == msg.id ? "checkmark" : "doc.on.doc")
                                Text(copiedMessageId == msg.id ? "Copied" : "Copy")
                            }
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(msg.role == .user ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(msg.role == .user ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: msg.role == .user ? .trailing : .leading)
    }

    // MARK: - Prompt Input Area

    private var promptInputArea: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 6) {
                // Multi-line Text Field
                TextField("Ask Antigravity... (↵ send)", text: $inputPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .font(.system(size: 12))
                    .focused($isInputFocused)
                    .onSubmit {
                        dispatchPrompt()
                    }

                // Send / Stop Button
                if agentService.isStreaming {
                    Button(action: { agentService.cancelCurrentStream() }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .help("Stop generating")
                } else {
                    Button(action: dispatchPrompt) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.4) : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                    .help("Send Message")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isInputFocused ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(10)
    }

    private func dispatchPrompt() {
        let text = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !agentService.isStreaming else { return }
        inputPrompt = ""
        agentService.sendMessage(
            prompt: text,
            activePage: activePage,
            vaultURL: store.vaultURL
        )
    }

    private func appendContentToCurrentNote(_ content: String) {
        guard let page = activePage else { return }
        var current = page.rawContent
        if !current.isEmpty && !current.hasSuffix("\n\n") {
            current += current.hasSuffix("\n") ? "\n" : "\n\n"
        }
        current += content
        store.updatePageContent(pageId: page.id, newContent: current)
    }
}
