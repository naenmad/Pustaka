use futures_util::{SinkExt, StreamExt};
use pustaka_core::{
    compile_typst_to_svg, deserialize_doc_from_ron, ron_blocks_to_typst, serialize_doc_to_ron,
    Block, BlockColor, BlockKind, PustakaDocument,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::RwLock;
use tokio_tungstenite::accept_async;
use tokio_tungstenite::tungstenite::Message;

pub const DEFAULT_ACP_PORT: u16 = 8080;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JsonRpcRequest {
    pub jsonrpc: String,
    pub method: String,
    #[serde(default)]
    pub params: Option<serde_json::Value>,
    pub id: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JsonRpcResponse<T> {
    pub jsonrpc: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<JsonRpcError>,
    pub id: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Clone)]
pub struct WorkspaceState {
    pub documents: HashMap<String, PustakaDocument>,
}

impl Default for WorkspaceState {
    fn default() -> Self {
        let mut documents = HashMap::new();
        let default_doc = PustakaDocument {
            id: "doc_1".to_string(),
            title: "Welcome to Pustaka".to_string(),
            blocks: vec![
                Block {
                    id: "blk_1".to_string(),
                    kind: BlockKind::Heading {
                        level: 1,
                        text: "Welcome to Pustaka".to_string(),
                    },
                    children: Vec::new(),
                },
                Block {
                    id: "blk_2".to_string(),
                    kind: BlockKind::Callout {
                        icon: "💡".to_string(),
                        color: BlockColor::Blue,
                        text: "High performance RON-RS document engine with Typst vector rendering."
                            .to_string(),
                    },
                    children: Vec::new(),
                },
                Block {
                    id: "blk_3".to_string(),
                    kind: BlockKind::Paragraph(
                        "Pustaka provides local AI agents with real-time ACP JSON-RPC access."
                            .to_string(),
                    ),
                    children: Vec::new(),
                },
            ],
        };
        documents.insert("doc_1".to_string(), default_doc);
        Self { documents }
    }
}

pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

/// Dispatches an ACP JSON-RPC 2.0 request against the shared WorkspaceState.
pub async fn handle_jsonrpc(req_str: &str, state: &RwLock<WorkspaceState>) -> String {
    let req: JsonRpcRequest = match serde_json::from_str(req_str) {
        Ok(r) => r,
        Err(e) => {
            let res = JsonRpcResponse::<serde_json::Value> {
                jsonrpc: "2.0".to_string(),
                result: None,
                error: Some(JsonRpcError {
                    code: -32700,
                    message: format!("Parse error: {}", e),
                    data: None,
                }),
                id: serde_json::Value::Null,
            };
            return serde_json::to_string(&res).unwrap();
        }
    };

    match req.method.as_str() {
        "pustaka.get_document_tree" => {
            let read_guard = state.read().await;
            let doc_list: Vec<serde_json::Value> = read_guard
                .documents
                .values()
                .map(|doc| {
                    serde_json::json!({
                        "id": doc.id,
                        "title": doc.title,
                        "parent_id": serde_json::Value::Null,
                    })
                })
                .collect();

            let res = JsonRpcResponse {
                jsonrpc: "2.0".to_string(),
                result: Some(serde_json::json!({ "documents": doc_list })),
                error: None,
                id: req.id,
            };
            serde_json::to_string(&res).unwrap()
        }

        "pustaka.read_document" => {
            let doc_id = req
                .params
                .as_ref()
                .and_then(|p| p.get("doc_id"))
                .and_then(|v| v.as_str())
                .unwrap_or("doc_1");

            let read_guard = state.read().await;
            if let Some(doc) = read_guard.documents.get(doc_id) {
                let ron_str = serialize_doc_to_ron(doc);
                let res = JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(serde_json::json!({
                        "doc_id": doc.id,
                        "title": doc.title,
                        "blocks_ron": ron_str,
                        "blocks": serde_json::to_value(&doc.blocks).unwrap_or(serde_json::json!([])),
                    })),
                    error: None,
                    id: req.id,
                };
                serde_json::to_string(&res).unwrap()
            } else {
                let res = JsonRpcResponse::<serde_json::Value> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(JsonRpcError {
                        code: -32602,
                        message: format!("Document '{}' not found", doc_id),
                        data: None,
                    }),
                    id: req.id,
                };
                serde_json::to_string(&res).unwrap()
            }
        }

        "pustaka.append_block" => {
            let params = req.params.as_ref();
            let doc_id = params
                .and_then(|p| p.get("doc_id"))
                .and_then(|v| v.as_str())
                .unwrap_or("doc_1");

            let block = if let Some(ron_str) = params.and_then(|p| p.get("block_ron")).and_then(|v| v.as_str()) {
                match ron::from_str::<Block>(ron_str) {
                    Ok(b) => b,
                    Err(e) => {
                        let res = JsonRpcResponse::<serde_json::Value> {
                            jsonrpc: "2.0".to_string(),
                            result: None,
                            error: Some(JsonRpcError {
                                code: -32602,
                                message: format!("Invalid block_ron: {}", e),
                                data: None,
                            }),
                            id: req.id,
                        };
                        return serde_json::to_string(&res).unwrap();
                    }
                }
            } else {
                let content = params
                    .and_then(|p| p.get("content"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("New Block");
                Block {
                    id: format!("blk_{}", uuid::Uuid::new_v4().simple()),
                    kind: BlockKind::Paragraph(content.to_string()),
                    children: Vec::new(),
                }
            };

            let block_id = block.id.clone();
            let mut write_guard = state.write().await;
            if let Some(doc) = write_guard.documents.get_mut(doc_id) {
                doc.blocks.push(block);
                let res = JsonRpcResponse {
                    jsonrpc: "2.0".to_string(),
                    result: Some(serde_json::json!({
                        "success": true,
                        "block_id": block_id,
                    })),
                    error: None,
                    id: req.id,
                };
                serde_json::to_string(&res).unwrap()
            } else {
                let res = JsonRpcResponse::<serde_json::Value> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(JsonRpcError {
                        code: -32602,
                        message: format!("Document '{}' not found", doc_id),
                        data: None,
                    }),
                    id: req.id,
                };
                serde_json::to_string(&res).unwrap()
            }
        }

        "pustaka.update_block" => {
            let params = req.params.as_ref();
            let block_id = params
                .and_then(|p| p.get("block_id"))
                .and_then(|v| v.as_str());

            if block_id.is_none() {
                let res = JsonRpcResponse::<serde_json::Value> {
                    jsonrpc: "2.0".to_string(),
                    result: None,
                    error: Some(JsonRpcError {
                        code: -32602,
                        message: "Missing block_id".to_string(),
                        data: None,
                    }),
                    id: req.id,
                };
                return serde_json::to_string(&res).unwrap();
            }

            let block_id = block_id.unwrap();
            let mut updated = false;

            if let Some(ron_str) = params.and_then(|p| p.get("block_ron")).and_then(|v| v.as_str()) {
                if let Ok(new_block) = ron::from_str::<Block>(ron_str) {
                    let mut write_guard = state.write().await;
                    for doc in write_guard.documents.values_mut() {
                        for blk in &mut doc.blocks {
                            if blk.id == block_id {
                                blk.kind = new_block.kind.clone();
                                blk.children = new_block.children.clone();
                                updated = true;
                                break;
                            }
                        }
                    }
                }
            }

            let res = JsonRpcResponse {
                jsonrpc: "2.0".to_string(),
                result: Some(serde_json::json!({ "success": updated })),
                error: None,
                id: req.id,
            };
            serde_json::to_string(&res).unwrap()
        }

        "pustaka.delete_block" => {
            let params = req.params.as_ref();
            let block_id = params
                .and_then(|p| p.get("block_id"))
                .and_then(|v| v.as_str())
                .unwrap_or("");

            let mut write_guard = state.write().await;
            let mut deleted = false;
            for doc in write_guard.documents.values_mut() {
                let initial_len = doc.blocks.len();
                doc.blocks.retain(|b| b.id != block_id);
                if doc.blocks.len() != initial_len {
                    deleted = true;
                }
            }

            let res = JsonRpcResponse {
                jsonrpc: "2.0".to_string(),
                result: Some(serde_json::json!({ "success": deleted })),
                error: None,
                id: req.id,
            };
            serde_json::to_string(&res).unwrap()
        }

        "pustaka.compile_document" => {
            let params = req.params.as_ref();
            let blocks: Option<Vec<Block>> = if let Some(ron_str) = params.and_then(|p| p.get("blocks_ron")).and_then(|v| v.as_str()) {
                ron::from_str::<Vec<Block>>(ron_str)
                    .or_else(|_| deserialize_doc_from_ron(ron_str).map(|d| d.blocks))
                    .ok()
            } else {
                let doc_id = params.and_then(|p| p.get("doc_id")).and_then(|v| v.as_str()).unwrap_or("doc_1");
                let read_guard = state.read().await;
                read_guard.documents.get(doc_id).map(|d| d.blocks.clone())
            };

            match blocks {
                Some(b) => {
                    let typst_markup = ron_blocks_to_typst(&b);
                    match compile_typst_to_svg(&typst_markup) {
                        Ok(svg) => {
                            let res = JsonRpcResponse {
                                jsonrpc: "2.0".to_string(),
                                result: Some(serde_json::json!({ "svg": svg })),
                                error: None,
                                id: req.id,
                            };
                            serde_json::to_string(&res).unwrap()
                        }
                        Err(compile_err) => {
                            let res = JsonRpcResponse::<serde_json::Value> {
                                jsonrpc: "2.0".to_string(),
                                result: None,
                                error: Some(JsonRpcError {
                                code: -32000,
                                message: format!("Typst compilation error: {}", compile_err),
                                data: None,
                            }),
                            id: req.id,
                        };
                        serde_json::to_string(&res).unwrap()
                        }
                    }
                }
                None => {
                    let res = JsonRpcResponse::<serde_json::Value> {
                        jsonrpc: "2.0".to_string(),
                        result: None,
                        error: Some(JsonRpcError {
                            code: -32602,
                            message: "Failed to find or parse target blocks".to_string(),
                            data: None,
                        }),
                        id: req.id,
                    };
                    serde_json::to_string(&res).unwrap()
                }
            }
        }

        other => {
            let res = JsonRpcResponse::<serde_json::Value> {
                jsonrpc: "2.0".to_string(),
                result: None,
                error: Some(JsonRpcError {
                    code: -32601,
                    message: format!("Method '{}' not found", other),
                    data: None,
                }),
                id: req.id,
            };
            serde_json::to_string(&res).unwrap()
        }
    }
}

