# Agent Communication Protocol (ACP) Specification — Pustaka (RON Engine)

## 1. Overview
The Agent Communication Protocol (ACP) is a local JSON-RPC 2.0 interface enabling AI agents (such as Antigravity, MCP clients, or local LLMs) to inspect, manipulate, and compile typed RON-RS documents within Pustaka.

## 2. Transport & Protocol
- **Transport:** WebSocket (`ws://127.0.0.1:8080`)
- **Protocol:** JSON-RPC 2.0
- **Serialization Format:** Strongly-typed RON (Rusty Object Notation) strings alongside structured JSON representations.

## 3. Data Representation

### 3.1 Block Schema in RON
```rust
Block(
  id: "blk_1",
  kind: Heading(level: 1, text: "Project Roadmap"),
  children: [],
)
```

### 3.2 Block Kinds
- `Heading(level: u8, text: String)`
- `Paragraph(String)`
- `Callout(icon: String, color: BlockColor, text: String)`
  - Colors: `Default`, `Red`, `Blue`, `Green`, `Custom(String)`
- `Grid(columns: Vec<Vec<Block>>)`
- `CodeBlock(language: String, code: String)`

---

## 4. JSON-RPC Methods

### 4.1 `pustaka.get_document_tree`
Retrieves the workspace document tree.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "pustaka.get_document_tree",
  "id": 1
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "documents": [
      { "id": "doc_1", "title": "Architecture Overview", "parent_id": null }
    ]
  },
  "id": 1
}
```

### 4.2 `pustaka.read_document`
Reads a document and its full RON block tree.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "pustaka.read_document",
  "params": { "doc_id": "doc_1" },
  "id": 2
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "doc_id": "doc_1",
    "title": "Architecture Overview",
    "blocks_ron": "[(id:\"blk_1\",kind:Heading(level:1,text:\"Architecture\"),children:[])]",
    "blocks": [
      {
        "id": "blk_1",
        "kind": { "Heading": { "level": 1, "text": "Architecture" } },
        "children": []
      }
    ]
  },
  "id": 2
}
```

### 4.3 `pustaka.append_block`
Appends a typed block to a target document.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "pustaka.append_block",
  "params": {
    "doc_id": "doc_1",
    "block_ron": "Block(id: \"blk_2\", kind: Callout(icon: \"💡\", color: Blue, text: \"Key takeaway\"), children: [])"
  },
  "id": 3
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "block_id": "blk_2"
  },
  "id": 3
}
```

### 4.4 `pustaka.update_block`
Updates a block by id with a new typed RON definition.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "pustaka.update_block",
  "params": {
    "block_id": "blk_2",
    "block_ron": "Block(id: \"blk_2\", kind: Callout(icon: \"⚠️\", color: Red, text: \"Action required\"), children: [])"
  },
  "id": 4
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true
  },
  "id": 4
}
```

### 4.5 `pustaka.delete_block`
Deletes a block from a document.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "pustaka.delete_block",
  "params": {
    "block_id": "blk_2"
  },
  "id": 5
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true
  },
  "id": 5
}
```

### 4.6 `pustaka.compile_document`
Compiles typed RON blocks directly into Typst-rendered vector SVG.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "pustaka.compile_document",
  "params": {
    "blocks_ron": "[(id:\"blk_1\",kind:Heading(level:1,text:\"Pustaka\"),children:[])]"
  },
  "id": 6
}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "svg": "<svg xmlns=\"http://www.w3.org/2000/svg\" ...>...</svg>"
  },
  "id": 6
}
```
