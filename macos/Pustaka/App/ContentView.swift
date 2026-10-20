import SwiftUI

struct ContentView: View {
    @State private var engineStatus: String = "Initializing..."
    @State private var appVersion: String = ""

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pustaka")
                        .font(.title.bold())

                    Text("Local-First Block-Based Desktop Workspace")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .frame(maxWidth: 400)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Rust Core Engine Status", systemImage: "bolt.horizontal.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Circle()
                        .fill(engineStatus.contains("initialized") ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                }

                Text(engineStatus)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxWidth: 440)

            if !appVersion.isEmpty {
                HStack(spacing: 4) {
                    Text("Pustaka Core Version:")
                        .foregroundStyle(.secondary)
                    Text(appVersion)
                        .fontWeight(.semibold)
                }
                .font(.footnote)
            }
        }
        .padding(36)
        .frame(minWidth: 520, minHeight: 380)
        .onAppear {
            loadEngine()
        }
    }

    private func loadEngine() {
        let status = initEngine()
        let version = getAppVersion()
        self.engineStatus = status
        self.appVersion = version
    }
}

#Preview {
    ContentView()
}
