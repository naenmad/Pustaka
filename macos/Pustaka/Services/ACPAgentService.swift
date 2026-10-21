import Foundation
import SwiftUI

// MARK: - AI Provider Enum (Zed ACP & Direct APIs)

enum AIProviderType: String, CaseIterable, Identifiable {
    // Local ACP Coding Agents (Zed ACP Standard)
    case antigravity = "antigravity"
    case claudeCode  = "claude_code"
    case geminiCli   = "gemini_cli"
    case customAcp   = "custom_acp"

    // Direct Cloud & Local LLM APIs
    case geminiApi   = "gemini_api"
    case openai      = "openai"
    case claudeApi   = "claude_api"

    var id: String { rawValue }

    var isLocalAcp: Bool {
        switch self {
        case .antigravity, .claudeCode, .geminiCli, .customAcp:
            return true
        default:
            return false
        }
    }

    var label: String {
        switch self {
        case .antigravity: return "Antigravity CLI (Zed ACP)"
        case .claudeCode:  return "Claude Code CLI"
        case .geminiCli:   return "Gemini CLI"
        case .customAcp:   return "Custom ACP Server"
        case .geminiApi:   return "Google Gemini API"
        case .openai:      return "OpenAI / OpenRouter / DeepSeek"
        case .claudeApi:   return "Anthropic Claude API"
        }
    }

    var shortName: String {
        switch self {
        case .antigravity: return "Antigravity"
        case .claudeCode:  return "Claude Code"
        case .geminiCli:   return "Gemini CLI"
        case .customAcp:   return "Custom ACP"
        case .geminiApi:   return "Gemini API"
        case .openai:      return "OpenAI / DeepSeek"
        case .claudeApi:   return "Claude API"
        }
    }

    var icon: String {
        switch self {
        case .antigravity: return "sparkles"
        case .claudeCode:  return "terminal.fill"
        case .geminiCli:   return "bolt.fill"
        case .customAcp:   return "gearshape.2.fill"
        case .geminiApi:   return "wand.and.stars"
        case .openai:      return "cpu"
        case .claudeApi:   return "brain"
        }
    }

    static func from(raw: String) -> AIProviderType {
        if raw == "gemini" { return .geminiApi }
        if raw == "claude" { return .claudeApi }
        return AIProviderType(rawValue: raw) ?? .antigravity
    }
}

// MARK: - Model Option Model & Registry

struct AIModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let badge: String?
    let description: String?

    init(id: String, name: String, badge: String? = nil, description: String? = nil) {
        self.id = id
        self.name = name
        self.badge = badge
        self.description = description
    }
}

