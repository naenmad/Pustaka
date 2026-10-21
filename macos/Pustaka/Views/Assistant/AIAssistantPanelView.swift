import SwiftUI

// MARK: - AI Assistant Side Panel View (Zed ACP & Multi-Provider)

struct AIAssistantPanelView: View {
    @ObservedObject var store: WorkspaceStore
    @StateObject private var agentService = ACPAgentService()
    @Binding var isPresented: Bool

    @State private var inputPrompt: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var copiedMessageId: UUID? = nil
    @State private var showReplaceConfirmation: Bool = false
    @State private var textToReplace: String = ""
    @State private var isSettingsOpen: Bool = false

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

            // 3. Conversation ScrollView OR Onboarding Card
            if !agentService.isAgentAvailable && agentService.messages.isEmpty {
                providerOnboardingView
            } else if agentService.messages.isEmpty {
                emptyStateSuggestionsView
            } else {
                conversationMessagesView
            }

            Divider().opacity(0.3)

            // 4. Prompt Input & Dispatch Area
            promptInputArea
        }
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            agentService.checkAgentAvailability()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .alert("Replace Document Content?", isPresented: $showReplaceConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Replace Content", role: .destructive) {
                replaceNoteWithContent(textToReplace)
            }
        } message: {
            Text("This will replace the content of '\(activePage?.title ?? "Document")' with the AI response. You can undo this later via document history.")
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

                Image(systemName: agentService.currentProvider.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(agentService.currentProvider.label)
                        .font(.system(size: 11.5, weight: .bold))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(agentService.isAgentAvailable ? Color.green : Color.orange)
                        .frame(width: 5.5, height: 5.5)
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
                Text("No note selected (Vault context)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("ACP Mode")
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

    // MARK: - Provider Onboarding View (When CLI / API Key Not Configured)

    private var providerOnboardingView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                Spacer().frame(height: 8)

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.orange)
                }

                VStack(spacing: 4) {
                    Text("Connect an AI Provider")
                        .font(.system(size: 13, weight: .bold))
                    Text("Pustaka supports local Antigravity CLI (Zed ACP), Google Gemini, OpenAI, and Claude.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    // Option A: Antigravity CLI
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "terminal")
                                .font(.system(size: 11))
                            Text("Antigravity CLI (Recommended)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        Text("Zero-setup local agent if `agy` is installed.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("curl -sSL https://antigravity.google/install.sh | bash", forType: .string)
                        }) {
                            HStack {
                                Text("Copy CLI Install Command")
                                Spacer()
                                Image(systemName: "doc.on.doc")
                            }
                            .font(.system(size: 10.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Option B: Open Settings to Configure API Key
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "key")
                                .font(.system(size: 11))
                            Text("Direct API Keys (Gemini, OpenAI, Claude)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        Text("Paste your free Gemini or OpenAI key in Settings to use without terminal.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("Press ⌘, to configure in Settings → AI & ACP")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
        }
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
                    Text("Assistant")
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
                    if msg.role == .user {
                        Text(msg.content)
                            .font(.system(size: 12))
                            .lineSpacing(2)
                            .foregroundStyle(Color.white)
                            .textSelection(.enabled)
                    } else {
                        // Render formatted Markdown (No raw asterisks, bold/italic, code blocks)
                        FormattedMarkdownMessageView(markdown: msg.content)
                    }
                }

                // Assistant Action Bar
                if msg.role == .assistant && !msg.content.isEmpty && !msg.isStreaming {
                    HStack(spacing: 6) {
                        // 1. Direct Replace Button (User requested: "minta tolong langsung edit")
                        Button(action: {
                            textToReplace = msg.content
                            showReplaceConfirmation = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil.and.outline")
                                Text("Replace Note")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Replace active note with this text")

                        // 2. Append to Note Button
                        Button(action: {
                            appendContentToCurrentNote(msg.content)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down.doc.fill")
                                Text("Append")
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(.plain)
                        .help("Append this text to the end of the note")

                        // 3. Copy Button
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
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
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
                TextField("Ask Assistant... (↵ send)", text: $inputPrompt, axis: .vertical)
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

    private func replaceNoteWithContent(_ content: String) {
        guard let page = activePage else { return }
        store.updatePageContent(pageId: page.id, newContent: content)
    }
}

// MARK: - Formatted Markdown Message View (No Raw Asterisks, Full Typography)

struct FormattedMarkdownMessageView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let lines = markdown.components(separatedBy: "\n")
            var inCodeBlock = false
            var codeBuffer = ""

            ForEach(Array(lines.enumerated()), id: \.offset) { _, rawLine in
                let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("```") {
                    if inCodeBlock {
                        // End code block
                        CodeBlockCard(code: codeBuffer)
                        let _ = { codeBuffer = ""; inCodeBlock = false }()
                    } else {
                        // Start code block
                        let _ = { inCodeBlock = true; codeBuffer = "" }()
                    }
                } else if inCodeBlock {
                    let _ = { codeBuffer += (codeBuffer.isEmpty ? "" : "\n") + rawLine }()
                } else if trimmed.hasPrefix("### ") {
                    Text(LocalizedStringKey(String(trimmed.dropFirst(4))))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 2)
                } else if trimmed.hasPrefix("## ") {
                    Text(LocalizedStringKey(String(trimmed.dropFirst(3))))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                } else if trimmed.hasPrefix("# ") {
                    Text(LocalizedStringKey(String(trimmed.dropFirst(2))))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                } else if trimmed.hasPrefix("> ") {
                    HStack(alignment: .top, spacing: 6) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 2.5)
                        Text(LocalizedStringKey(String(trimmed.dropFirst(2))))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                } else if trimmed == "---" {
                    Divider().opacity(0.4)
                } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                    HStack(alignment: .top, spacing: 5) {
                        Text("•")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(LocalizedStringKey(String(trimmed.dropFirst(2))))
                            .font(.system(size: 12))
                            .lineSpacing(2)
                            .foregroundStyle(.primary)
                    }
                } else if !trimmed.isEmpty {
                    Text(LocalizedStringKey(trimmed))
                        .font(.system(size: 12))
                        .lineSpacing(2)
                        .foregroundStyle(.primary)
                }
            }
        }
        .textSelection(.enabled)
    }
}

// MARK: - Code Block Card

struct CodeBlockCard: View {
    let code: String
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Code")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04))

            Divider().opacity(0.2)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .padding(8)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .padding(.vertical, 2)
    }
}
