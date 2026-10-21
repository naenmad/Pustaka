import Foundation
import SwiftUI

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

    // Default Antigravity CLI path on macOS
    static let defaultAgyPath: String = {
        let userLocal = ("~/.local/bin/agy" as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: userLocal) {
            return userLocal
        }
        return "/usr/local/bin/agy"
    }()

    init() {
        checkAgentAvailability()
    }

    /// Checks if the configured agent binary exists and is executable
    func checkAgentAvailability() {
        let path = (UserDefaults.standard.string(forKey: "aiAgentCliPath") ?? Self.defaultAgyPath)
        let expanded = (path as NSString).expandingTildeInPath
        let exists = FileManager.default.isExecutableFile(atPath: expanded)
        DispatchQueue.main.async {
            self.isAgentAvailable = exists
            self.statusMessage = exists ? "Antigravity Ready" : "Agent CLI Not Found"
        }
    }

    /// Dispatches a prompt to the agent with the active note as context
    func sendMessage(
        prompt: String,
        activePage: DocumentPage?,
        vaultURL: URL,
        onPageUpdate: ((String) -> Void)? = nil
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
            contextPreamble += "You are helping the user inside Pustaka, a modern markdown workspace.\n"
            contextPreamble += "The user is currently viewing note: \"\(page.title)\"\n"
            contextPreamble += "Note Content:\n```markdown\n\(page.rawContent)\n```\n\n"
            contextPreamble += "User Request: \(trimmed)\n"
            contextPreamble += "Please respond in concise, clear markdown. If providing code or note additions, use standard markdown formatting."
        } else {
            contextPreamble = trimmed
        }

        // 4. Resolve Agent Binary & Arguments
        let rawCliPath = UserDefaults.standard.string(forKey: "aiAgentCliPath") ?? Self.defaultAgyPath
        let cliPath = (rawCliPath as NSString).expandingTildeInPath

        guard FileManager.default.isExecutableFile(atPath: cliPath) else {
            DispatchQueue.main.async {
                self.isStreaming = false
                self.statusMessage = "Error: CLI not executable"
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = "⚠️ Agent CLI not found or not executable at `\(cliPath)`.\n\nPlease check Settings (⌘,) → **AI & ACP** to configure the Antigravity binary path."
                    self.messages[idx].isStreaming = false
                }
            }
            return
        }

        var arguments = [
            "--print", contextPreamble,
            "--output-format", "stream-json",
            "--add-dir", vaultURL.path
        ]

        if let model = UserDefaults.standard.string(forKey: "aiAgentModel"), !model.isEmpty, model != "default" {
            arguments.append(contentsOf: ["--model", model])
        }

        if let effort = UserDefaults.standard.string(forKey: "aiAgentEffort"), !effort.isEmpty, effort != "default" {
            arguments.append(contentsOf: ["--effort", effort])
        }

        // 5. Run Subprocess via Apple Process & Pipe
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = arguments
            process.currentDirectoryURL = vaultURL

            // Inherit essential environment variables (PATH, HOME, USER)
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
                    self.statusMessage = "Failed to launch"
                    if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                        self.messages[idx].content = "❌ Failed to start agent process: \(error.localizedDescription)"
                        self.messages[idx].isStreaming = false
                    }
                }
                return
            }

            // Stream reading stdout line-by-line
            let fileHandle = stdoutPipe.fileHandleForReading
            var buffer = Data()
            var accumulatedResponse = ""

            while process.isRunning || fileHandle.availableData.count > 0 {
                let chunk = fileHandle.availableData
                if chunk.isEmpty && !process.isRunning {
                    break
                }
                buffer.append(chunk)

                // Process complete lines
                while let range = buffer.range(of: Data([0x0A])) { // newline delimiter \n
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

    /// Parses NDJSON line from agent output and updates chat stream
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
            accumulated = fullResponse
            let currentText = fullResponse
            DispatchQueue.main.async {
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMsgId }) {
                    self.messages[idx].content = currentText
                    self.messages[idx].isStreaming = false
                }
            }
        }
    }

    /// Stops the currently running stream
    func cancelCurrentStream() {
        if let proc = currentProcess, proc.isRunning {
            proc.terminate()
        }
        currentProcess = nil
        isStreaming = false
        statusMessage = "Cancelled"
    }

    /// Clears conversation history
    func clearHistory() {
        cancelCurrentStream()
        messages.removeAll()
    }
}
