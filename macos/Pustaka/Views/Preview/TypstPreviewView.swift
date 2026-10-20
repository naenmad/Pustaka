import SwiftUI
import WebKit

struct SVGWebView: NSViewRepresentable {
    let svgString: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 24px;
            background-color: transparent;
            display: flex;
            justify-content: center;
          }
          svg {
            max-width: 100%;
            height: auto;
            background: white;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.12);
            border-radius: 6px;
          }
        </style>
        </head>
        <body>
          \(svgString)
        </body>
        </html>
        """
        nsView.loadHTMLString(html, baseURL: nil)
    }
}

struct TypstPreviewView: View {
    let svgString: String
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Preview Header Bar
            HStack(spacing: 12) {
                Label("Typst In-Memory Vector Canvas", systemImage: "sparkles")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(svgString, forType: .string)
                    }) {
                        Label("Copy SVG", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let onClose = onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // SVG Content View
            if svgString.contains("<svg") {
                SVGWebView(svgString: svgString)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.3))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("Typst Compilation Error")
                        .font(.headline)

                    ScrollView {
                        Text(svgString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
