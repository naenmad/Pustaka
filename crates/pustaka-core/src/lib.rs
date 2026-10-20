pub mod models;

pub use models::{Block, BlockType, Document};

pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    #[test]
    fn test_version() {
        assert_eq!(version(), "0.1.0");
    }

    #[test]
    fn test_block_serialization() {
        let block = Block {
            id: "blk_1".to_string(),
            doc_id: "doc_1".to_string(),
            block_type: BlockType::Heading,
            content: "Hello Pustaka".to_string(),
            properties: serde_json::json!({ "level": 1 }),
            order_index: 0,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        let json = serde_json::to_string(&block).expect("Serialization failed");
        assert!(json.contains("\"type\":\"heading\""));
        assert!(json.contains("\"content\":\"Hello Pustaka\""));

        let deserialized: Block = serde_json::from_str(&json).expect("Deserialization failed");
        assert_eq!(deserialized.id, "blk_1");
        assert_eq!(deserialized.block_type, BlockType::Heading);
    }
}