enum AIModelRegistry {
    static func models(for provider: AIProviderType) -> [AIModelOption] {
        switch provider {
        case .antigravity:
            return [
                AIModelOption(id: "gemini-3.8-flash-high", name: "Gemini 3.8 Flash (High)", badge: "Smart", description: "Fast multimodal with high reasoning effort"),
                AIModelOption(id: "gemini-3.8-flash-medium", name: "Gemini 3.8 Flash (Medium)", badge: "Balanced", description: "Balanced reasoning effort and low latency"),
                AIModelOption(id: "gemini-3.8-flash-low", name: "Gemini 3.8 Flash (Low)", badge: "Fast", description: "Ultra-low latency for instant responses"),
                AIModelOption(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", badge: "Reasoning", description: "Anthropic Claude with extended thinking"),
                AIModelOption(id: "claude-opus-4-6-thinking", name: "Claude Opus 4.6", badge: "Deep", description: "Deepest reasoning and maximum capability"),
                AIModelOption(id: "gpt-oss-120b-medium", name: "GPT-OSS 120B", badge: "Open", description: "Open source foundation model"),
                AIModelOption(id: "default", name: "Session Default", badge: "Auto", description: "Inherit model configured in active CLI session")
            ]
        case .claudeCode:
            return [
                AIModelOption(id: "claude-3-7-sonnet-latest", name: "Claude 3.7 Sonnet", badge: "Latest", description: "Flagship hybrid thinking model"),
                AIModelOption(id: "claude-3-5-sonnet-latest", name: "Claude 3.5 Sonnet", badge: "Popular", description: "Coding and synthesis specialist"),
                AIModelOption(id: "claude-3-5-haiku-latest", name: "Claude 3.5 Haiku", badge: "Fast", description: "Fastest response time"),
                AIModelOption(id: "default", name: "CLI Default", badge: "Auto", description: "Default configured in Claude Code")
            ]
        case .geminiCli:
            return [
                AIModelOption(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", badge: "Fast", description: "High-speed multimodal responses"),
                AIModelOption(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", badge: "Smart", description: "Advanced reasoning for complex tasks"),
                AIModelOption(id: "default", name: "CLI Default", badge: "Auto", description: "Default configured in Gemini CLI")
            ]
        case .customAcp:
            return [
                AIModelOption(id: "default", name: "Server Default", badge: "Auto", description: "Default model handled by external ACP server")
            ]
        case .geminiApi:
            return [
                AIModelOption(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", badge: "Recommended", description: "Google's recommended everyday fast model"),
                AIModelOption(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", badge: "Smart", description: "Best for deep analysis and long documents"),
                AIModelOption(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", badge: "Fast", description: "High throughput next-generation flash"),
                AIModelOption(id: "gemini-2.0-flash-lite", name: "Gemini 2.0 Flash Lite", badge: "Lite", description: "Cost-effective lightweight responses")
            ]
        case .openai:
            return [
                AIModelOption(id: "gpt-4o", name: "GPT-4o (OpenAI)", badge: "Flagship", description: "Most capable model for writing and editing"),
                AIModelOption(id: "gpt-4o-mini", name: "GPT-4o Mini (OpenAI)", badge: "Fast", description: "Fast, cost-efficient everyday assistance"),
                AIModelOption(id: "o3-mini", name: "o3-mini (OpenAI)", badge: "Reasoning", description: "High-speed reasoning model"),
                AIModelOption(id: "deepseek-chat", name: "DeepSeek V3", badge: "DeepSeek", description: "Powerful open-weights general chat model"),
                AIModelOption(id: "deepseek-reasoner", name: "DeepSeek R1", badge: "Reasoning", description: "Open reasoning model with visible thinking"),
                AIModelOption(id: "anthropic/claude-3.5-sonnet", name: "Claude 3.5 Sonnet", badge: "OpenRouter", description: "Claude routed via OpenRouter endpoint"),
                AIModelOption(id: "qwen/qwen-2.5-coder-32b-instruct", name: "Qwen 2.5 Coder 32B", badge: "Coding", description: "Via Ollama or OpenRouter"),
                AIModelOption(id: "llama3.3:70b", name: "Llama 3.3 70B", badge: "Local", description: "Local model via Ollama endpoint")
            ]
        case .claudeApi:
            return [
                AIModelOption(id: "claude-3-7-sonnet-latest", name: "Claude 3.7 Sonnet", badge: "Latest", description: "Flagship hybrid thinking model"),
                AIModelOption(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", badge: "Popular", description: "Industry-standard coding and synthesis"),
                AIModelOption(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", badge: "Fast", description: "Low latency and economical")
            ]
        }
    }

    static func defaultModel(for provider: AIProviderType) -> String {
        switch provider {
        case .antigravity: return "gemini-3.8-flash-high"
        case .claudeCode:  return "claude-3-7-sonnet-latest"
        case .geminiCli:   return "gemini-2.5-flash"
        case .customAcp:   return "default"
        case .geminiApi:   return "gemini-2.5-flash"
        case .openai:      return "gpt-4o"
        case .claudeApi:   return "claude-3-7-sonnet-latest"
        }
    }

    static func displayName(for modelId: String, in provider: AIProviderType) -> String {
        if let found = models(for: provider).first(where: { $0.id == modelId }) {
            return found.name
        }
        return modelId.isEmpty || modelId == "default" ? "Default" : modelId
    }
}

// MARK: - Chat Message Model

struct AIChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool

    enum MessageRole: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}

// MARK: - Universal ACP & AI Agent Service

class ACPAgentService: ObservableObject {
    @Published var messages: [AIChatMessage] = []
    @Published var isStreaming: Bool = false
    @Published var statusMessage: String = "Ready"
    @Published var isAgentAvailable: Bool = false

    @Published var currentProvider: AIProviderType {
        didSet {
            UserDefaults.standard.set(currentProvider.rawValue, forKey: "aiProviderType")
            self.currentModel = Self.savedModel(for: currentProvider)
            checkAgentAvailability()
        }
    }

    @Published var currentModel: String {
        didSet {
            UserDefaults.standard.set(currentModel, forKey: "aiModel_\(currentProvider.rawValue)")
            // Keep legacy keys in sync
            switch currentProvider {
            case .antigravity:
                UserDefaults.standard.set(currentModel, forKey: "aiAgentModel")
            case .geminiApi:
                UserDefaults.standard.set(currentModel, forKey: "geminiModel")
            case .openai:
                UserDefaults.standard.set(currentModel, forKey: "openaiModel")
            case .claudeApi:
                UserDefaults.standard.set(currentModel, forKey: "claudeModel")
            default:
                break
            }
        }
    }

    @Published var currentEffort: String {
        didSet {
            UserDefaults.standard.set(currentEffort, forKey: "aiAgentEffort")
        }
    }

    private var currentProcess: Process?
    private var currentTask: URLSessionDataTask?

    // Default Antigravity CLI path on macOS
    static let defaultAgyPath: String = {
        let userLocal = ("~/.local/bin/agy" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userLocal) {
            return userLocal
        }
        return "/usr/local/bin/agy"
    }()

    init() {
        let rawProvider = UserDefaults.standard.string(forKey: "aiProviderType") ?? AIProviderType.antigravity.rawValue
        let provider = AIProviderType.from(raw: rawProvider)
        self.currentProvider = provider
        self.currentModel = Self.savedModel(for: provider)
        self.currentEffort = UserDefaults.standard.string(forKey: "aiAgentEffort") ?? "high"

        checkAgentAvailability()
    }

    static func savedModel(for provider: AIProviderType) -> String {
        if let stored = UserDefaults.standard.string(forKey: "aiModel_\(provider.rawValue)"), !stored.isEmpty {
            return stored
        }
        switch provider {
        case .antigravity:
            let legacy = UserDefaults.standard.string(forKey: "aiAgentModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        case .geminiApi:
            let legacy = UserDefaults.standard.string(forKey: "geminiModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        case .openai:
            let legacy = UserDefaults.standard.string(forKey: "openaiModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        case .claudeApi:
            let legacy = UserDefaults.standard.string(forKey: "claudeModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        default:
            return AIModelRegistry.defaultModel(for: provider)
        }
    }

    // MARK: - Dynamic Executable Path Resolver

    static func resolveExecutablePath(command: String, preferredPath: String? = nil) -> String? {
        if let pref = preferredPath, !pref.trimmingCharacters(in: .whitespaces).isEmpty {
            let expanded = (pref as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return expanded
            }
        }

        let candidates = [
            ("~/.local/bin/\(command)" as NSString).expandingTildeInPath,
            "/usr/local/bin/\(command)",
            "/opt/homebrew/bin/\(command)",
            "/usr/bin/\(command)",
            ("/Users/mac/.local/state/fnm_multishells/1805_1792558437123/bin/\(command)" as NSString).expandingTildeInPath
        ]
        for p in candidates {
            if FileManager.default.isExecutableFile(atPath: p) {
                return p
            }
        }

        // Query zsh login shell PATH
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-c", "which \(command)"]
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !out.isEmpty, FileManager.default.isExecutableFile(atPath: out) {
                return out
            }
        } catch {}

        return nil
    }

    // Strip ANSI escape codes from CLI terminal text
    static func stripAnsiCodes(_ str: String) -> String {
        return str.replacingOccurrences(of: #"\x1B\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression)
    }

    // MARK: - Availability Check

    func checkAgentAvailability() {
        switch currentProvider {
        case .antigravity:
            let preferred = UserDefaults.standard.string(forKey: "aiAgentCliPath") ?? Self.defaultAgyPath
            let resolved = Self.resolveExecutablePath(command: "agy", preferredPath: preferred)
            let ready = (resolved != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Antigravity Ready" : "agy CLI Missing"
            }
        case .claudeCode:
            let preferred = UserDefaults.standard.string(forKey: "claudeCodeCliPath") ?? "claude"
            let resolved = Self.resolveExecutablePath(command: "claude", preferredPath: preferred)
            let ready = (resolved != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Claude Code Ready" : "claude CLI Missing"
            }
        case .geminiCli:
            let preferred = UserDefaults.standard.string(forKey: "geminiCliPath") ?? "gemini"
            let resolved = Self.resolveExecutablePath(command: "gemini", preferredPath: preferred)
            let ready = (resolved != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Gemini CLI Ready" : "gemini CLI Missing"
            }
        case .customAcp:
            let cmd = UserDefaults.standard.string(forKey: "customAcpCommand") ?? "npx"
            let resolved = Self.resolveExecutablePath(command: cmd, preferredPath: cmd)
            let ready = (resolved != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Custom ACP Ready" : "'\(cmd)' Missing"
            }
        case .geminiApi:
            let key = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
            let hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = hasKey
                self.statusMessage = hasKey ? "Gemini API Ready" : "API Key Required"
            }
        case .openai:
            let key = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
            let baseUrl = UserDefaults.standard.string(forKey: "openaiBaseUrl") ?? ""
            let isLocal = baseUrl.contains("localhost") || baseUrl.contains("127.0.0.1")
            let ready = !key.trimmingCharacters(in: .whitespaces).isEmpty || isLocal
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "OpenAI/Local Ready" : "API Key Required"
            }
        case .claudeApi:
            let key = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
            let hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = hasKey
                self.statusMessage = hasKey ? "Claude API Ready" : "API Key Required"
            }
        }
    }

    // MARK: - Message Dispatcher

    func sendMessage(
        prompt: String,
        activePage: DocumentPage?,
        vaultURL: URL
    ) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        // 1. Append User Message
        let userMsg = AIChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)

        // 2. Prepare Assistant Message Placeholder
        let assistantMsgId = UUID()
        let placeholderMsg = AIChatMessage(id: assistantMsgId, role: .assistant, content: "", isStreaming: true)
        messages.append(placeholderMsg)
        self.isStreaming = true
        self.statusMessage = "Thinking..."

        // 3. Build Full Contextual Prompt
        var contextPreamble = ""
        if let page = activePage {
            contextPreamble += "You are helping the user inside Pustaka, a modern local Markdown workspace.\n"
            contextPreamble += "The user is currently editing note: \"\(page.title)\"\n"
            contextPreamble += "Note Content:\n```markdown\n\(page.rawContent)\n```\n\n"
            contextPreamble += "User Request: \(trimmed)\n"
            contextPreamble += "Respond in clear, elegant markdown. If revising or writing note content, provide the text cleanly without extra filler so the user can directly insert or replace their document."
        } else {
            contextPreamble = trimmed
        }

        // 4. Delegate to Provider
        switch currentProvider {
        case .antigravity:
            sendAntigravityMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL)
        case .claudeCode:
            sendClaudeCodeMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL)
        case .geminiCli:
            sendGeminiCliMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL)
        case .customAcp:
            sendCustomAcpMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL)
        case .geminiApi:
            sendGeminiApiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        case .openai:
            sendOpenAIMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        case .claudeApi:
            sendClaudeApiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        }
    }

    // MARK: - 1. Antigravity CLI (Zed ACP Subprocess)

    private func sendAntigravityMessage(prompt: String, assistantMsgId: UUID, vaultURL: URL) {
        let rawCliPath = UserDefaults.standard.string(forKey: "aiAgentCliPath") ?? Self.defaultAgyPath
        guard let cliPath = Self.resolveExecutablePath(command: "agy", preferredPath: rawCliPath) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Antigravity CLI not found** at `\(rawCliPath)`.\n\nPlease check Settings (⌘,) → **AI & ACP**.")
            return
        }

        var arguments = [
            "--print", prompt,
            "--output-format", "stream-json",
            "--dangerously-skip-permissions",
            "--add-dir", vaultURL.path
        ]

        if !currentModel.isEmpty && currentModel != "default" {
            arguments.append(contentsOf: ["--model", currentModel])
        }

        if !currentEffort.isEmpty && currentEffort != "default" {
            arguments.append(contentsOf: ["--effort", currentEffort])
        }

        executeCliProcess(
            executablePath: cliPath,
            arguments: arguments,
            workingDirectory: vaultURL,
            assistantMsgId: assistantMsgId,
            isStreamJson: true
        )
    }

    // MARK: - 2. Claude Code CLI

    private func sendClaudeCodeMessage(prompt: String, assistantMsgId: UUID, vaultURL: URL) {
        let rawCliPath = UserDefaults.standard.string(forKey: "claudeCodeCliPath") ?? "claude"
        guard let cliPath = Self.resolveExecutablePath(command: "claude", preferredPath: rawCliPath) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Claude Code CLI not found.**\n\nPlease check Settings (⌘,) → **AI & ACP** or install via `npm install -g @anthropic-ai/claude-code`.")
            return
        }

        var arguments = ["-p", prompt]
        if !currentModel.isEmpty && currentModel != "default" {
            arguments.append(contentsOf: ["--model", currentModel])
        }

        executeCliProcess(
            executablePath: cliPath,
            arguments: arguments,
            workingDirectory: vaultURL,
            assistantMsgId: assistantMsgId,
            isStreamJson: false
        )
    }

