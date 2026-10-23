import SwiftUI

// MARK: - Dedicated Native macOS Settings Sheet

struct SettingsSheet: View {
    @ObservedObject var store: WorkspaceStore
    var initialTab: SettingsTab = .appearance
    let onDismiss: () -> Void

    // Theme & Primary Color
    @AppStorage("appAppearance") private var appAppearance: String = "system"
    @AppStorage("appPrimaryColorHex") private var appPrimaryColorHex: String = "#007AFF"

    // Accessibility & Scaling
    @AppStorage("appUiScale") private var appUiScale: Double = 1.0
    @AppStorage("editorFontSize") private var editorFontSize: Double = 15.0
    @AppStorage("sidebarFontSize") private var sidebarFontSize: Double = 13.0
    @AppStorage("enhanceContrast") private var enhanceContrast: Bool = false
    @AppStorage("editorFontFamily") private var editorFontFamily: String = "system"
    @AppStorage("editorLineSpacing") private var editorLineSpacing: String = "normal"

    // Navigation & Sort
    @AppStorage("sidebarSortOption") private var sidebarSortOption: SidebarSortOption = .modifiedDesc
    @AppStorage("sidebarFilterOption") private var sidebarFilterOption: SidebarFilterOption = .all

    // AI Providers
    @AppStorage("aiProviderType") private var aiProviderType: String = AIProviderType.antigravity.rawValue
    @AppStorage("aiAgentCliPath") private var aiAgentCliPath: String = ACPAgentService.defaultAgyPath
    @AppStorage("aiAgentModel") private var aiAgentModel: String = "gemini-3.8-flash-high"
    @AppStorage("aiAgentEffort") private var aiAgentEffort: String = "high"
    @AppStorage("claudeCliPath") private var claudeCliPath: String = ACPAgentService.defaultClaudePath
    @AppStorage("claudeCliModel") private var claudeCliModel: String = "claude-3-7-sonnet"
    @AppStorage("geminiCliPath") private var geminiCliPath: String = ACPAgentService.defaultGeminiCliPath
    @AppStorage("geminiCliModel") private var geminiCliModel: String = "gemini-2.5-flash"
    @AppStorage("customAcpPath") private var customAcpPath: String = ""
    @AppStorage("customAcpArgs") private var customAcpArgs: String = "--print {prompt}"
    @AppStorage("geminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("geminiModel") private var geminiModel: String = "gemini-2.5-flash"
    @AppStorage("openaiApiKey") private var openaiApiKey: String = ""
    @AppStorage("openaiEndpoint") private var openaiEndpoint: String = "https://api.openai.com/v1"
    @AppStorage("openaiModel") private var openaiModel: String = "gpt-4o"
    @AppStorage("claudeApiKey") private var claudeApiKey: String = ""
    @AppStorage("claudeApiModel") private var claudeApiModel: String = "claude-3-7-sonnet-20250219"

    @State private var selectedTab: SettingsTab = .appearance
    @State private var customColor: Color = Color(hex: "#007AFF")

    enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case accessibility = "Accessibility"
        case ai = "AI Assistant"
        case editor = "Editor & Canvas"
        case vault = "Vault & Storage"
        case shortcuts = "Shortcuts"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: return "paintpalette"
            case .accessibility: return "figure.walk.circle"
            case .ai: return "sparkles"
            case .editor: return "square.and.pencil"
            case .vault: return "folder"
            case .shortcuts: return "command"
            case .about: return "info.circle"
            }
        }
    }

    // Curated Apple Accent Colors
    private let accentColorPresets: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Indigo", "#5856D6"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Green", "#34C759"),
        ("Teal", "#00C7BE"),
        ("Graphite", "#8E8E93")
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Left Settings Navigation Sidebar (200pt)
            settingsSidebar
                .frame(width: 200)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider().opacity(0.3)

            // Right Settings Content Area (540pt)
            VStack(spacing: 0) {
                // Header Bar with Title and Close Button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedTab.rawValue)
                            .font(.title3.weight(.bold))
                        Text(tabSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close Settings (Esc)")
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 12)

                Divider().opacity(0.3)

                // Scrollable Setting Sections
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedTab {
                        case .appearance:
                            appearanceSettingsContent
                        case .accessibility:
                            accessibilitySettingsContent
                        case .ai:
                            aiSettingsContent
                        case .editor:
                            editorSettingsContent
                        case .vault:
                            vaultSettingsContent
                        case .shortcuts:
                            shortcutsSettingsContent
                        case .about:
                            aboutSettingsContent
                        }
                    }
                    .padding(22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        }
        .frame(width: 740, height: 530)
        .onAppear {
            selectedTab = initialTab
            customColor = Color(hex: appPrimaryColorHex)
        }
    }

    private var tabSubtitle: String {
        switch selectedTab {
        case .appearance: return "Theme mode and primary accent colors"
        case .accessibility: return "Adjust font sizes, UI scale, and display contrast"
        case .ai: return "Local ACP agents and cloud API intelligence"
        case .editor: return "Document canvas typography and line formatting"
        case .vault: return "Local filesystem storage and workspace statistics"
        case .shortcuts: return "Quick keyboard shortcuts and slash commands"
        case .about: return "Pustaka desktop release notes and architecture"
        }
    }

    // MARK: - Left Settings Sidebar

    private var settingsSidebar: some View {
        VStack(spacing: 6) {
            // App Badge Identity
            HStack(spacing: 8) {
                if let logoImg = NSImage(named: "AppLogo") ?? Bundle.main.url(forResource: "AppLogo", withExtension: "png").flatMap({ NSImage(contentsOf: $0) }) ?? NSApplication.shared.applicationIconImage {
                    Image(nsImage: logoImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(hex: appPrimaryColorHex))
                            .frame(width: 24, height: 24)

                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Pustaka")
                        .font(.system(size: 13, weight: .bold))
                    Text("Settings")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            Divider().opacity(0.2)

            // Category Tab Buttons
            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.14)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 9) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color(hex: appPrimaryColorHex) : Color.secondary)
                                .frame(width: 18)

                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            isSelected ?
                            Color(hex: appPrimaryColorHex).opacity(0.12) :
                            Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Spacer()
        }
    }

    // MARK: - Tab 1: Appearance Settings Content

    private var appearanceSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Theme Mode
            settingsCardSection(title: "THEME MODE") {
                HStack(spacing: 12) {
                    themeOptionCard(title: "System", mode: "system", icon: "circle.lefthalf.striped.horizontal")
                    themeOptionCard(title: "Light", mode: "light", icon: "sun.max")
                    themeOptionCard(title: "Dark", mode: "dark", icon: "moon")
                }
            }

            // Primary Accent Color Picker
            settingsCardSection(title: "PRIMARY ACCENT COLOR") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose the primary brand and highlight color used throughout Pustaka.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Color Swatches
                    HStack(spacing: 10) {
                        ForEach(accentColorPresets, id: \.hex) { preset in
                            let isCurrent = appPrimaryColorHex.uppercased() == preset.hex.uppercased()
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    appPrimaryColorHex = preset.hex
                                    customColor = Color(hex: preset.hex)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 24, height: 24)

                                    if isCurrent {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 2)
                                            .frame(width: 30, height: 30)
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .help(preset.name)
                        }

                        Divider()
                            .frame(height: 22)
                            .padding(.horizontal, 4)

                        // Custom Color Picker
                        ColorPicker("", selection: Binding(
                            get: { customColor },
                            set: { newColor in
                                customColor = newColor
                                appPrimaryColorHex = newColor.toHex()
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                        .help("Custom Accent Color")
                    }
                }
            }

            // Default Sort Order
            settingsCardSection(title: "SIDEBAR DEFAULTS") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Note Order")
                            .font(.system(size: 12, weight: .medium))
                        Text("How notes are sorted within sidebar folders")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $sidebarSortOption) {
                        ForEach(SidebarSortOption.allCases) { opt in
                            Text(opt.label).tag(opt)
                        }
                    }
                    .frame(width: 170)
                }
            }
        }
    }

    private func themeOptionCard(title: String, mode: String, icon: String) -> some View {
        let isSelected = appAppearance == mode
        return Button(action: {
            appAppearance = mode
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color(hex: appPrimaryColorHex) : Color.secondary)

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                if isSelected {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: appPrimaryColorHex))
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(hex: appPrimaryColorHex) : Color.secondary.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 2: Accessibility & Scaling Settings Content

    private var accessibilitySettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // UI & Menu Scale
            settingsCardSection(title: "UI & MENU SCALING") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Overall Interface Scale")
                                .font(.system(size: 12, weight: .medium))
                            Text("Scales sidebar elements, icons, tab heights, and buttons")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(appUiScale * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: appPrimaryColorHex))
                            .frame(width: 45, alignment: .trailing)
                    }

                    HStack(spacing: 8) {
                        uiScalePresetButton("90%", value: 0.9)
                        uiScalePresetButton("100% (Default)", value: 1.0)
                        uiScalePresetButton("115%", value: 1.15)
                        uiScalePresetButton("130% (Large)", value: 1.3)
                    }

                    Slider(value: $appUiScale, in: 0.85...1.35, step: 0.05)
                        .controlSize(.small)
                }
            }

            // Document Canvas Font Size
            settingsCardSection(title: "DOCUMENT TEXT SIZE") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Editor Font Size")
                                .font(.system(size: 12, weight: .medium))
                            Text("Size of headings, paragraphs, lists, and tables on canvas")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(editorFontSize)) pt")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: appPrimaryColorHex))
                            .frame(width: 45, alignment: .trailing)
                    }

                    HStack(spacing: 8) {
                        fontSizePresetButton("Small (13)", value: 13.0)
                        fontSizePresetButton("Regular (15)", value: 15.0)
                        fontSizePresetButton("Medium (17)", value: 17.0)
                        fontSizePresetButton("Large (19)", value: 19.0)
                        fontSizePresetButton("Huge (22)", value: 22.0)
                    }

                    Slider(value: $editorFontSize, in: 11.0...28.0, step: 1.0)
                        .controlSize(.small)
                }
            }

            // Sidebar Font Size
            settingsCardSection(title: "SIDEBAR TEXT SIZE") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sidebar Item Font Size")
                            .font(.system(size: 12, weight: .medium))
                        Text("Size of documents and folder names in the sidebar tree")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $sidebarFontSize) {
                        Text("Compact (11.5 pt)").tag(11.5)
                        Text("Standard (13 pt - Apple HIG)").tag(13.0)
                        Text("Large (14 pt)").tag(14.0)
                        Text("Extra Large (15.5 pt)").tag(15.5)
                    }
                    .frame(width: 170)
                }
            }

            // Contrast Accessibility
            settingsCardSection(title: "LEGIBILITY & CONTRAST") {
                Toggle(isOn: $enhanceContrast) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enhance Text Contrast")
                            .font(.system(size: 12, weight: .medium))
                        Text("Increases the readability and boldness of secondary and tertiary labels")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
        }
    }

    private func uiScalePresetButton(_ label: String, value: Double) -> some View {
        let isSelected = abs(appUiScale - value) < 0.02
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                appUiScale = value
            }
        }) {
            Text(label)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color(hex: appPrimaryColorHex) : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isSelected ? Color(hex: appPrimaryColorHex).opacity(0.12) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func fontSizePresetButton(_ label: String, value: Double) -> some View {
        let isSelected = abs(editorFontSize - value) < 0.5
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                editorFontSize = value
            }
        }) {
            Text(label)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color(hex: appPrimaryColorHex) : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isSelected ? Color(hex: appPrimaryColorHex).opacity(0.12) : Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 3: AI & ACP Settings Content

    private var aiSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCardSection(title: "ACTIVE AI PROVIDER") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Provider", selection: $aiProviderType) {
                        ForEach(AIProviderType.allCases) { p in
                            Label(p.label, systemImage: p.icon).tag(p.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Divider().opacity(0.2)

                    switch AIProviderType.from(raw: aiProviderType) {
                    case .antigravity:
                        antigravityConfigSection
                    case .claudeCode:
                        claudeCodeConfigSection
                    case .geminiCli:
                        geminiCliConfigSection
                    case .customAcp:
                        customAcpConfigSection
                    case .geminiApi:
                        geminiApiConfigSection
                    case .openai:
                        openAiConfigSection
                    case .claudeApi:
                        claudeApiConfigSection
                    }
                }
            }
        }
    }

    // Antigravity ACP Config
    private var antigravityConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isFound = ACPAgentService.resolveExecutablePath(command: "agy", preferredPath: aiAgentCliPath) != nil

            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: appPrimaryColorHex).opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: appPrimaryColorHex))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Dedicated Antigravity Agent (Local ACP)")
                        .font(.system(size: 12, weight: .bold))
                    Text("Subprocess stream-json protocol via stdio • Zero-config local auth")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(isFound ? Color.green : Color.red)
                        .frame(width: 5.5, height: 5.5)
                    Text(isFound ? "Ready" : "Missing")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFound ? Color.green : Color.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isFound ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CLI Executable Path")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button("Auto-Detect") {
                        if let resolved = ACPAgentService.resolveExecutablePath(command: "agy") {
                            aiAgentCliPath = resolved
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: appPrimaryColorHex))
                }

                TextField("Path to agy binary...", text: $aiAgentCliPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Default Model")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $aiAgentModel) {
                    ForEach(AIModelRegistry.models(for: .antigravity)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Reasoning Effort")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $aiAgentEffort) {
                    Text("Auto / Inherit").tag("default")
                    Text("Low (Fastest)").tag("low")
                    Text("Medium (Balanced)").tag("medium")
                    Text("High (Deep Thinking)").tag("high")
                    Text("Max (Maximum Intelligence)").tag("max")
                }
                .labelsHidden()
            }
        }
    }

    // Claude Code Config
    private var claudeCodeConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isFound = ACPAgentService.resolveExecutablePath(command: "claude", preferredPath: claudeCliPath) != nil

            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: "terminal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.orange)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude Code CLI Agent")
                        .font(.system(size: 12, weight: .bold))
                    Text("Run tasks through the official Anthropic claude CLI")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(isFound ? Color.green : Color.red)
                        .frame(width: 5.5, height: 5.5)
                    Text(isFound ? "Ready" : "Missing")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFound ? Color.green : Color.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isFound ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CLI Executable Path")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button("Auto-Detect") {
                        if let resolved = ACPAgentService.resolveExecutablePath(command: "claude") {
                            claudeCliPath = resolved
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: appPrimaryColorHex))
                }

                TextField("Path to claude binary...", text: $claudeCliPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $claudeCliModel) {
                    ForEach(AIModelRegistry.models(for: .claudeCode)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // Gemini CLI Config
    private var geminiCliConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isFound = ACPAgentService.resolveExecutablePath(command: "gemini", preferredPath: geminiCliPath) != nil

            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 22, height: 22)
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.blue)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Google Gemini CLI Agent")
                        .font(.system(size: 12, weight: .bold))
                    Text("Direct execution via Google gemini command line")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(isFound ? Color.green : Color.red)
                        .frame(width: 5.5, height: 5.5)
                    Text(isFound ? "Ready" : "Missing")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isFound ? Color.green : Color.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isFound ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("CLI Executable Path")
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button("Auto-Detect") {
                        if let resolved = ACPAgentService.resolveExecutablePath(command: "gemini") {
                            geminiCliPath = resolved
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: appPrimaryColorHex))
                }

                TextField("Path to gemini binary...", text: $geminiCliPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $geminiCliModel) {
                    ForEach(AIModelRegistry.models(for: .geminiCli)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // Custom ACP Config
    private var customAcpConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Executable Command or Path")
                    .font(.system(size: 11.5, weight: .medium))
                TextField("e.g. /usr/local/bin/my-agent", text: $customAcpPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Arguments Template")
                    .font(.system(size: 11.5, weight: .medium))
                TextField("e.g. --print {prompt}", text: $customAcpArgs)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }
        }
    }

    // Gemini API Config
    private var geminiApiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gemini API Key")
                    .font(.system(size: 11.5, weight: .medium))
                SecureField("Paste your Google AI Studio API key...", text: $geminiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $geminiModel) {
                    ForEach(AIModelRegistry.models(for: .geminiApi)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // OpenAI Config
    private var openAiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Base API Endpoint")
                    .font(.system(size: 11.5, weight: .medium))
                TextField("https://api.openai.com/v1 or http://localhost:11434/v1", text: $openaiEndpoint)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key (optional for local Ollama)")
                    .font(.system(size: 11.5, weight: .medium))
                SecureField("Paste API key...", text: $openaiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Identifier")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $openaiModel) {
                    ForEach(AIModelRegistry.models(for: .openai)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // Claude API Config
    private var claudeApiConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Anthropic API Key")
                    .font(.system(size: 11.5, weight: .medium))
                SecureField("Paste your Anthropic API key...", text: $claudeApiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Model Selection")
                    .font(.system(size: 11.5, weight: .medium))
                Picker("", selection: $claudeApiModel) {
                    ForEach(AIModelRegistry.models(for: .claudeApi)) { m in
                        Text("\(m.name)\(m.badge != nil ? " [\(m.badge!)]" : "")").tag(m.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    // MARK: - Tab 4: Editor & Canvas Settings Content

    private var editorSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCardSection(title: "TYPOGRAPHY") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Font Family")
                            .font(.system(size: 12, weight: .medium))
                        Text("Typeface style for document body and headings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $editorFontFamily) {
                        Text("System (San Francisco)").tag("system")
                        Text("Serif (New York)").tag("serif")
                        Text("Monospaced (SF Mono)").tag("monospaced")
                        Text("Rounded (SF Pro Rounded)").tag("rounded")
                    }
                    .frame(width: 190)
                }
            }

            settingsCardSection(title: "LINE SPACING") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paragraph Spacing")
                            .font(.system(size: 12, weight: .medium))
                        Text("Vertical breathing room between sentences and blocks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $editorLineSpacing) {
                        Text("Compact").tag("compact")
                        Text("Normal").tag("normal")
                        Text("Relaxed").tag("relaxed")
                    }
                    .frame(width: 140)
                }
            }
        }
    }

    // MARK: - Tab 5: Vault & Storage Settings Content

    private var vaultSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCardSection(title: "VAULT LOCATION") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("~/Documents/Pustaka")
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        Text("Standard local Markdown vault with YAML frontmatter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Reveal in Finder") {
                        store.revealInFinder()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            settingsCardSection(title: "WORKSPACE METRICS") {
                HStack(spacing: 12) {
                    metricCard(title: "Active Notes", value: "\(store.activePages.count)", icon: "doc.text")
                    metricCard(title: "Folders", value: "\(store.categories.count)", icon: "folder")
                    metricCard(title: "In Trash", value: "\(store.trashPages.count)", icon: "trash")
                }
            }

            settingsCardSection(title: "STORAGE INTEGRITY") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("Atomic auto-save is active. Changes are committed immediately to local disk.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text("Deleted notes are preserved in the ~/.trash/ folder for recovery.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func metricCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Tab 6: Shortcuts Settings Content

    private var shortcutsSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCardSection(title: "GLOBAL SHORTCUTS") {
                VStack(spacing: 6) {
                    shortcutRow(key: "⌘N", description: "Create new document")
                    shortcutRow(key: "⌘K", description: "Focus search bar")
                    shortcutRow(key: "⇧⌘R", description: "Reveal vault in Finder")
                    shortcutRow(key: "⌘,", description: "Open Settings")
                    shortcutRow(key: "⌘J", description: "Toggle AI Assistant panel")
                    shortcutRow(key: "⌃⌘S", description: "Toggle Sidebar")
                    shortcutRow(key: "⌘W", description: "Close active document tab")
                    shortcutRow(key: "⌘B / ⌘I", description: "Format Bold / Italic")
                    shortcutRow(key: "⌘D", description: "Duplicate selected block or note")
                }
            }

            settingsCardSection(title: "SLASH COMMANDS & FORMATTING") {
                VStack(spacing: 6) {
                    shortcutRow(key: "/subpage", description: "Insert inline subpage link block")
                    shortcutRow(key: "/table", description: "Insert 2D grid table")
                    shortcutRow(key: "/callout", description: "Insert styled callout note")
                    shortcutRow(key: "1. / -", description: "Auto format numbered or bullet list")
                    shortcutRow(key: "```", description: "Insert code snippet block")
                }
            }
        }
    }

    private func shortcutRow(key: String, description: String) -> some View {
        HStack {
            Text(description)
                .font(.system(size: 12))
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tab 7: About Settings Content

    private var aboutSettingsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCardSection(title: "ABOUT PUSTAKA") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        if let logoImg = NSImage(named: "AppLogo") ?? Bundle.main.url(forResource: "AppLogo", withExtension: "png").flatMap({ NSImage(contentsOf: $0) }) ?? NSApplication.shared.applicationIconImage {
                            Image(nsImage: logoImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: appPrimaryColorHex))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pustaka for macOS")
                                .font(.headline.weight(.bold))
                            Text("Version 1.0 (Build 2026.10)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("A local-first, distraction-free knowledge workspace crafted for macOS. Zero cloud lock-in, 100% private Markdown vault, with deep native AI Agent ACP integration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            settingsCardSection(title: "LOCAL ARCHITECTURE") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Native Swift + AppKit desktop application. Uses standard Markdown files with YAML frontmatter saved directly to your local filesystem. Safe, private, and permanent.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helper Section Card

    private func settingsCardSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}
