# Product Requirement Document (PRD) — Pustaka

## 1. Executive Summary
**Pustaka** is a local-first, block-based desktop workspace for macOS engineered for ultra-fast performance, minimal resource consumption, and seamless real-time integration with external AI agents via the **Agent Communication Protocol (ACP)**.

## 2. Core Value & Vision
- **Ultra-Fast & Lightweight:** Built using SwiftUI for native macOS UI and Rust for the core processing engine.
- **Local-First & Data Ownership:** All documents and databases are stored locally on the user's device.
- **Agentic-Ready:** Provides a high-speed local event-loop and communication server allowing local AI agents (such as Antigravity, MCP Clients, or custom agents) to read, mutate, and manage workspace documents in real time.

## 3. Scope & MVP Features (Phase 1)
- **Document & Workspace Management:**
  - Sidebar document hierarchy (Create, Rename, Delete, Reorder).
  - Local storage backed by SQLite.
- **Block-Based Editor:**
  - Core block types: Heading (H1, H2, H3), Paragraph, Todo List, Code Block, Bullet List.
  - Automatic parsing and export to Markdown (`.md`) format.
- **ACP Integration (Local Server):**
  - Local WebSocket server (`ws://127.0.0.1:8080`) powered by Rust Async (`tokio`).
  - Handles JSON-RPC 2.0 requests from AI agents for real-time document manipulation.

## 4. Non-Functional Requirements
- **Target OS:** macOS 14.0 (Sonoma) or newer.
- **Performance:** App launch time < 1 second, editor rendering at 60+ FPS.
- **Privacy:** Zero document data transmitted to external cloud services by default.