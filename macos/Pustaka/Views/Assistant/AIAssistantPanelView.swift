import SwiftUI

// MARK: - AI Assistant Side Panel View (Dedicated Antigravity ACP)

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
    @State private var showCustomModelDialog: Bool = false
    @State private var customModelInput: String = ""

    private var activePage: DocumentPage? {
        store.selectedPage
    }

    var body: some View {
        VStack(spacing: 0) {
            // 1. Clean Top Header
            cleanHeader

            Divider().opacity(0.3)

            // 2. Active Note Context Bar
            contextBadgeBar

            Divider().opacity(0.2)

            // 3. Messages ScrollView OR Onboarding Card
            if !agentService.isAgentAvailable && agentService.messages.isEmpty {
                providerOnboardingView
            } else if agentService.messages.isEmpty {
                emptyStateSuggestionsView
            } else {
                conversationMessagesView
            }

            Divider().opacity(0.3)

            // 4. Bottom Prompt Input Area with Model & Effort Pickers at the BOTTOM
            bottomInputArea
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            agentService.checkAgentAvailability()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .sheet(isPresented: $isSettingsOpen) {
            SettingsSheet(
                store: store,
                initialTab: .ai,
                onDismiss: {
                    isSettingsOpen = false
                    agentService.checkAgentAvailability()
                }
            )
        }
        .alert("Replace Document Content?", isPresented: $showReplaceConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Replace Content", role: .destructive) {
                replaceNoteWithContent(textToReplace)
            }
        } message: {
            Text("This will replace the content of '\(activePage?.title ?? "Document")' with the AI response. You can undo this later via document history.")
        }
        .alert("Custom Model ID", isPresented: $showCustomModelDialog) {
            TextField("e.g. gemini-3.8-flash-high, claude-sonnet-4-6", text: $customModelInput)
            Button("Cancel", role: .cancel) { }
            Button("Set Model") {
                let trimmed = customModelInput.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    agentService.currentModel = trimmed
                }
            }
        } message: {
            Text("Enter model identifier for the Antigravity ACP session.")
        }
    }

    // MARK: - Clean Header (Top)

    private var cleanHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.purple, Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(agentService.currentProvider.shortName)
                    .font(.system(size: 12, weight: .bold))

                HStack(spacing: 4) {
                    Circle()
                        .fill(agentService.isAgentAvailable ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(agentService.statusMessage)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Settings Gear Button
            Button(action: { isSettingsOpen = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("AI Settings (⌘,)")

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
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close Assistant (⌘J)")
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
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
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1.5)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.02))
    }

    // MARK: - Provider Onboarding View

    private var providerOnboardingView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 14) {
                Spacer().frame(height: 12)

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.orange)
                }

                VStack(spacing: 4) {
                    Text("Antigravity CLI Required")
                        .font(.system(size: 13, weight: .bold))
                    Text("Pustaka communicates with your local Antigravity agent (`agy`) via standard Zed ACP protocol.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "terminal")
                                .font(.system(size: 11))
                            Text("Antigravity CLI (Recommended)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        Text("Free, unlimited AI assistant logged into your Google account on macOS.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Button(action: { isSettingsOpen = true }) {
                            HStack {
                                Text("Configure in Settings (⌘,)")
                                Spacer()
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
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

            if msg.role == .assistant {
                VStack(alignment: .leading, spacing: 8) {
                    FormattedMarkdownMessageView(rawMarkdown: msg.content)

                    if msg.isStreaming {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                            Text("Agent typing...")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    } else if !msg.content.isEmpty && !msg.content.starts(with: "⚠️") && !msg.content.starts(with: "❌") {
                        Divider().opacity(0.2).padding(.vertical, 2)

                        HStack(spacing: 8) {
                            // Direct Replace Note Button
                            Button(action: {
                                textToReplace = msg.content
                                showReplaceConfirmation = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 9))
                                    Text("Replace Note")
                                        .font(.system(size: 10.5, weight: .semibold))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.orange.opacity(0.12))
                                .foregroundStyle(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Replace active document with this text")

                            // Append to Note Button
                            Button(action: {
                                appendContentToNote(msg.content)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 9))
                                    Text("Append")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3.5)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            .help("Append response to end of active document")

                            // Copy Raw Text Button
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(msg.content, forType: .string)
                                copiedMessageId = msg.id
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    if copiedMessageId == msg.id { copiedMessageId = nil }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedMessageId == msg.id ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 9))
                                    Text(copiedMessageId == msg.id ? "Copied" : "Copy")
                                        .font(.system(size: 10.5, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3.5)
                                .background(Color.primary.opacity(0.04))
                                .foregroundStyle(.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            } else {
                Text(msg.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Bottom Prompt Input Area (Model & Effort Pickers at the BOTTOM)

    private var bottomInputArea: some View {
        VStack(spacing: 6) {
            // Main Input Container
            VStack(spacing: 0) {
                // Multi-line Text Editor
                TextEditor(text: $inputPrompt)
                    .font(.system(size: 12.5))
                    .frame(minHeight: 40, maxHeight: 110)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .padding(8)

                Divider().opacity(0.15)

                // Bottom Controls Row: Model Picker, Effort Picker, Send Button
                HStack(spacing: 6) {
                    // 1. Model Selector at BOTTOM
                    bottomModelSelectorMenu

                    // 2. Effort Selector at BOTTOM
                    if agentService.currentProvider == .antigravity {
                        bottomEffortSelectorMenu
                    }

                    Spacer()

                    // Send or Stop Button
                    if agentService.isStreaming {
                        Button(action: {
                            agentService.cancelCurrentStream()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Stop Generation")
                    } else {
                        Button(action: dispatchPrompt) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("Send Prompt")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.015))
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            // Hint Text
            HStack {
                Text(activePage != nil ? "Note context attached" : "Global vault context")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("Return to send")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
    }

    // MARK: - Bottom Model Selector Menu

    private var bottomModelSelectorMenu: some View {
        let models = AIModelRegistry.models(for: agentService.currentProvider)
        let currentName = AIModelRegistry.displayName(for: agentService.currentModel, in: agentService.currentProvider)

        return Menu {
            ForEach(models) { m in
                Button(action: {
                    agentService.currentModel = m.id
                }) {
                    HStack {
                        Text(m.name)
                        if let badge = m.badge {
                            Text("[\(badge)]")
                        }
                        if agentService.currentModel == m.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button(action: {
                customModelInput = agentService.currentModel
                showCustomModelDialog = true
            }) {
                Label("Custom Model...", systemImage: "pencil")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.accentColor)

                Text(currentName)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Bottom Reasoning Effort Menu

    private var bottomEffortSelectorMenu: some View {
        Menu {
            Button(action: { agentService.currentEffort = "default" }) {
                HStack {
                    Text("Auto / Default")
                    if agentService.currentEffort == "default" { Image(systemName: "checkmark") }
                }
            }
            Button(action: { agentService.currentEffort = "low" }) {
                HStack {
                    Text("Low (Fastest)")
                    if agentService.currentEffort == "low" { Image(systemName: "checkmark") }
                }
            }
            Button(action: { agentService.currentEffort = "medium" }) {
                HStack {
                    Text("Medium (Balanced)")
                    if agentService.currentEffort == "medium" { Image(systemName: "checkmark") }
                }
            }
            Button(action: { agentService.currentEffort = "high" }) {
                HStack {
                    Text("High (Deep Thinking)")
                    if agentService.currentEffort == "high" { Image(systemName: "checkmark") }
                }
            }
            Button(action: { agentService.currentEffort = "max" }) {
                HStack {
                    Text("Max (Maximum Intelligence)")
                    if agentService.currentEffort == "max" { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "brain")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.purple)

                Text("Effort: \(agentService.currentEffort.capitalized)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color.purple.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Document Actions

    private func dispatchPrompt() {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputPrompt = ""

        agentService.sendMessage(
            prompt: trimmed,
            activePage: activePage,
            vaultURL: store.vaultURL
        )
    }

    private func appendContentToNote(_ content: String) {
        guard let page = activePage else { return }
        let cleanAddition = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAddition.isEmpty else { return }

        var updated = page.rawContent
        if !updated.isEmpty && !updated.hasSuffix("\n\n") {
            updated += updated.hasSuffix("\n") ? "\n" : "\n\n"
        }
        updated += cleanAddition

        store.updatePageContent(updated)
    }

    private func replaceNoteWithContent(_ content: String) {
        guard let page = activePage else { return }
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        store.updatePageContent(clean)
    }
}

// MARK: - Formatted Markdown Message View (No Raw Asterisks)

struct FormattedMarkdownMessageView: View {
    let rawMarkdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let blocks = MarkdownBlockParser.parse(rawMarkdown)
            ForEach(blocks) { block in
                switch block.type {
                case .code(let lang, let code):
                    CodeBlockCard(language: lang, code: code)
                case .heading(let level, let text):
                    Text(LocalizedStringKey(text))
                        .font(.system(size: headingSize(level), weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 2)
                case .quote(let text):
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 3)
                        Text(LocalizedStringKey(text))
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                case .bullet(let text):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                        Text(LocalizedStringKey(text))
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                    }
                case .divider:
                    Divider().opacity(0.3)
                case .paragraph(let text):
                    Text(LocalizedStringKey(text))
                        .font(.system(size: 12))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 15
        case 2: return 13.5
        default: return 12.5
        }
    }
}

// MARK: - Code Block Card

struct CodeBlockCard: View {
    let language: String
    let code: String

    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
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
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 8.5))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04))

            Divider().opacity(0.2)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(10)
                    .textSelection(.enabled)
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Markdown Block Parser

enum MarkdownParsedBlockType {
    case code(lang: String, content: String)
    case heading(level: Int, text: String)
    case quote(text: String)
    case bullet(text: String)
    case divider
    case paragraph(text: String)
}

struct MarkdownParsedBlock: Identifiable {
    let id = UUID()
    let type: MarkdownParsedBlockType
}

enum MarkdownBlockParser {
    static func parse(_ raw: String) -> [MarkdownParsedBlock] {
        var blocks: [MarkdownParsedBlock] = []
        var inCode = false
        var codeLang = ""
        var codeLines: [String] = []

        let lines = raw.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if !inCode {
                    inCode = true
                    codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLines.removeAll()
                } else {
                    inCode = false
                    blocks.append(MarkdownParsedBlock(type: .code(lang: codeLang, content: codeLines.joined(separator: "\n"))))
                }
                continue
            }

            if inCode {
                codeLines.append(line)
                continue
            }

            if trimmed.isEmpty {
                continue
            }

            if trimmed.hasPrefix("### ") {
                blocks.append(MarkdownParsedBlock(type: .heading(level: 3, text: String(trimmed.dropFirst(4)))))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(MarkdownParsedBlock(type: .heading(level: 2, text: String(trimmed.dropFirst(3)))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(MarkdownParsedBlock(type: .heading(level: 1, text: String(trimmed.dropFirst(2)))))
            } else if trimmed.hasPrefix("> ") {
                blocks.append(MarkdownParsedBlock(type: .quote(text: String(trimmed.dropFirst(2)))))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(MarkdownParsedBlock(type: .bullet(text: String(trimmed.dropFirst(2)))))
            } else if trimmed == "---" || trimmed == "___" {
                blocks.append(MarkdownParsedBlock(type: .divider))
            } else {
                blocks.append(MarkdownParsedBlock(type: .paragraph(text: trimmed)))
            }
        }

        if inCode {
            blocks.append(MarkdownParsedBlock(type: .code(lang: codeLang, content: codeLines.joined(separator: "\n"))))
        }

        return blocks
    }
}
