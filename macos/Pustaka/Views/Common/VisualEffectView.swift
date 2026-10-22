import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .followsWindowActiveState

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Legacy Emoji to Native Outline SF Symbol Converter

enum SFIconMapper {
    static let map: [String: String] = [
        "👋": "hand.wave",
        "⚡️": "bolt", "⚡": "bolt",
        "📄": "doc.text",
        "🗑️": "trash", "🗑": "trash",
        "💡": "lightbulb",
        "✨": "sparkles",
        "⭐️": "star", "⭐": "star",
        "🚀": "paperplane",
        "📁": "folder",
        "📝": "pencil.and.outline",
        "📚": "book.closed",
        "📌": "pin",
        "🛠️": "wrench.and.screwdriver", "🛠": "wrench.and.screwdriver",
        "🔥": "flame",
        "🎯": "scope",
        "⚙️": "gearshape", "⚙": "gearshape",
        "❤️": "heart", "♥️": "heart",
        "🏷️": "tag", "🏷": "tag",
        "🚩": "flag", "🏁": "flag",
        "🔒": "lock",
        "💼": "briefcase",
        "👥": "person.2", "👤": "person",
        "📥": "archivebox", "📦": "archivebox",
        "☀️": "sun.max", "🔆": "sun.max",
        "🌙": "moon", "🌓": "circle.lefthalf.striped.horizontal",
        "💻": "display", "🖥️": "display",
        "📱": "iphone",
        "🌐": "globe",
        "🎨": "paintpalette",
        "🎵": "music.note",
        "🔗": "link",
        "🔍": "magnifyingglass",
        "✅": "checkmark.circle", "✔️": "checkmark.circle",
        "⚠️": "exclamationmark.triangle",
        "❓": "questionmark.circle",
        "💬": "quote.bubble",
        "🕒": "clock", "⏱️": "clock",
        "📅": "calendar",
        "🔔": "bell",
        "🔖": "bookmark",
        "👁️": "eye"
    ]

    static func convert(_ raw: String, fallback: String = "doc.text") -> String {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return fallback }
        if let mapped = map[clean] { return mapped }
        if NSImage(systemSymbolName: clean, accessibilityDescription: nil) != nil {
            return clean
        }
        // If it's an emoji or unknown unicode character, replace with fallback
        if clean.unicodeScalars.contains(where: { $0.properties.isEmoji }) {
            return fallback
        }
        return clean
    }
}

// MARK: - Dynamic Icon View (Native SF Symbol with seamless fallback, NEVER renders emoji)

struct DynamicIconView: View {
    let icon: String
    var size: CGFloat = 12
    var weight: Font.Weight = .regular
    var defaultSymbol: String = "doc.text"

    var body: some View {
        let symbol = SFIconMapper.convert(icon, fallback: defaultSymbol)
        if NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil {
            Image(systemName: symbol)
                .font(.system(size: size, weight: weight))
        } else {
            Image(systemName: defaultSymbol)
                .font(.system(size: size, weight: weight))
        }
    }
}

// MARK: - Color Hex Conversion Extension

extension Color {
    static var appPrimary: Color {
        let hex = UserDefaults.standard.string(forKey: "appPrimaryColorHex") ?? "#007AFF"
        return Color(hex: hex)
    }
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "#007AFF" }
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
