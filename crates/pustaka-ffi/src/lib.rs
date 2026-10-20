uniffi::setup_scaffolding!();

use pustaka_core::{
    compile_typst_to_svg, deserialize_doc_from_ron, pfs_to_ron_blocks, ron_blocks_to_typst,
    Block, PustakaDocument,
};

#[uniffi::export]
pub fn parse_pfs_to_ron(input: String) -> String {
    let blocks = pfs_to_ron_blocks(&input);
    let doc = PustakaDocument {
        id: "doc_current".to_string(),
        title: "Workspace Document".to_string(),
        blocks,
    };
    pustaka_core::serialize_doc_to_ron(&doc)
}

#[uniffi::export]
pub fn render_ron_to_svg(ron_str: String) -> String {
    // Attempt deserializing as full PustakaDocument, or fallback to Vec<Block>
    let blocks: Vec<Block> = match deserialize_doc_from_ron(&ron_str) {
        Ok(doc) => doc.blocks,
        Err(_) => match ron::from_str::<Vec<Block>>(&ron_str) {
            Ok(b) => b,
            Err(e) => {
                return format!(
                    "<svg xmlns=\"http://www.w3.org/2000/svg\"><text y=\"20\" fill=\"red\">RON Parse Error: {}</text></svg>",
                    e
                );
            }
        },
    };

    let typst_code = ron_blocks_to_typst(&blocks);
    match compile_typst_to_svg(&typst_code) {
        Ok(svg) => svg,
        Err(err) => format!(
            "<svg xmlns=\"http://www.w3.org/2000/svg\"><text y=\"20\" fill=\"red\">Typst Compile Error: {}</text></svg>",
            err
        ),
    }
}

#[uniffi::export]
pub fn get_engine_info() -> String {
    format!(
        "Pustaka Engine (RON-RS Block Tree + Typst v0.15.1, Core v{}, ACP v{})",
        pustaka_core::version(),
        pustaka_acp::version()
    )
}

#[uniffi::export]
pub fn init_engine() -> String {
    format!(
        "Pustaka Engine initialized: RON-RS & Typst Compiler Ready (v{})",
        pustaka_core::version()
    )
}

#[uniffi::export]
pub fn get_app_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_info_and_version() {
        let info = get_engine_info();
        assert!(info.contains("RON-RS"));
        assert!(info.contains("Typst"));
        assert_eq!(get_app_version(), "0.1.0");
    }

    #[test]
    fn test_ffi_pfs_to_ron_and_render_to_svg() {
        let input = ". FFI Header\n:info Live preview via UniFFI\nSwiftUI Typst rendering";
        let ron = parse_pfs_to_ron(input.to_string());
        assert!(ron.contains("FFI Header"));
        assert!(ron.contains("Live preview via UniFFI"));

        let svg = render_ron_to_svg(ron);
        assert!(svg.starts_with("<svg"));
        assert!(svg.contains("</svg>"));
    }
}
