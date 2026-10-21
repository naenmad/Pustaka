import Foundation
import SwiftUI

// MARK: - Multi-Provider AI Registry

enum AIProviderType: String, CaseIterable, Identifiable {
    case antigravity = "antigravity"
    case claudeCode  = "claude_code"
    case geminiCli   = "gemini_cli"
    case customAcp   = "custom_acp"
    case geminiApi   = "gemini_api"
    case openai      = "openai"
    case claudeApi   = "claude_api"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .antigravity: return "Antigravity ACP (Local Agent)"
        case .claudeCode:  return "Claude Code (CLI Agent)"
        case .geminiCli:   return "Gemini CLI (Local Agent)"
        case .customAcp:   return "Custom ACP Command"
        case .geminiApi:   return "Google Gemini Cloud API"
        case .openai:      return "OpenAI / Compatible API"
        case .claudeApi:   return "Anthropic Claude API"
        }
    }

    var shortName: String {
        switch self {
        case .antigravity: return "Antigravity ACP"
        case .claudeCode:  return "Claude Code"
        case .geminiCli:   return "Gemini CLI"
        case .customAcp:   return "Custom ACP"
        case .geminiApi:   return "Gemini API"
        case .openai:      return "OpenAI API"
        case .claudeApi:   return "Claude API"
        }
    }

    var icon: String {
        switch self {
        case .antigravity: return "sparkles"
        case .claudeCode:  return "terminal"
        case .geminiCli:   return "command"
        case .customAcp:   return "wrench.and.screwdriver"
        case .geminiApi:   return "wand.and.stars"
        case .openai:      return "bolt.circle"
        case .claudeApi:   return "brain.head.profile"
        }
    }

    var isCliAgent: Bool {
        switch self {
        case .antigravity, .claudeCode, .geminiCli, .customAcp:
            return true
        case .geminiApi, .openai, .claudeApi:
            return false
        }
    }

    static func from(raw: String) -> AIProviderType {
        return AIProviderType(rawValue: raw) ?? .antigravity
    }
}