    // MARK: - 3. Gemini CLI

    private func sendGeminiCliMessage(prompt: String, assistantMsgId: UUID, vaultURL: URL) {
        let rawCliPath = UserDefaults.standard.string(forKey: "geminiCliPath") ?? "gemini"
        guard let cliPath = Self.resolveExecutablePath(command: "gemini", preferredPath: rawCliPath) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Gemini CLI not found.**\n\nPlease check Settings (⌘,) → **AI & ACP**.")
            return
        }

        var arguments = ["-p", prompt, "--yolo", "-o", "stream-json"]
        if !currentModel.isEmpty && currentModel != "default" {
            arguments.append(contentsOf: ["-m", currentModel])
        }

        executeCliProcess(
            executablePath: cliPath,
            arguments: arguments,
            workingDirectory: vaultURL,
            assistantMsgId: assistantMsgId,
            isStreamJson: true
        )
    }

    // MARK: - 4. Custom ACP Server

    private func sendCustomAcpMessage(prompt: String, assistantMsgId: UUID, vaultURL: URL) {
        let rawCmd = UserDefaults.standard.string(forKey: "customAcpCommand") ?? "npx"
        let rawArgs = UserDefaults.standard.string(forKey: "customAcpArgs") ?? ""

        guard let cliPath = Self.resolveExecutablePath(command: rawCmd, preferredPath: rawCmd) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Custom ACP command '\(rawCmd)' not found.**\n\nPlease check Settings (⌘,) → **AI & ACP**.")
            return
        }

        var arguments = rawArgs.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        arguments.append(prompt)

        executeCliProcess(
            executablePath: cliPath,
            arguments: arguments,
            workingDirectory: vaultURL,
            assistantMsgId: assistantMsgId,
            isStreamJson: false
        )
    }

    // MARK: - Universal CLI Process Executor

    private func executeCliProcess(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        assistantMsgId: UUID,
        isStreamJson: Bool
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory

            var env = ProcessInfo.processInfo.environment
            let home = NSHomeDirectory()
            env["PATH"] = "\(home)/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/mac/.local/state/fnm_multishells/1805_1792558437123/bin"
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            self.currentProcess = process

            do {
                try process.run()
            } catch {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Failed to start agent process: \(error.localizedDescription)")
                return
            }

            let fileHandle = stdoutPipe.fileHandleForReading
            var buffer = Data()
            var accumulatedResponse = ""

            while process.isRunning || fileHandle.availableData.count > 0 {
                let chunk = fileHandle.availableData
                if chunk.isEmpty && !process.isRunning {
                    break
                }

                if isStreamJson {
                    buffer.append(chunk)
                    while let range = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer.subdata(in: 0..<range.lowerBound)
                        buffer.removeSubrange(0..<range.upperBound)

                        if let lineStr = String(data: lineData, encoding: .utf8), !lineStr.trimmingCharacters(in: .whitespaces).isEmpty {
                            self.handleStreamJsonLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                        }
                    }
                } else {
                    if let chunkStr = String(data: chunk, encoding: .utf8) {
                        let cleanStr = Self.stripAnsiCodes(chunkStr)
                        accumulatedResponse += cleanStr
                        let currentText = accumulatedResponse
                        DispatchQueue.main.async {
                            if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                                self.messages[idx].content = currentText
                            }
                        }
                    }
                }
            }

            // Flush remaining buffer
            if isStreamJson && !buffer.isEmpty {
                if let lineStr = String(data: buffer, encoding: .utf8), !lineStr.trimmingCharacters(in: .whitespaces).isEmpty {
                    self.handleStreamJsonLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                }
            }

            process.waitUntilExit()

            DispatchQueue.main.async {
                self.isStreaming = false
                self.statusMessage = "Ready"
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    if self.messages[idx].content.isEmpty {
                        self.messages[idx].content = accumulatedResponse.isEmpty ? "*(No output returned from agent)*" : accumulatedResponse
                    }
                    self.messages[idx].isStreaming = false
                }
                self.currentProcess = nil
            }
        }
    }

    private func handleStreamJsonLine(_ line: String, assistantMsgId: UUID, accumulated: inout String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // If not JSON but meaningful plain text line
            let clean = Self.stripAnsiCodes(line).trimmingCharacters(in: .newlines)
            if !clean.isEmpty && !clean.hasPrefix("⠋") && !clean.hasPrefix("⠙") && !clean.hasPrefix("⠹") {
                accumulated += clean + "\n"
                let current = accumulated
                DispatchQueue.main.async {
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[idx].content = current
                    }
                }
            }
            return
        }

        let event = json["event"] as? String

        if event == "step_update",
           let update = json["step_update"] as? [String: Any],
           let delta = update["text_delta"] as? String {
            accumulated += delta
            let currentText = accumulated
            DispatchQueue.main.async {
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = currentText
                }
            }
        } else if event == "result",
                  let result = json["result"] as? [String: Any],
                  let fullResponse = result["response"] as? String {
            if !fullResponse.isEmpty {
                accumulated = fullResponse
            }
            let currentText = accumulated
            DispatchQueue.main.async {
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = currentText
                    self.messages[idx].isStreaming = false
                }
            }
        }
    }

    // MARK: - 5. Google Gemini REST API

    private func sendGeminiApiMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Gemini API Key missing.**\n\nPlease add your API key in Settings (⌘,) → **AI & ACP**.")
            return
        }

        let model = currentModel.isEmpty ? "gemini-2.5-flash" : currentModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?key=\(apiKey)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        var accumulated = ""
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Connection error: \(error.localizedDescription)")
                return
            }

            guard let data = data, let text = String(data: data, encoding: .utf8) else {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Empty response from Gemini API.")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in json {
                    if let candidates = item["candidates"] as? [[String: Any]],
                       let first = candidates.first,
                       let content = first["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let part = parts.first,
                       let t = part["text"] as? String {
                        accumulated += t
                    }
                }
            } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let part = parts.first,
                      let t = part["text"] as? String {
                accumulated = t
            } else {
                accumulated = text
            }

            let result = accumulated.isEmpty ? "*(No response generated)*" : accumulated
            DispatchQueue.main.async {
                self.isStreaming = false
                self.statusMessage = "Ready"
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = result
                    self.messages[idx].isStreaming = false
                }
            }
        }
        self.currentTask = task
        task.resume()
    }

    // MARK: - 6. OpenAI / OpenRouter / DeepSeek API

    private func sendOpenAIMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        let rawBaseUrl = UserDefaults.standard.string(forKey: "openaiBaseUrl") ?? "https://api.openai.com/v1"
        let baseUrl = rawBaseUrl.trimmingCharacters(in: .whitespaces).isEmpty ? "https://api.openai.com/v1" : rawBaseUrl
        let model = currentModel.isEmpty ? "gpt-4o" : currentModel

        guard let url = URL(string: "\(baseUrl)/chat/completions") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Connection error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Invalid response from API.")
                return
            }

            if let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ API Error: \(msg)")
                return
            }

            var outputText = ""
            if let choices = json["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                outputText = content
            }

            DispatchQueue.main.async {
                self.isStreaming = false
                self.statusMessage = "Ready"
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = outputText.isEmpty ? "*(No output)*" : outputText
                    self.messages[idx].isStreaming = false
                }
            }
        }
        self.currentTask = task
        task.resume()
    }

    // MARK: - 7. Anthropic Claude REST API

    private func sendClaudeApiMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Claude API Key missing.**\n\nPlease add your API key in Settings (⌘,) → **AI & ACP**.")
            return
        }

        let model = currentModel.isEmpty ? "claude-3-7-sonnet-latest" : currentModel
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Connection error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Invalid response from Claude API.")
                return
            }

            if let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Claude API Error: \(msg)")
                return
            }

            var outputText = ""
            if let content = json["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                outputText = text
            }

            DispatchQueue.main.async {
                self.isStreaming = false
                self.statusMessage = "Ready"
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = outputText.isEmpty ? "*(No output)*" : outputText
                    self.messages[idx].isStreaming = false
                }
            }
        }
        self.currentTask = task
        task.resume()
    }

    private func failWithMessage(assistantMsgId: UUID, text: String) {
        DispatchQueue.main.async {
            self.isStreaming = false
            self.statusMessage = "Error"
            if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                self.messages[idx].content = text
                self.messages[idx].isStreaming = false
            }
        }
    }

    /// Stops the currently running stream
    func cancelCurrentStream() {
        if let proc = currentProcess, proc.isRunning {
            proc.terminate()
        }
        currentProcess = nil
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
        statusMessage = "Cancelled"
    }

    /// Clears conversation history
    func clearHistory() {
        cancelCurrentStream()
        messages.removeAll()
    }
}
