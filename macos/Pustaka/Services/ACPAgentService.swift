import Foundation
import SwiftUI

// MARK: - Dedicated ACP Provider Type

enum AIProviderType: String, CaseIterable, Identifiable {
    case antigravity = "antigravity"
    case geminiApi   = "gemini_api"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .antigravity: return "Antigravity ACP (Local Agent)"
        case .geminiApi:   return "Gemini Cloud API (Direct)"
        }
    }

    var shortName: String {
        switch self {
        case .antigravity: return "Antigravity ACP"
        case .geminiApi:   return "Gemini API"
        }
    }

    var icon: String {
        switch self {
        case .antigravity: return "sparkles"
        case .geminiApi:   return "wand.and.stars"
        }
    }

    static func from(raw: String) -> AIProviderType {
        if raw.contains("gemini") && raw != "antigravity" {
            return .geminiApi
        }
        return .antigravity
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

    static let geminiApiModels: [AIModelOption] = [
        AIModelOption(id: "gemini-2.5-flash", name: "Gemini 2.5 Flash", badge: "Recommended", description: "Everyday fast model"),
        AIModelOption(id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", badge: "Smart", description: "Deep analysis and long context"),
        AIModelOption(id: "gemini-2.0-flash", name: "Gemini 2.0 Flash", badge: "Fast", description: "High throughput next-generation flash")
    ]

    static func models(for provider: AIProviderType) -> [AIModelOption] {
        switch provider {
        case .antigravity: return antigravityModels
        case .geminiApi:   return geminiApiModels
        }
    }

    static func defaultModel(for provider: AIProviderType) -> String {
        switch provider {
        case .antigravity: return "gemini-3.8-flash-high"
        case .geminiApi:   return "gemini-2.5-flash"
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
            } else {
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
        if provider == .antigravity {
            let legacy = UserDefaults.standard.string(forKey: "aiAgentModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
        } else {
            let legacy = UserDefaults.standard.string(forKey: "geminiModel")
            return (legacy != nil && !legacy!.isEmpty) ? legacy! : AIModelRegistry.defaultModel(for: provider)
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
            "/usr/bin/\(command)"
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

    // Availability Check
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
        case .geminiApi:
            let key = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
            let hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = hasKey
                self.statusMessage = hasKey ? "Gemini Ready" : "API Key Required"
            }
        }
    }

    // Message Dispatcher
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
        case .geminiApi:
            sendGeminiApiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        }
    }

    // Antigravity ACP Subprocess Execution
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
            assistantMsgId: assistantMsgId
        )
    }

    private func executeCliProcess(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL,
        assistantMsgId: UUID
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
                        self.handleStreamJsonLine(lineStr, assistantMsgId: assistantMsgId, accumulated: &accumulatedResponse)
                    }
                }
            }

            if !buffer.isEmpty {
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

    // Direct Google Gemini REST API (Fallback)
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
