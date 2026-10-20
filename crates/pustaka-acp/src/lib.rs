use serde::{Deserialize, Serialize};

pub const DEFAULT_ACP_PORT: u16 = 8080;

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct JsonRpcRequest<T = serde_json::Value> {
    pub jsonrpc: String,
    pub method: String,
    pub params: Option<T>,
    pub id: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct JsonRpcResponse<T> {
    pub jsonrpc: String,
    pub result: Option<T>,
    pub error: Option<JsonRpcError>,
    pub id: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct JsonRpcError {
    pub code: i32,
    pub message: String,
    pub data: Option<serde_json::Value>,
}

pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(version(), "0.1.0");
    }

    #[test]
    fn test_jsonrpc_request_serialization() {
        let req_json = r#"{"jsonrpc":"2.0","method":"pustaka.get_document_tree","id":1}"#;
        let req: JsonRpcRequest = serde_json::from_str(req_json).expect("Deserialization failed");
        assert_eq!(req.jsonrpc, "2.0");
        assert_eq!(req.method, "pustaka.get_document_tree");
        assert_eq!(req.id, serde_json::json!(1));
        assert!(req.params.is_none());
    }

    #[test]
    fn test_jsonrpc_response_serialization() {
        let res = JsonRpcResponse {
            jsonrpc: "2.0".to_string(),
            result: Some(serde_json::json!({ "success": true })),
            error: None,
            id: serde_json::json!(1),
        };
        let json = serde_json::to_string(&res).expect("Serialization failed");
        assert!(json.contains("\"result\":{\"success\":true}"));
    }
}
