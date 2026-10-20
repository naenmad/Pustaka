use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlockColor {
    Default,
    Red,
    Blue,
    Green,
    Custom(String),
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum BlockKind {
    Heading { level: u8, text: String },
    Paragraph(String),
    Callout { icon: String, color: BlockColor, text: String },
    Grid { columns: Vec<Vec<Block>> },
    CodeBlock { language: String, code: String },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Block {
    pub id: String,
    pub kind: BlockKind,
    #[serde(default)]
    pub children: Vec<Block>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PustakaDocument {
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub blocks: Vec<Block>,
}

/// Serializes a PustakaDocument into a RON string.
pub fn serialize_doc_to_ron(doc: &PustakaDocument) -> String {
    let pretty = ron::ser::PrettyConfig::default().struct_names(true);
    ron::ser::to_string_pretty(doc, pretty).unwrap_or_else(|_| ron::to_string(doc).unwrap())
}

/// Deserializes a PustakaDocument from a RON string.
pub fn deserialize_doc_from_ron(ron_str: &str) -> Result<PustakaDocument, ron::Error> {
    ron::from_str(ron_str).map_err(|e| e.code)
}

/// Converts both Pustaka Fast Syntax (PFS) and Markdown into typed `Block` instances.
pub fn pfs_to_ron_blocks(input_text: &str) -> Vec<Block> {
    let mut blocks = Vec::new();
    let mut counter: usize = 0;
    let mut next_id = || {
        counter += 1;
        format!("blk_{}", counter)
    };

    let mut in_code = false;
    let mut code_lang = String::new();
    let mut code_lines = Vec::new();

    for line in input_text.lines() {
        let trimmed_start = line.trim_start();

        // Handle code fences
        if trimmed_start.starts_with("```") {
            if !in_code {
                in_code = true;
                code_lang = trimmed_start.trim_start_matches('`').trim().to_string();
                code_lines.clear();
            } else {
                in_code = false;
                blocks.push(Block {
                    id: next_id(),
                    kind: BlockKind::CodeBlock {
                        language: if code_lang.is_empty() { "text".to_string() } else { code_lang.clone() },
                        code: code_lines.join("\n"),
                    },
                    children: Vec::new(),
                });
            }
            continue;
        }

        if in_code {
            code_lines.push(line.to_string());
            continue;
        }

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        // Headings: PFS (. , .. , ... ) or Markdown (# , ## , ### )
        if let Some(rest) = trimmed.strip_prefix("... ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Heading { level: 3, text: rest.trim().to_string() },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix("### ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Heading { level: 3, text: rest.trim().to_string() },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(".. ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Heading { level: 2, text: rest.trim().to_string() },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix("## ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Heading { level: 2, text: rest.trim().to_string() },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(". ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Heading { level: 1, text: rest.trim().to_string() },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix("# ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Heading { level: 1, text: rest.trim().to_string() },
                children: Vec::new(),
            });
        }
        // Callouts: PFS :info, :warn, :tip, :callout, Markdown > , PFS ,
        else if let Some(rest) = trimmed.strip_prefix(":info ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "💡".to_string(),
                    color: BlockColor::Blue,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(":warn ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "⚠️".to_string(),
                    color: BlockColor::Red,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(":warning ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "⚠️".to_string(),
                    color: BlockColor::Red,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(":tip ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "✅".to_string(),
                    color: BlockColor::Green,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(":callout ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "💬".to_string(),
                    color: BlockColor::Default,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix(", ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "📌".to_string(),
                    color: BlockColor::Default,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        } else if let Some(rest) = trimmed.strip_prefix("> ") {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Callout {
                    icon: "💬".to_string(),
                    color: BlockColor::Default,
                    text: rest.trim().to_string(),
                },
                children: Vec::new(),
            });
        }
        // Grid shorthand: [grid] col1 | col2 [/grid]
        else if trimmed.starts_with("[grid]") && trimmed.ends_with("[/grid]") {
            let inner = &trimmed[6..trimmed.len() - 7];
            let cols: Vec<Vec<Block>> = inner
                .split('|')
                .map(|col_text| {
                    vec![Block {
                        id: next_id(),
                        kind: BlockKind::Paragraph(col_text.trim().to_string()),
                        children: Vec::new(),
                    }]
                })
                .collect();
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Grid { columns: cols },
                children: Vec::new(),
            });
        }
        // Normal paragraph
        else {
            blocks.push(Block {
                id: next_id(),
                kind: BlockKind::Paragraph(trimmed.to_string()),
                children: Vec::new(),
            });
        }
    }

    // Flush unclosed code block if file ends
    if in_code {
        blocks.push(Block {
            id: next_id(),
            kind: BlockKind::CodeBlock {
                language: if code_lang.is_empty() { "text".to_string() } else { code_lang },
                code: code_lines.join("\n"),
            },
            children: Vec::new(),
        });
    }

    blocks
}

/// Transpiles a slice of RON `Block` structures into valid Typst markup.
pub fn ron_blocks_to_typst(blocks: &[Block]) -> String {
    let mut out = String::new();
    out.push_str("#set page(paper: \"a4\", margin: (x: 2cm, y: 2.5cm))\n");
    out.push_str("#set text(font: (\"Liberation Sans\", \"DejaVu Sans\", \"Helvetica Neue\", \"Arial\"), size: 11pt)\n");
    out.push_str("#set par(justify: false, leading: 0.75em)\n\n");

    for block in blocks {
        render_block_typst(block, &mut out);
    }

    out
}

fn render_block_typst(block: &Block, out: &mut String) {
    match &block.kind {
        BlockKind::Heading { level, text } => {
            let prefix = "=".repeat((*level).max(1) as usize);
            out.push_str(&format!("{} {}\n\n", prefix, text));
        }
        BlockKind::Paragraph(text) => {
            out.push_str(&format!("{}\n\n", text));
        }
        BlockKind::Callout { icon, color, text } => {
            let (bg, stroke) = match color {
                BlockColor::Default => ("rgb(\"#f4f4f5\")", "rgb(\"#71717a\")"),
                BlockColor::Red => ("rgb(\"#fef2f2\")", "rgb(\"#ef4444\")"),
                BlockColor::Blue => ("rgb(\"#eff6ff\")", "rgb(\"#3b82f6\")"),
                BlockColor::Green => ("rgb(\"#f0fdf4\")", "rgb(\"#22c55e\")"),
                BlockColor::Custom(_) => ("rgb(\"#f9fafb\")", "rgb(\"#6366f1\")"),
            };

            out.push_str(&format!(
                "#block(fill: {}, stroke: (left: 3pt + {}), inset: (x: 12pt, y: 10pt), radius: (right: 4pt), width: 100%)[\n  #grid(columns: (auto, 1fr), gutter: 10pt, [#text(size: 13pt)[{}]], [{}])\n]\n\n",
                bg, stroke, icon, text
            ));
        }
        BlockKind::Grid { columns } => {
            out.push_str(&format!("#grid(columns: {}, gutter: 14pt", columns.len()));
            for col in columns {
                out.push_str(", [\n");
                for sub_block in col {
                    render_block_typst(sub_block, out);
                }
                out.push_str("]");
            }
            out.push_str(")\n\n");
        }
        BlockKind::CodeBlock { language, code } => {
            let escaped = code.replace('\\', "\\\\").replace('"', "\\\"");
            out.push_str(&format!(
                "#raw(\"{}\", lang: \"{}\", block: true)\n\n",
                escaped, language
            ));
        }
    }

    // Render children recursively if present
    for child in &block.children {
        render_block_typst(child, out);
    }
}