/// Spawns the Tokio WebSocket ACP server listening on the specified address.
pub async fn start_acp_server(addr: &str, state: Arc<RwLock<WorkspaceState>>) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let listener = TcpListener::bind(addr).await?;
    tracing::info!("Pustaka ACP WebSocket server listening on ws://{}", addr);

    while let Ok((stream, peer_addr)) = listener.accept().await {
        let state_clone = Arc::clone(&state);
        tokio::spawn(handle_connection(stream, peer_addr, state_clone));
    }

    Ok(())
}

async fn handle_connection(stream: TcpStream, _peer: SocketAddr, state: Arc<RwLock<WorkspaceState>>) {
    let ws_stream = match accept_async(stream).await {
        Ok(ws) => ws,
        Err(e) => {
            tracing::error!("WebSocket handshake error: {}", e);
            return;
        }
    };

    let (mut write, mut read) = ws_stream.split();

    while let Some(msg) = read.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                let response = handle_jsonrpc(&text, &state).await;
                if write.send(Message::Text(response.into())).await.is_err() {
                    break;
                }
            }
            Ok(Message::Ping(data)) => {
                if write.send(Message::Pong(data)).await.is_err() {
                    break;
                }
            }
            Ok(Message::Close(_)) | Err(_) => break,
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(version(), "0.1.0");
    }

    #[tokio::test]
    async fn test_get_document_tree() {
        let state = RwLock::new(WorkspaceState::default());
        let req = r#"{"jsonrpc":"2.0","method":"pustaka.get_document_tree","id":1}"#;
        let res_str = handle_jsonrpc(req, &state).await;
        assert!(res_str.contains("doc_1"));
        assert!(res_str.contains("Welcome to Pustaka"));
    }

    #[tokio::test]
    async fn test_read_document() {
        let state = RwLock::new(WorkspaceState::default());
        let req = r#"{"jsonrpc":"2.0","method":"pustaka.read_document","params":{"doc_id":"doc_1"},"id":2}"#;
        let res_str = handle_jsonrpc(req, &state).await;
        assert!(res_str.contains("blocks_ron"));
        assert!(res_str.contains("Welcome to Pustaka"));
    }

    #[tokio::test]
    async fn test_append_and_update_block() {
        let state = RwLock::new(WorkspaceState::default());
        let append_req = r#"{
            "jsonrpc": "2.0",
            "method": "pustaka.append_block",
            "params": {
                "doc_id": "doc_1",
                "block_ron": "Block(id: \"blk_ai\", kind: Callout(icon: \"🤖\", color: Green, text: \"AI-generated block\"), children: [])"
            },
            "id": 3
        }"#;

        let append_res = handle_jsonrpc(append_req, &state).await;
        assert!(append_res.contains("\"success\":true"));
        assert!(append_res.contains("blk_ai"));

        let update_req = r#"{
            "jsonrpc": "2.0",
            "method": "pustaka.update_block",
            "params": {
                "block_id": "blk_ai",
                "block_ron": "Block(id: \"blk_ai\", kind: Callout(icon: \"⚡\", color: Red, text: \"Updated by Agent\"), children: [])"
            },
            "id": 4
        }"#;
        let update_res = handle_jsonrpc(update_req, &state).await;
        assert!(update_res.contains("\"success\":true"));
    }

    #[tokio::test]
    async fn test_compile_document() {
        let state = RwLock::new(WorkspaceState::default());
        let req = r#"{
            "jsonrpc": "2.0",
            "method": "pustaka.compile_document",
            "params": {
                "blocks_ron": "[(id: \"b1\", kind: Heading(level: 1, text: \"ACP Compiled Title\"), children: [])]"
            },
            "id": 5
        }"#;
        let res = handle_jsonrpc(req, &state).await;
        assert!(res.contains("<svg"));
        assert!(res.contains("</svg>"));
    }
}