// MARK: - Model Registry

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
    static let antigravityModels: [AIModelOption] = [
        AIModelOption(id: "gemini-3.8-flash-high", name: "Gemini 3.8 Flash (High)", badge: "Smart", description: "High reasoning effort, fast response"),
        AIModelOption(id: "gemini-3.8-flash-medium", name: "Gemini 3.8 Flash (Medium)", badge: "Balanced", description: "Balanced reasoning effort"),
        AIModelOption(id: "gemini-3.8-flash-low", name: "Gemini 3.8 Flash (Low)", badge: "Fast", description: "Ultra-low latency for quick edits"),
        AIModelOption(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", badge: "Reasoning", description: "Extended thinking model"),
        AIModelOption(id: "claude-opus-4-6-thinking", name: "Claude Opus 4.6", badge: "Deep", description: "Deepest reasoning and maximum capability"),
        AIModelOption(id: "gpt-oss-120b-medium", name: "GPT-OSS 120B", badge: "Open", description: "Open source foundation model"),
        AIModelOption(id: "default", name: "Session Default", badge: "Auto", description: "Inherit model configured in active CLI session")
    ]

    static let claudeCodeModels: [AIModelOption] = [
        AIModelOption(id: "claude-3-7-sonnet", name: "Claude 3.7 Sonnet", badge: "Hybrid", description: "Hybrid reasoning and coding model"),
        AIModelOption(id: "claude-3-5-sonnet", name: "Claude 3.5 Sonnet", badge: "Coding", description: "Standard coding and refactoring model"),
        AIModelOption(id: "claude-3-5-haiku", name: "Claude 3.5 Haiku", badge: "Fast", description: "Lightweight and fast"),
        AIModelOption(id: "default", name: "CLI Default", badge: "Auto", description: "Inherit default model from claude CLI")
    ]

    static let geminiCliModels: [AIModelOption] = [
        AIModelOption(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", badge: "Smart", description: "Deep reasoning and analysis"),
        AIModelOption(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", badge: "Fast", description: "Fast generation with search grounding"),
        AIModelOption(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", badge: "Speed", description: "High throughput next-generation flash"),
        AIModelOption(id: "default", name: "CLI Default", badge: "Auto", description: "Inherit default model from gemini CLI")
    ]

    static let customAcpModels: [AIModelOption] = [
        AIModelOption(id: "default", name: "Default (Agent Defined)", badge: "Auto", description: "Model defined in custom command configuration")
    ]

    static let geminiApiModels: [AIModelOption] = [
        AIModelOption(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", badge: "Recommended", description: "Everyday fast model"),
        AIModelOption(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", badge: "Smart", description: "Deep analysis and long context"),
        AIModelOption(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", badge: "Fast", description: "High throughput next-generation flash")
    ]

    static let openAiModels: [AIModelOption] = [
        AIModelOption(id: "gpt-4o", name: "GPT-4o", badge: "Omni", description: "Flagship intelligent multimodal model"),
        AIModelOption(id: "gpt-4o-mini", name: "GPT-4o Mini", badge: "Fast", description: "Affordable and fast reasoning"),
        AIModelOption(id: "o3-mini", name: "o3-mini", badge: "Reasoning", description: "STEM and coding reasoning model"),
        AIModelOption(id: "deepseek-chat", name: "DeepSeek V3", badge: "DeepSeek", description: "Direct DeepSeek V3 chat model"),
        AIModelOption(id: "deepseek-reasoner", name: "DeepSeek R1", badge: "DeepSeek", description: "DeepSeek R1 full reasoning model"),
        AIModelOption(id: "llama3.3:70b", name: "Llama 3.3 70B", badge: "Local", description: "Local model via Ollama endpoint")
    ]

    static let claudeApiModels: [AIModelOption] = [
        AIModelOption(id: "claude-3-7-sonnet-20250219", name: "Claude 3.7 Sonnet", badge: "Latest", description: "Anthropic flagship model"),
        AIModelOption(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet", badge: "Coding", description: "Industry standard coding"),
        AIModelOption(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku", badge: "Fast", description: "Fastest Claude model")
    ]

    static func models(for provider: AIProviderType) -> [AIModelOption] {
        switch provider {
        case .antigravity: return antigravityModels
        case .claudeCode:  return claudeCodeModels
        case .geminiCli:   return geminiCliModels
        case .customAcp:   return customAcpModels
        case .geminiApi:   return geminiApiModels
        case .openai:      return openAiModels
        case .claudeApi:   return claudeApiModels
        }
    }

    static func defaultModel(for provider: AIProviderType) -> String {
        switch provider {
        case .antigravity: return "gemini-3.8-flash-high"
        case .claudeCode:  return "claude-3-7-sonnet"
        case .geminiCli:   return "gemini-2.5-flash"
        case .customAcp:   return "default"
        case .geminiApi:   return "gemini-2.5-flash"
        case .openai:      return "gpt-4o"
        case .claudeApi:   return "claude-3-7-sonnet-20250219"
        }
    }

    static func displayName(for modelId: String, in provider: AIProviderType) -> String {
        if let found = models(for: provider).first(where: { $0.id == modelId }) {
            return found.name
        }
        return modelId.isEmpty || modelId == "default" ? "Default" : modelId
    }
}

// MARK: - Agent Process Step Model

struct AgentProcessStep: Identifiable, Hashable {
    let id: String
    let stepIndex: Int
    var title: String
    var detail: String?
    var toolName: String?
    var state: StepState
    var durationSeconds: Double?
    var outputSnippet: String?

    enum StepState: String, Codable {
        case running
        case completed
        case failed
    }

    init(
        id: String = UUID().uuidString,
        stepIndex: Int,
        title: String,
        detail: String? = nil,
        toolName: String? = nil,
        state: StepState = .running,
        durationSeconds: Double? = nil,
        outputSnippet: String? = nil
    ) {
        self.id = id
        self.stepIndex = stepIndex
        self.title = title
        self.detail = detail
        self.toolName = toolName
        self.state = state
        self.durationSeconds = durationSeconds
        self.outputSnippet = outputSnippet
    }
}

// MARK: - Chat Message Model

struct AIChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var isStreaming: Bool
    var processSteps: [AgentProcessStep]
    var thinkingTokens: Int?
    var durationSeconds: Double?

    enum MessageRole: String, Codable {
        case user
        case assistant
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        processSteps: [AgentProcessStep] = [],
        thinkingTokens: Int? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.processSteps = processSteps
        self.thinkingTokens = thinkingTokens
        self.durationSeconds = durationSeconds
    }
}

// MARK: - Dedicated ACP Agent Service

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
            if currentProvider == .antigravity {
                UserDefaults.standard.set(currentModel, forKey: "aiAgentModel")
            } else if currentProvider == .geminiApi {
                UserDefaults.standard.set(currentModel, forKey: "geminiModel")
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

    // Default CLI paths on macOS
    static let defaultAgyPath: String = {
        let userLocal = ("~/.local/bin/agy" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userLocal) {
            return userLocal
        }
        return "/usr/local/bin/agy"
    }()

    static let defaultClaudePath: String = {
        let userLocal = ("~/.local/bin/claude" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userLocal) {
            return userLocal
        }
        return "/usr/local/bin/claude"
    }()

    static let defaultGeminiCliPath: String = {
        let userLocal = ("~/.local/bin/gemini" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userLocal) {
            return userLocal
        }
        return "/usr/local/bin/gemini"
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
        if provider == .antigravity {
            let legacy = UserDefaults.standard.string(forKey: "aiAgentModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        } else if provider == .geminiApi {
            let legacy = UserDefaults.standard.string(forKey: "geminiModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        } else {
            return AIModelRegistry.defaultModel(for: provider)
        }
    }

    // Dynamic Executable Path Resolver
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
            ("/opt/homebrew/Caskroom/\(command)" as NSString).expandingTildeInPath
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

    static func stripAnsiCodes(_ str: String) -> String {
        return str.replacingOccurrences(of: #"\x1B\[[0-9;]*[a-zA-Z]"#, with: "", options: .regularExpression)
    }

    // Availability Check for all Providers
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
            let preferred = UserDefaults.standard.string(forKey: "claudeCliPath") ?? Self.defaultClaudePath
            let resolved = Self.resolveExecutablePath(command: "claude", preferredPath: preferred)
            let ready = (resolved != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Claude Code Ready" : "claude CLI Missing"
            }

        case .geminiCli:
            let preferred = UserDefaults.standard.string(forKey: "geminiCliPath") ?? Self.defaultGeminiCliPath
            let resolved = Self.resolveExecutablePath(command: "gemini", preferredPath: preferred)
            let ready = (resolved != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Gemini CLI Ready" : "gemini CLI Missing"
            }

        case .customAcp:
            let cmd = UserDefaults.standard.string(forKey: "customAcpPath") ?? ""
            let ready = !cmd.trimmingCharacters(in: .whitespaces).isEmpty &&
                        (FileManager.default.isExecutableFile(atPath: (cmd as NSString).expandingTildeInPath) ||
                         Self.resolveExecutablePath(command: cmd) != nil)
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "Custom ACP Ready" : "Set Command Path"
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
            let endpoint = UserDefaults.standard.string(forKey: "openaiEndpoint") ?? "https://api.openai.com/v1"
            let isLocal = endpoint.contains("localhost") || endpoint.contains("127.0.0.1")
            let ready = isLocal || !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = ready
                self.statusMessage = ready ? "OpenAI API Ready" : "API Key Required"
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

    // Message Dispatcher
    func sendMessage(
        prompt: String,
        activePage: DocumentPage?,
        activePageURL: URL?,
        vaultURL: URL,
        onDiskModified: (() -> Void)? = nil
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
        var contextPreamble = "You are an AI writing assistant in Pustaka, a local Markdown note workspace.\n"
        if let page = activePage {
            let pathInfo = activePageURL?.path ?? "unknown"
            contextPreamble += """
Active Note Title: "\(page.title)"
Active Note File Path: "\(pathInfo)"
Workspace Root: "\(vaultURL.path)"

Current Note Content:
```markdown
\(page.rawContent)
```

Direct Workspace & Note Editing:
- You have access to the workspace directory. If the user explicitly asks you to edit, modify, or rewrite this document, you may directly use your file editing tools to update "\(pathInfo)".
- If providing text, answers, or structured information in chat, respond in clean, well-formatted Markdown (headings, tables, callouts :info/:warn/:tip, code blocks, math $$...$$).
- Keep your conversational response elegant and concise.

User Request: \(trimmed)
"""
        } else {
            contextPreamble += "Workspace Root: \"\(vaultURL.path)\"\nUser Request: \(trimmed)"
        }

        // 4. Delegate to Provider
        switch currentProvider {
        case .antigravity:
            sendAntigravityMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL, onDiskModified: onDiskModified)
        case .claudeCode:
            sendClaudeCodeMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL, onDiskModified: onDiskModified)
        case .geminiCli:
            sendGeminiCliMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL, onDiskModified: onDiskModified)
        case .customAcp:
            sendCustomAcpMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL, onDiskModified: onDiskModified)
        case .geminiApi:
            sendGeminiApiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        case .openai:
            sendOpenAiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        case .claudeApi:
            sendClaudeApiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        }
    }

    // MARK: - Antigravity ACP Execution (stream-json)

    private func sendAntigravityMessage(
        prompt: String,
        assistantMsgId: UUID,
        vaultURL: URL,
        onDiskModified: (() -> Void)?
    ) {
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
            isStreamJson: true,
            onCompletion: onDiskModified
        )
    }

    // MARK: - Claude Code CLI Execution

    private func sendClaudeCodeMessage(
        prompt: String,
        assistantMsgId: UUID,
        vaultURL: URL,
        onDiskModified: (() -> Void)?
    ) {
        let rawPath = UserDefaults.standard.string(forKey: "claudeCliPath") ?? Self.defaultClaudePath
        guard let cliPath = Self.resolveExecutablePath(command: "claude", preferredPath: rawPath) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Claude Code CLI not found** at `\(rawPath)`.\n\nInstall via `npm install -g @anthropic-ai/claude-code` or configure in Settings.")
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
            isStreamJson: false,
            onCompletion: onDiskModified
        )
    }

    // MARK: - Gemini CLI Execution

    private func sendGeminiCliMessage(
        prompt: String,
        assistantMsgId: UUID,
        vaultURL: URL,
        onDiskModified: (() -> Void)?
    ) {
        let rawPath = UserDefaults.standard.string(forKey: "geminiCliPath") ?? Self.defaultGeminiCliPath
        guard let cliPath = Self.resolveExecutablePath(command: "gemini", preferredPath: rawPath) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Gemini CLI not found** at `\(rawPath)`.\n\nPlease verify your path in Settings (⌘,) → **AI & ACP**.")
            return
        }

        var arguments = ["--prompt", prompt]
        if !currentModel.isEmpty && currentModel != "default" {
            arguments.append(contentsOf: ["--model", currentModel])
        }

        executeCliProcess(
            executablePath: cliPath,
            arguments: arguments,
            workingDirectory: vaultURL,
            assistantMsgId: assistantMsgId,
            isStreamJson: false,
            onCompletion: onDiskModified
        )
    }

    // MARK: - Custom ACP / Agent Execution

    private func sendCustomAcpMessage(
        prompt: String,
        assistantMsgId: UUID,
        vaultURL: URL,
        onDiskModified: (() -> Void)?
    ) {
        let rawPath = UserDefaults.standard.string(forKey: "customAcpPath") ?? ""
        guard let cliPath = Self.resolveExecutablePath(command: rawPath, preferredPath: rawPath) else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Custom ACP Executable not found**.\n\nPlease configure the command path in Settings (⌘,) → **AI & ACP**.")
            return
        }

        let rawArgs = UserDefaults.standard.string(forKey: "customAcpArgs") ?? "--print {prompt}"
        let finalArgs = rawArgs
            .replacingOccurrences(of: "{prompt}", with: prompt)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }

        executeCliProcess(
            executablePath: cliPath,
            arguments: finalArgs,
            workingDirectory: vaultURL,
            assistantMsgId: assistantMsgId,
            isStreamJson: false,
            onCompletion: onDiskModified
        )
    }

    // MARK: - Generic Subprocess Execution & Stream Parser

    private func executeCliProcess(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        assistantMsgId: UUID,
        isStreamJson: Bool,
        onCompletion: (() -> Void)? = nil
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = workingDirectory

            var env = ProcessInfo.processInfo.environment
            let home = NSHomeDirectory()
            env["PATH"] = "\(home)/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
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

                buffer.append(chunk)
                while let range = buffer.range(of: Data([0x0A])) {
                    let lineData = buffer.subdata(in: 0..<range.lowerBound)
                    buffer.removeSubrange(0..<range.upperBound)

                    if let lineStr = String(data: lineData, encoding: .utf8), !lineStr.trimmingCharacters(in: .whitespaces).isEmpty {
                        if isStreamJson {
                            self.handleStreamJsonLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                        } else {
                            self.handleRawTextLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                        }
                    }
                }
            }

            if !buffer.isEmpty {
                if let lineStr = String(data: buffer, encoding: .utf8), !lineStr.trimmingCharacters(in: .whitespaces).isEmpty {
                    if isStreamJson {
                        self.handleStreamJsonLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                    } else {
                        self.handleRawTextLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                    }
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
                onCompletion?()
            }
        }
    }

    // Handles stream-json protocol (e.g. from agy)
    private func handleStreamJsonLine(_ line: String, assistantMsgId: UUID, accumulated: inout String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
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

        if event == "step_update", let update = json["step_update"] as? [String: Any] {
            let stepType = update["step_type"] as? String ?? ""
            let stepIndex = update["step_index"] as? Int ?? 0
            let stateStr = update["state"] as? String ?? "ACTIVE"

            if stepType == "tool" {
                let toolName = update["tool_name"] as? String ?? "Tool"
                let toolInfo = update["tool_info"] as? [String: Any] ?? [:]
                let params = toolInfo["parameters"] as? [String: Any]
                var detailText: String? = nil

                if let cmd = params?["CommandLine"] as? String {
                    detailText = cmd
                } else if let path = params?["Path"] as? String {
                    detailText = path
                } else if let query = params?["query"] as? String {
                    detailText = query
                } else if let p = params, let firstVal = p.values.first {
                    detailText = "\(firstVal)"
                }

                let duration = update["duration_seconds"] as? Double
                let output = toolInfo["output"] as? String

                let stepState: AgentProcessStep.StepState = (stateStr == "DONE") ? .completed : (stateStr == "ERROR" ? .failed : .running)

                DispatchQueue.main.async {
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        var steps = self.messages[idx].processSteps
                        if let sIdx = steps.firstIndex(where: { $0.stepIndex == stepIndex && $0.toolName == toolName }) {
                            steps[sIdx].state = stepState
                            if let dur = duration { steps[sIdx].durationSeconds = dur }
                            if let out = output { steps[sIdx].outputSnippet = out }
                            if let det = detailText { steps[sIdx].detail = det }
                        } else {
                            let newStep = AgentProcessStep(
                                stepIndex: stepIndex,
                                title: "Tool: \(toolName)",
                                detail: detailText,
                                toolName: toolName,
                                state: stepState,
                                durationSeconds: duration,
                                outputSnippet: output
                            )
                            steps.append(newStep)
                        }
                        self.messages[idx].processSteps = steps
                        self.statusMessage = stepState == .running ? "Running \(toolName)..." : "Processed \(toolName)"
                    }
                }
            } else if let delta = update["text_delta"] as? String {
                accumulated += delta
                let currentText = accumulated
                DispatchQueue.main.async {
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[idx].content = currentText
                    }
                }
            }
        } else if event == "result", let result = json["result"] as? [String: Any] {
            if let fullResponse = result["response"] as? String, !fullResponse.isEmpty {
                accumulated = fullResponse
            }
            let duration = result["duration_seconds"] as? Double
            let usage = result["usage"] as? [String: Any]
            let thinkingTokens = usage?["thinking_tokens"] as? Int

            let currentText = accumulated
            DispatchQueue.main.async {
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = currentText
                    self.messages[idx].durationSeconds = duration
                    self.messages[idx].thinkingTokens = thinkingTokens
                    self.messages[idx].isStreaming = false
                }
            }
        }
    }

    // Handles standard text streaming (e.g. from claude or gemini cli)
    private func handleRawTextLine(_ line: String, assistantMsgId: UUID, accumulated: inout String) {
        let clean = Self.stripAnsiCodes(line).trimmingCharacters(in: .newlines)
        guard !clean.isEmpty else { return }

        accumulated += clean + "\n"
        let currentText = accumulated
        DispatchQueue.main.async {
            if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                self.messages[idx].content = currentText
            }
        }
    }

    // MARK: - Direct Google Gemini REST API

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

    // MARK: - Direct OpenAI / Compatible REST API (ChatGPT, DeepSeek, Ollama)

    private func sendOpenAiMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        var endpoint = UserDefaults.standard.string(forKey: "openaiEndpoint") ?? "https://api.openai.com/v1"
        if endpoint.hasSuffix("/") { endpoint.removeLast() }

        let isLocal = endpoint.contains("localhost") || endpoint.contains("127.0.0.1")
        if !isLocal && apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **OpenAI API Key missing.**\n\nPlease enter your key in Settings (⌘,) → **AI & ACP**.")
            return
        }

        guard let url = URL(string: "\(endpoint)/chat/completions") else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Invalid API Endpoint URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let model = currentModel.isEmpty ? "gpt-4o" : currentModel
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Connection error: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Empty response received.")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorObj = json["error"] as? [String: Any], let errText = errorObj["message"] as? String {
                    self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ API Error: \(errText)")
                    return
                }
                if let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let msg = first["message"] as? [String: Any],
                   let text = msg["content"] as? String {
                    DispatchQueue.main.async {
                        self.isStreaming = false
                        self.statusMessage = "Ready"
                        if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                            self.messages[idx].content = text
                            self.messages[idx].isStreaming = false
                        }
                    }
                    return
                }
            }
            let rawStr = String(data: data, encoding: .utf8) ?? "*(Failed to decode response)*"
            self.failWithMessage(assistantMsgId: assistantMsgId, text: rawStr)
        }
        self.currentTask = task
        task.resume()
    }

    // MARK: - Direct Anthropic Claude REST API

    private func sendClaudeApiMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Anthropic Claude API Key missing.**\n\nPlease add your API key in Settings (⌘,) → **AI & ACP**.")
            return
        }

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let model = currentModel.isEmpty ? "claude-3-7-sonnet-20250219" : currentModel
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
            guard let data = data else {
                self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Empty response received.")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errorObj = json["error"] as? [String: Any], let errText = errorObj["message"] as? String {
                    self.failWithMessage(assistantMsgId: assistantMsgId, text: "❌ Claude Error: \(errText)")
                    return
                }
                if let contentList = json["content"] as? [[String: Any]],
                   let first = contentList.first,
                   let text = first["text"] as? String {
                    DispatchQueue.main.async {
                        self.isStreaming = false
                        self.statusMessage = "Ready"
                        if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                            self.messages[idx].content = text
                            self.messages[idx].isStreaming = false
                        }
                    }
                    return
                }
            }
            let rawStr = String(data: data, encoding: .utf8) ?? "*(Failed to decode response)*"
            self.failWithMessage(assistantMsgId: assistantMsgId, text: rawStr)
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

    func clearHistory() {
        cancelCurrentStream()
        messages.removeAll()
    }
}
