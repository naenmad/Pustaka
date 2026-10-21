import Foundation
import SwiftUI

// MARK: - AI Provider Enum

enum AIProviderType: String, CaseIterable, Identifiable {
    case antigravity = "antigravity"
    case gemini = "gemini"
    case openai = "openai"
    case claude = "claude"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .antigravity: return "Antigravity CLI (Zed ACP)"
        case .gemini: return "Google Gemini API"
        case .openai: return "OpenAI / OpenRouter / DeepSeek"
        case .claude: return "Anthropic Claude API"
        }
    }

    var icon: String {
        switch self {
        case .antigravity: return "sparkles"
        case .gemini: return "wand.and.stars"
        case .openai: return "cpu"
        case .claude: return "brain"
        }
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

    var currentProvider: AIProviderType {
        let raw = UserDefaults.standard.string(forKey: "aiProviderType") ?? AIProviderType.antigravity.rawValue
        return AIProviderType(rawValue: raw) ?? .antigravity
    }

    init() {
        checkAgentAvailability()
    }

    /// Checks if the configured provider is ready (CLI executable exists OR API key present)
    func checkAgentAvailability() {
        switch currentProvider {
        case .antigravity:
            let path = UserDefaults.standard.string(forKey: "aiAgentCliPath") ?? Self.defaultAgyPath
            let expanded = (path as NSString).expandingTildeInPath
            let exists = FileManager.default.isExecutableFile(atPath: expanded)
            DispatchQueue.main.async {
                self.isAgentAvailable = exists
                self.statusMessage = exists ? "Antigravity Ready" : "CLI Not Installed"
            }
        case .gemini:
            let key = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
            let hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = hasKey
                self.statusMessage = hasKey ? "Gemini Ready" : "API Key Required"
            }
        case .openai:
            let key = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
            let hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = hasKey
                self.statusMessage = hasKey ? "OpenAI Ready" : "API Key Required"
            }
        case .claude:
            let key = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
            let hasKey = !key.trimmingCharacters(in: .whitespaces).isEmpty
            DispatchQueue.main.async {
                self.isAgentAvailable = hasKey
                self.statusMessage = hasKey ? "Claude Ready" : "API Key Required"
            }
        }
    }

    /// Dispatches a prompt to the active AI provider
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

        // 4. Delegate to the active provider
        switch currentProvider {
        case .antigravity:
            sendAntigravityMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId, vaultURL: vaultURL)
        case .gemini:
            sendGeminiMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        case .openai:
            sendOpenAIMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        case .claude:
            sendClaudeMessage(prompt: contextPreamble, assistantMsgId: assistantMsgId)
        }
    }

    // MARK: - 1. Antigravity CLI (Zed ACP Subprocess)

    private func sendAntigravityMessage(prompt: String, assistantMsgId: UUID, vaultURL: URL) {
        let rawCliPath = UserDefaults.standard.string(forKey: "aiAgentCliPath") ?? Self.defaultAgyPath
        let cliPath = (rawCliPath as NSString).expandingTildeInPath

        guard FileManager.default.isExecutableFile(atPath: cliPath) else {
            DispatchQueue.main.async {
                self.isStreaming = false
                self.statusMessage = "CLI Not Found"
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = "⚠️ **Antigravity CLI not found** at `\(cliPath)`.\n\nPlease check Settings (⌘,) → **AI & ACP** or switch to **Direct API Key** mode."
                    self.messages[idx].isStreaming = false
                }
            }
            return
        }

        // Crucial: --dangerously-skip-permissions prevents headless tool permission blocks!
        var arguments = [
            "--print", prompt,
            "--output-format", "stream-json",
            "--dangerously-skip-permissions",
            "--add-dir", vaultURL.path
        ]

        if let model = UserDefaults.standard.string(forKey: "aiAgentModel"), !model.isEmpty, model != "default" {
            arguments.append(contentsOf: ["--model", model])
        }

        if let effort = UserDefaults.standard.string(forKey: "aiAgentEffort"), !effort.isEmpty, effort != "default" {
            arguments.append(contentsOf: ["--effort", effort])
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = arguments
            process.currentDirectoryURL = vaultURL

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
                DispatchQueue.main.async {
                    self.isStreaming = false
                    self.statusMessage = "Launch Error"
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[idx].content = "❌ Failed to start agent process: \(error.localizedDescription)"
                        self.messages[idx].isStreaming = false
                    }
                }
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

    // MARK: - 2. Direct Google Gemini REST API

    private func sendGeminiMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "geminiApiKey") ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Gemini API Key missing.**\n\nPlease add your API key in Settings (⌘,) → **AI & ACP**.")
            return
        }

        let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.5-flash"
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

            // Parse Gemini response
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

    // MARK: - 3. OpenAI / OpenRouter / DeepSeek API

    private func sendOpenAIMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""
        let rawBaseUrl = UserDefaults.standard.string(forKey: "openaiBaseUrl") ?? "https://api.openai.com/v1"
        let baseUrl = rawBaseUrl.trimmingCharacters(in: .whitespaces).isEmpty ? "https://api.openai.com/v1" : rawBaseUrl
        let model = UserDefaults.standard.string(forKey: "openaiModel") ?? "gpt-4o-mini"

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

    // MARK: - 4. Anthropic Claude REST API

    private func sendClaudeMessage(prompt: String, assistantMsgId: UUID) {
        let apiKey = UserDefaults.standard.string(forKey: "claudeApiKey") ?? ""
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            failWithMessage(assistantMsgId: assistantMsgId, text: "⚠️ **Claude API Key missing.**\n\nPlease add your API key in Settings (⌘,) → **AI & ACP**.")
            return
        }

        let model = UserDefaults.standard.string(forKey: "claudeModel") ?? "claude-3-5-sonnet-20241022"
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
