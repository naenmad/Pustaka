# Technical Architecture — Pustaka Monorepo

## 1. High-Level Architecture
Pustaka enforces a **Decoupled Architecture**:

+---------------------------------------------------------+
|                  SwiftUI (macOS App)                    |
|   • View Layer & Native macOS UX                        |
|   • Reactive State Management (@Observable)             |
+----------------------------+----------------------------+
                             | UniFFI (C-ABI Bridge)
+----------------------------v----------------------------+
|                    Rust Core Engine                     |
|  +-------------------------+-------------------------+  |
|  |      pustaka-core       |       pustaka-acp       |  |
|  |  • SQLite Manager       |  • Tokio WS Server      |  |
|  |  • Block Engine & CRDT  |  • JSON-RPC Router      |  |
|  +-------------------------+-------------------------+  |
+---------------------------------------------------------+

## 2. Repository Structure
The monorepo is managed using a Cargo Workspace for Rust crate isolation alongside an Xcode Project for the macOS application:

pustaka/
├── Cargo.toml                  # Rust Workspace manifest
├── crates/
│   ├── pustaka-core/           # Block schemas, SQLite manager, Markdown parser
│   ├── pustaka-acp/            # WebSocket Server & ACP Protocol Handler
│   └── pustaka-ffi/            # UniFFI interface exporter for Swift
└── macos/                      # Xcode Project / SwiftUI App

## 3. Core Components Detail
- **`pustaka-core`**: Leverages `rusqlite`/`sqlx` for local storage and `pulldown-cmark` for fast Markdown conversion.
- **`pustaka-acp`**: Utilizes `tokio` and `tokio-tungstenite` to run a non-blocking WebSocket server on a background thread.
- **`pustaka-ffi`**: Generates a C-static library (`.a`) and Swift bindings using Mozilla's UniFFI.
- **`macos/`**: Native SwiftUI application importing UniFFI bindings to interact with the Rust Core Engine.