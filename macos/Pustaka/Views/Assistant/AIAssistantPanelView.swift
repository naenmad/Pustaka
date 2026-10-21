import Foundation
import SwiftUI
import AppKit

// MARK: - AI Assistant Side Panel View (Universal Multi-Provider ACP & Agents)

struct AIAssistantPanelView: View {
    @ObservedObject var store: WorkspaceStore
    @StateObject private var agentService = ACPAgentService()
    @Binding var isPresented: Bool

    @State private var inputPrompt: String = ""
    @State private var copiedMessageId: UUID? = nil
    @State private var showReplaceConfirmation: Bool = false
    @State private var textToReplace: String = ""
    @State private var isSettingsOpen: Bool = false
    @State private var showCustomModelDialog: Bool = false
    @State private var customModelInput: String = ""

    private var activePage: DocumentPage? {
        store.selectedPage
    }

    private var activePageURL: URL? {
        guard let page = activePage else { return nil }
        return store.fileURL(for: page)
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
        .alert("Custom Model Identifier", isPresented: $showCustomModelDialog) {
            TextField("e.g. gemini-3.8-flash-high, claude-3-7-sonnet", text: $customModelInput)
            Button("Cancel", role: .cancel) { }
            Button("Set Model") {
                let trimmed = customModelInput.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    agentService.currentModel = trimmed
                }
            }
        } message: {
            Text("Enter a custom model identifier to send to \(agentService.currentProvider.shortName).")
        }
    }

    // MARK: - Clean Header (Top)

    private var cleanHeader: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.purple, Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                Image(systemName: agentService.currentProvider.icon)
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
            .help("AI & ACP Settings (⌘,)")

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

            Text(agentService.currentProvider.isCliAgent ? "ACP Agent" : "API Direct")
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
                    Image(systemName: agentService.currentProvider.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.orange)
                }

                VStack(spacing: 4) {
                    Text("\(agentService.currentProvider.shortName) Setup Needed")
                        .font(.system(size: 13, weight: .bold))
                    Text(onboardingDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button(action: { isSettingsOpen = true }) {
                        HStack {
                            Text("Configure in Settings (⌘,)")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }

    private var onboardingDescription: String {
        switch agentService.currentProvider {
        case .antigravity:
            return "Pustaka communicates with your local Antigravity agent (`agy`) directly via standard stdio ACP."
        case .claudeCode:
            return "Requires the `claude` CLI installed locally on your Mac (`npm install -g @anthropic-ai/claude-code`)."
        case .geminiCli:
            return "Requires the `gemini` CLI binary installed and available in your shell PATH."
        case .customAcp:
            return "Please define the command path and arguments for your custom agent in Settings."
        case .geminiApi, .openai, .claudeApi:
            return "Please configure your API credentials and endpoint in Settings."
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
                    Text("Ask questions, generate ideas, edit notes, or format data tables.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 6) {
                    suggestionChip(title: "Summarize this note", icon: "bolt.fill", prompt: "Please summarize the key takeaways of this note in 3 concise bullet points.")
                    suggestionChip(title: "Generate structured table", icon: "tablecells", prompt: "Organize the information in this note into an elegant Markdown table with 3-4 columns.")
                    suggestionChip(title: "Expand and elaborate", icon: "pencil.line", prompt: "Expand the ideas in this note with more depth, supporting arguments, and practical examples.")
                    suggestionChip(title: "Polish grammar & tone", icon: "sparkles", prompt: "Review and refine the diction in this note to sound clear, professional, and engaging.")
                    suggestionChip(title: "Generate Typst math formula", icon: "function", prompt: "Show me an elegant mathematical formula for this topic formatted as $$...$$.")
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 12)
        }
    }

    private func suggestionChip(title: String, icon: String, prompt: String) -> some View {
        Button(action: {
            inputPrompt = prompt
            dispatchPrompt()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.accentColor)
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
                    Image(systemName: agentService.currentProvider.icon)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                    Text(agentService.currentProvider.shortName)
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
                    // 1. Visible Agent Process Card (Tool executions, parameters, duration, thinking tokens)
                    AgentProcessCard(
                        steps: msg.processSteps,
                        isStreaming: msg.isStreaming,
                        thinkingTokens: msg.thinkingTokens,
                        durationSeconds: msg.durationSeconds
                    )

                    // 2. Reusable Markdown Block Canvas Rendering
                    if !msg.content.isEmpty {
                        ReusableMarkdownBlockView(rawMarkdown: msg.content)
                    }

                    if msg.isStreaming && msg.content.isEmpty {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 5, height: 5)
                            Text("Agent reasoning...")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    } else if !msg.isStreaming && !msg.content.isEmpty && !msg.content.starts(with: "[Error]") && !msg.content.starts(with: "Error:") && !msg.content.starts(with: "⚠️") && !msg.content.starts(with: "❌") {
                        Divider().opacity(0.2).padding(.vertical, 2)

                        // 3. Smart Contextual Action Buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                // Smart Apply to Note
                                Button(action: {
                                    applyResponseToNote(msg.content)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 8.5))
                                        Text("Apply to Note")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(Color.accentColor.opacity(0.12))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .help("Smartly apply changes to active note")

                                // Insert Below
                                Button(action: {
                                    insertContentBelow(msg.content)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.to.line")
                                            .font(.system(size: 8.5))
                                        Text("Insert Below")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(Color.primary.opacity(0.05))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .help("Insert content after current selection or end")

                                // Replace All Button
                                Button(action: {
                                    textToReplace = msg.content
                                    showReplaceConfirmation = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 8.5))
                                        Text("Replace All")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3.5)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .help("Replace active document with this text")

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
                                            .font(.system(size: 8.5))
                                        Text(copiedMessageId == msg.id ? "Copied" : "Copy")
                                            .font(.system(size: 10, weight: .medium))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3.5)
                                    .background(Color.primary.opacity(0.04))
                                    .foregroundStyle(.secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
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
                // Multi-line Text Editor with Enter to Send (Shift+Enter for newline)
                ChatInputEditorView(
                    text: $inputPrompt,
                    placeholder: "Ask assistant, edit note, or run tasks...",
                    onSubmit: dispatchPrompt
                )
                .frame(minHeight: 40, maxHeight: 110)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)

                Divider().opacity(0.15)

                // Bottom Controls Row: Provider, Model, Effort, Send
                HStack(spacing: 6) {
                    // 1. Provider Switcher at BOTTOM
                    bottomProviderSelectorMenu

                    // 2. Model Selector at BOTTOM
                    bottomModelSelectorMenu

                    // 3. Effort Selector at BOTTOM (for reasoning models)
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
                        .help("Send Prompt (Enter)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
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
                Text(activePage != nil ? "Note context attached" : "Vault context")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("Enter to send • ⇧Enter newline")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
    }

    // MARK: - Bottom Provider Selector Menu

    private var bottomProviderSelectorMenu: some View {
        Menu {
            ForEach(AIProviderType.allCases) { p in
                Button(action: {
                    agentService.currentProvider = p
                }) {
                    HStack {
                        Label(p.shortName, systemImage: p.icon)
                        if agentService.currentProvider == p {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: agentService.currentProvider.icon)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.accentColor)

                Text(agentService.currentProvider.shortName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3.5)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
            HStack(spacing: 3) {
                Image(systemName: "cpu")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)

                Text(currentName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
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
                    .font(.system(size: 8))
                    .foregroundStyle(Color.purple)

                Text(agentService.currentEffort.capitalized)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 6.5, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 5)
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
            activePageURL: activePageURL,
            vaultURL: store.vaultURL,
            onDiskModified: {
                if let page = activePage {
                    DispatchQueue.main.async {
                        self.store.reloadPageFromDisk(pageId: page.id)
                    }
                }
            }
        )
    }

    private func applyResponseToNote(_ content: String) {
        store.replaceActiveSelection(with: content)
    }

    private func insertContentBelow(_ content: String) {
        store.insertContentAfterActiveSelection(content)
    }

    private func replaceNoteWithContent(_ content: String) {
        let clean = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.updatePageContent(clean)
    }
}

// MARK: - NSTextView Representable for Direct Enter-to-Send

struct ChatInputEditorView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 2
        layoutManager.addTextContainer(textContainer)

        let textView = ChatInputNSTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 12.5)
        textView.textColor = NSColor.labelColor
        textView.placeholder = placeholder
        textView.onSubmit = onSubmit
        textView.delegate = context.coordinator

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? ChatInputNSTextView else { return }
        if textView.string != text {
            textView.string = text
            textView.needsDisplay = true
        }
        textView.placeholder = placeholder
        textView.onSubmit = onSubmit
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatInputEditorView
        init(_ parent: ChatInputEditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

final class ChatInputNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var placeholder: String = ""

    override func keyDown(with event: NSEvent) {
        // Return key (keyCode 36) without Shift/Command/Option submits immediately
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) && !event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.option) {
            onSubmit?()
            return // Prevent bubbling to default window button or inserting newline!
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty && !placeholder.isEmpty {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: font ?? NSFont.systemFont(ofSize: 12.5)
            ]
            let rect = NSRect(x: 2, y: 1, width: bounds.width - 4, height: bounds.height)
            (placeholder as NSString).draw(in: rect, withAttributes: attrs)
        }
    }
}

// MARK: - Agent Process Card (Visible Live Process, Tool Executions, Thinking Tokens)

struct AgentProcessCard: View {
    let steps: [AgentProcessStep]
    let isStreaming: Bool
    let thinkingTokens: Int?
    let durationSeconds: Double?

    @State private var isExpanded: Bool = false

    var body: some View {
        if !steps.isEmpty || isStreaming || (thinkingTokens ?? 0) > 0 {
            VStack(alignment: .leading, spacing: 5) {
                // Header row
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        if isStreaming {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.green)
                        }

                        Text(headerStatusText)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        if let dur = durationSeconds {
                            Text(String(format: "%.1fs", dur))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)

                // Expanded Steps Details
                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        if let tokens = thinkingTokens, tokens > 0 {
                            HStack(spacing: 5) {
                                Image(systemName: "brain")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Color.purple)
                                Text("Reasoned through context (\(tokens) thinking tokens)")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }

                        ForEach(steps) { step in
                            HStack(alignment: .top, spacing: 6) {
                                switch step.state {
                                case .running:
                                    ProgressView().controlSize(.mini).padding(.top, 2)
                                case .completed:
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.green)
                                        .padding(.top, 3)
                                case .failed:
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.red)
                                        .padding(.top, 3)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(step.title)
                                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                            .foregroundStyle(.primary)

                                        if let dur = step.durationSeconds {
                                            Text(String(format: "(%.1fs)", dur))
                                                .font(.system(size: 8.5, design: .monospaced))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

                                    if let detail = step.detail, !detail.isEmpty {
                                        Text(detail)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var headerStatusText: String {
        if isStreaming {
            let runningStep = steps.first(where: { $0.state == .running })
            if let run = runningStep {
                return "Agent executing \(run.toolName ?? "tool")..."
            }
            return "Agent processing request..."
        } else {
            let toolCount = steps.count
            if toolCount > 0 {
                return "Agent completed \(toolCount) tool action\(toolCount > 1 ? "s" : "")"
            }
            if let tokens = thinkingTokens, tokens > 0 {
                return "Agent reasoning finished (\(tokens) tokens)"
            }
            return "Agent response ready"
        }
    }
}

// MARK: - Reusable Markdown Block Canvas View (Leverages Pustaka's Block Engine & ModernTableView)

struct ReusableMarkdownBlockView: View {
    let rawMarkdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let blocks = WorkspaceStore.parseToUIBlocks(content: rawMarkdown)
            ForEach(blocks) { block in
                renderBlock(block)
            }
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: UIBlockItem) -> some View {
        switch block.kind {
        case .heading(let level):
            Text(LocalizedStringKey(block.text))
                .font(.system(size: headingSize(level), weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 2)

        case .paragraph:
            if !block.text.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .bullet:
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

        case .numbered(let index):
            HStack(alignment: .top, spacing: 6) {
                Text("\(index).")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 16, alignment: .trailing)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

        case .quote:
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: 3)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

        case .divider:
            Divider().opacity(0.3)

        case .code(let lang):
            CodeBlockCard(language: lang, code: block.text)

        case .callout(let icon, let theme):
            HStack(alignment: .top, spacing: 8) {
                DynamicIconView(icon: icon, size: 13, defaultSymbol: "info.circle.fill")
                    .foregroundStyle(theme.stroke)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.primary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.bg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.stroke.opacity(0.3), lineWidth: 1)
            )

        case .math(let expr):
            HStack {
                Spacer()
                Text(expr)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
            }

        case .grid(let headers, let rows):
            ModernTableView(
                headers: headers,
                rows: rows,
                onUpdateTable: { _, _ in },
                onDelete: { }
            )

        case .todo(let checked):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11))
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

        case .toggle(let isExpanded):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
            }

        case .bookmark(let url):
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accentColor)
                Text(url)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                    .underline()
            }

        case .image(let url, let caption):
            VStack(alignment: .center, spacing: 4) {
                Text("[Image: \(caption.isEmpty ? url : caption)]")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

        case .subpage(let pageId):
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                Text("Subpage link: \(pageId)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
