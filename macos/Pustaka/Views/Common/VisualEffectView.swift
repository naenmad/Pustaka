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

// MARK: - Dynamic Icon View (Native SF Symbol with seamless fallback)

struct DynamicIconView: View {
    let icon: String
    var size: CGFloat = 12
    var weight: Font.Weight = .regular
    var defaultSymbol: String = "doc.text"

    var body: some View {
        let clean = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            Image(systemName: defaultSymbol)
                .font(.system(size: size, weight: weight))
        } else if NSImage(systemSymbolName: clean, accessibilityDescription: nil) != nil {
            Image(systemName: clean)
                .font(.system(size: size, weight: weight))
        } else {
            Text(clean)
                .font(.system(size: size))
        }
    }
}
