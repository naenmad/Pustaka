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
            padding: 20px;
            background-color: transparent;
            display: flex;
            justify-content: center;
          }
          svg {
            max-width: 100%;
            height: auto;
            background: white;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.15);
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

struct ContentView: View {
    @State private var engineInfo: String = "Loading..."
    @State private var inputPfs: String = """
    . Welcome to Pustaka
    .. Fast Syntax & Typst Live Preview
    :info Pustaka converts PFS & Markdown into typed RON blocks, rendered instantly via Typst.
    :warn Zero cloud lock-in. 100% local-first workspace.
    , Fast low-friction item
    > Blockquote formatted as callout

    [grid] Column A: Rust Backend | Column B: SwiftUI Frontend [/grid]

    ```rust
    fn compile_workspace() {
        println!("Sub-millisecond vector rendering!");
    }
    ```
    """
    @State private var ronOutput: String = ""
    @State private var svgOutput: String = ""
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pustaka")
                        .font(.headline.bold())

                    Text(engineInfo)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("View", selection: $selectedTab) {
                    Text("Live Typst Preview").tag(0)
                    Text("RON Block Tree").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Split View: Editor on Left, Live Typst Preview / RON on Right
            HSplitView {
                // Left: Input Editor
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("Editor (PFS / Markdown)", systemImage: "pencil.line")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(inputPfs.count) chars")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    TextEditor(text: $inputPfs)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        .onChange(of: inputPfs) { _, newValue in
                            recompileDocument(newValue)
                        }
                }
                .frame(minWidth: 320, idealWidth: 420)

                // Right: Typst Vector Preview or RON Inspector
                VStack(alignment: .leading, spacing: 6) {
                    if selectedTab == 0 {
                        HStack {
                            Label("Typst In-Memory Vector Render", systemImage: "sparkles")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Circle()
                                .fill(svgOutput.starts_with_svg() ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        if svgOutput.starts_with_svg() {
                            SVGWebView(svgString: svgOutput)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .padding(.horizontal, 10)
                                .padding(.bottom, 10)
                        } else {
                            ScrollView {
                                Text(svgOutput)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.red)
                                    .padding()
                            }
                        }
                    } else {
                        HStack {
                            Label("RON Block Representation", systemImage: "curlybraces")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ScrollView {
                            Text(ronOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                }
                .frame(minWidth: 400, idealWidth: 560)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        .onAppear {
            self.engineInfo = getEngineInfo()
            recompileDocument(inputPfs)
        }
    }

    private func recompileDocument(_ input: String) {
        let ron = parsePfsToRon(input: input)
        self.ronOutput = ron
        let svg = renderRonToSvg(ronStr: ron)
        self.svgOutput = svg
    }
}

fileprivate extension String {
    func starts_with_svg() -> Bool {
        return self.contains("<svg")
    }
}

#Preview {
    ContentView()
}
