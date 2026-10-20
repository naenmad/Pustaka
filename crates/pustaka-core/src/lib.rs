pub mod block;
pub mod models;
pub mod typst_compiler;

pub use block::{
    deserialize_doc_from_ron, pfs_to_ron_blocks, ron_blocks_to_typst, serialize_doc_to_ron,
    Block, BlockColor, BlockKind, PustakaDocument,
};
pub use typst_compiler::compile_typst_to_svg;

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
    fn test_ron_doc_roundtrip() {
        let doc = PustakaDocument {
            id: "doc_test".to_string(),
            title: "Test Workspace Document".to_string(),
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
                        text: "Local-first with Typst previewing".to_string(),
                    },
                    children: Vec::new(),
                },
                Block {
                    id: "blk_3".to_string(),
                    kind: BlockKind::Paragraph("Standard text block.".to_string()),
                    children: Vec::new(),
                },
            ],
        };

        let ron_str = serialize_doc_to_ron(&doc);
        assert!(ron_str.contains("PustakaDocument"));
        assert!(ron_str.contains("Welcome to Pustaka"));

        let deserialized = deserialize_doc_from_ron(&ron_str).expect("Failed to deserialize RON");
        assert_eq!(deserialized.id, doc.id);
        assert_eq!(deserialized.blocks.len(), 3);
        assert_eq!(deserialized.blocks[1].kind, doc.blocks[1].kind);
    }

    #[test]
    fn test_pfs_and_markdown_normalization() {
        let input = r#"
. PFS Heading 1
.. PFS Heading 2
... PFS Heading 3
# Markdown Heading 1
## Markdown Heading 2
:info This is an important note
:warn Caution advised
:tip Good to know
, Bullet sub-item
> Blockquote callout
[grid] Column A | Column B [/grid]
```rust
fn main() {
    println!("Hello, Pustaka!");
}
```
Regular paragraph text
"#;

        let blocks = pfs_to_ron_blocks(input);
        assert_eq!(blocks.len(), 13);

        // Check headings
        assert_eq!(
            blocks[0].kind,
            BlockKind::Heading { level: 1, text: "PFS Heading 1".to_string() }
        );
        assert_eq!(
            blocks[1].kind,
            BlockKind::Heading { level: 2, text: "PFS Heading 2".to_string() }
        );
        assert_eq!(
            blocks[2].kind,
            BlockKind::Heading { level: 3, text: "PFS Heading 3".to_string() }
        );
        assert_eq!(
            blocks[3].kind,
            BlockKind::Heading { level: 1, text: "Markdown Heading 1".to_string() }
        );

        // Check callouts
        assert_eq!(
            blocks[5].kind,
            BlockKind::Callout {
                icon: "💡".to_string(),
                color: BlockColor::Blue,
                text: "This is an important note".to_string()
            }
        );
        assert_eq!(
            blocks[6].kind,
            BlockKind::Callout {
                icon: "⚠️".to_string(),
                color: BlockColor::Red,
                text: "Caution advised".to_string()
            }
        );

        // Check Grid
        match &blocks[10].kind {
            BlockKind::Grid { columns } => {
                assert_eq!(columns.len(), 2);
            }
            other => panic!("Expected Grid, got {:?}", other),
        }

        // Check CodeBlock
        match &blocks[11].kind {
            BlockKind::CodeBlock { language, code } => {
                assert_eq!(language, "rust");
                assert!(code.contains("Hello, Pustaka!"));
            }
            other => panic!("Expected CodeBlock, got {:?}", other),
        }
    }

    #[test]
    fn test_ron_blocks_to_typst() {
        let blocks = vec![
            Block {
                id: "b1".to_string(),
                kind: BlockKind::Heading {
                    level: 1,
                    text: "Typst Transpiler Test".to_string(),
                },
                children: Vec::new(),
            },
            Block {
                id: "b2".to_string(),
                kind: BlockKind::Callout {
                    icon: "✅".to_string(),
                    color: BlockColor::Green,
                    text: "Compiled via Typst".to_string(),
                },
                children: Vec::new(),
            },
        ];

        let typst_markup = ron_blocks_to_typst(&blocks);
        assert!(typst_markup.contains("= Typst Transpiler Test"));
        assert!(typst_markup.contains("#block"));
        assert!(typst_markup.contains("Compiled via Typst"));
    }

    #[test]
    fn test_compile_typst_to_svg() {
        let typst_code = r#"
#set page(width: 300pt, height: 200pt, margin: 10pt)
= Hello from Typst
This is vector text rendered in-memory.
"#;
        let svg_result = compile_typst_to_svg(typst_code);
        assert!(svg_result.is_ok(), "Typst compilation failed: {:?}", svg_result.err());
        let svg = svg_result.unwrap();
        assert!(svg.contains("<svg"));
        assert!(svg.contains("</svg>"));
    }

    #[test]
    fn test_end_to_end_pipeline() {
        let input = ". Fast Document\n:info Real-time Typst Vector Preview\nThis is paragraph content.";
        let blocks = pfs_to_ron_blocks(input);
        let typst_code = ron_blocks_to_typst(&blocks);
        let svg = compile_typst_to_svg(&typst_code).expect("End-to-end compilation failed");
        assert!(svg.starts_with("<svg"));
    }
}
