# Pustaka (पुस्तका)

> **A minimalist, local-first block workspace for macOS built with native SwiftUI and a high-performance Rust core (RON-RS & Typst).**

---

## 🌟 Overview

**Pustaka** is a desktop workspace application designed for speed, privacy, and distraction-free writing. It combines the clean, inline block interaction model of Notion with the power of local-first computing, sub-millisecond Rust AST processing, and live vector typesetting powered by Typst.

- **Zero Cloud Lock-in**: Your documents and notes remain strictly local on your machine.
- **Native macOS Experience**: Crafted in pure SwiftUI with macOS 14+ translucent sidebars, unified window toolbars, and Apple Human Interface Guidelines (HIG).
- **Rust-Powered Engine**: Built on Rusty Object Notation (`ron-rs`) block trees and in-memory Typst compiler connected via UniFFI.
- **Agent Communication Protocol (ACP)**: Integrated Tokio WebSocket JSON-RPC server allowing local AI agents to read, append, and manipulate typed block documents.

---

## ✨ Features

### 📝 Notion-Style Inline Block Editor
- **Left Gutter Interaction**: Hover over any block to reveal:
  - `+` (Insert Below): Insert Text, Headings (H1/H2/H3), To-do list, Callouts, or Code Blocks.
  - `⠿` (Arrange Handle): Drag & drop blocks to rearrange them visually with fluid animations.
  - `🗑` (1-Click Delete): Fast, instant deletion of any block row.
- **Natural Keyboard Flow**:
  - Press **Enter** in any block to automatically create a new block below and seamlessly move keyboard focus.
  - Press **Backspace / Delete** on an empty block to instantly delete it and return focus to the previous block.
  - Type **`/`** on any line to trigger the inline **Slash Command Palette** (*Heading 1/2/3, To-do, Callout, Code*).

### 🎨 Page Covers & Icons
- **Vibrant Preset Gradients**: Instant, zero-latency gradient covers (*Sunset, Ocean, Aurora, Midnight, Blush, Emerald*) that render offline without network delays.
- **Unsplash Photography**: Curated free photography covers (*Forest, Night Stars, Ocean Waves, Architecture, Minimal Waves*).
- **Full macOS Emoji & Symbols Palette**: Integrates directly with Apple's native Character Palette (`Ctrl+Cmd+Space`), custom emoji typing, and quick curated grids.

### 🪟 Unified macOS App Bar
- Native unified window toolbar hosting the document title and a single functional `...` menu:
  - **Duplicate Page**
  - **Add to / Remove from Favorites**
  - **Copy Page Title**
  - **Toggle Live Typst Vector Preview (Cmd+P)**
  - **Move to Trash (Delete)**

### ⚡️ Live Typst Vector Renderer
- Slide-over vector typesetting drawer powered by the official Typst compiler in Rust.
- Generates crisp vector SVG previews directly from your block tree in sub-milliseconds.

### 🤖 ACP (Agent Communication Protocol)
- Background WebSocket server running on `ws://127.0.0.1:8080`.
- Supports JSON-RPC 2.0 commands (`pustaka.read_document`, `pustaka.append_block`, `pustaka.compile_document`) for automated workflows and AI pair-programming agents.

---

## 🏗 Architecture & Monorepo

```
Pustaka/
├── crates/
│   ├── pustaka-core/       # RON-RS document engine, PFS normalizer & Typst SVG compiler
│   ├── pustaka-acp/        # Tokio-based WebSocket JSON-RPC server
│   └── pustaka-ffi/        # UniFFI Swift/Rust foreign function interface
├── macos/
│   ├── Pustaka/
│   │   ├── App/            # SwiftUI App entry & main window
│   │   ├── Models/         # Workspace store & reactive models
│   │   └── Views/          # Canvas, Sidebar, Block Editor, and Typst Preview
│   └── project.yml         # XcodeGen specification
├── scripts/
│   └── build-ffi.sh        # UniFFI binding & static library generation script
└── Makefile                # Unified build, test, and install automation
```

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0+ (Sonoma or newer)
- [Xcode 15+](https://developer.apple.com/xcode/) and Command Line Tools
- [Rust toolchain](https://rustup.rs/) (edition 2021)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Building & Running

1. **Clone the repository**:
   ```bash
   git clone https://github.com/naenmad/Pustaka.git
   cd Pustaka
   ```

2. **Run tests**:
   ```bash
   make test
   ```

3. **Build the macOS App (Debug)**:
   ```bash
   make all
   ```

4. **Build and Install to `/Applications`**:
   ```bash
   make install
   ```

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
