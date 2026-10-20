# Product Requirement Document (PRD) — Pustaka

## 1. Executive Summary
**Pustaka** is a local-first, block-based desktop workspace for macOS engineered for ultra-fast performance, zero latency, and beautiful typography. It reimagines document creation as a high-performance Notion competitor powered by a strongly-typed **Rusty Object Notation (RON-RS)** block tree and the **Typst compiler** for live, sub-millisecond vector previewing.

## 2. Core Value & Vision
- **RON-RS Block Tree:** Documents are stored and manipulated as structured, typed Rust data structures serialized using RON (Rusty Object Notation), providing human-readable, schema-validatable, and CRDT-friendly document models.
- **Pustaka Fast Syntax (PFS) & Markdown:** Hybrid input system allowing users to type using ultra-fast punctuation shortcuts (e.g., `. `, `.. `, `, `, `:info `) or standard Markdown, automatically normalized into RON blocks.
- **Typst Live Rendering:** Native in-memory compilation of RON blocks to Typst markup and SVG output, delivering publisher-grade typography at 60+ FPS live preview in SwiftUI without external dependencies.
- **Agentic-Ready (ACP):** Local WebSocket server (`ws://127.0.0.1:8080`) implementing JSON-RPC 2.0 ACP, allowing local AI agents (Antigravity, MCP clients, custom LLM agents) to query, mutate, and compile typed RON blocks directly.
- **Local-First & Privacy:** 100% on-device data ownership with zero cloud lock-in.

## 3. Scope & Architecture (Phase 2 Upgrade)
- **Editor & Data Pipeline:**
  - Pustaka Fast Syntax (PFS) & Markdown parsing.
  - Normalization into hierarchical `Block` and `PustakaDocument` structures.
  - In-memory transpilation from RON blocks to Typst markup.
  - Typst compiler rendering directly to scalable vector graphics (SVG).
- **Core Block Types:**
  - `Heading { level, text }` (Levels 1–3)
  - `Paragraph(text)`
  - `Callout { icon, color, text }` (Supports Default, Red, Blue, Green, Custom colors)
  - `Grid { columns }` (Multi-column block layouts)
  - `CodeBlock { language, code }`
- **Agent Communication Protocol (ACP):**
  - Typed block inspection (`pustaka.read_document`).
  - Structured block mutation (`pustaka.append_block`, `pustaka.update_block`, `pustaka.delete_block`).
  - Live preview compilation triggering (`pustaka.compile_document`).

## 4. Non-Functional Requirements
- **Target OS:** macOS 14.0 (Sonoma) or newer.
- **Performance:** In-memory Typst compilation to SVG < 10ms for typical documents.
- **Native Experience:** Native macOS SwiftUI views rendering vector SVGs via UniFFI bridge.
