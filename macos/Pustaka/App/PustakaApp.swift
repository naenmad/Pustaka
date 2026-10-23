import SwiftUI

@main
struct PustakaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: NSNotification.Name("PustakaZoomIn"), object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    NotificationCenter.default.post(name: NSNotification.Name("PustakaZoomOut"), object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    NotificationCenter.default.post(name: NSNotification.Name("PustakaResetZoom"), object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
        }
    }
}
