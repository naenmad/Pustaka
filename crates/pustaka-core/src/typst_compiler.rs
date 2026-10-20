use typst::LibraryExt;
use typst::diag::{FileError, FileResult};
use typst::foundations::{Bytes, Datetime, Duration};
use typst::syntax::{FileId, RootedPath, Source, VirtualPath, VirtualRoot};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst::{Library, World};
use typst_layout::PagedDocument;
use typst_svg::SvgOptions;

pub struct InMemoryWorld {
    library: LazyHash<Library>,
    book: LazyHash<FontBook>,
    fonts: Vec<Font>,
    source: Source,
    main_id: FileId,
}

impl InMemoryWorld {
    pub fn new(source_code: &str) -> Self {
        let fonts: Vec<Font> = typst_assets::fonts()
            .flat_map(|data| Font::iter(Bytes::new(data)))
            .collect();

        let book = FontBook::from_fonts(&fonts);
        let vpath = VirtualPath::new("main.typ").unwrap();
        let rooted = RootedPath::new(VirtualRoot::Project, vpath);
        let main_id = FileId::new(rooted);
        let source = Source::new(main_id, source_code.to_string());

        Self {
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(book),
            fonts,
            source,
            main_id,
        }
    }
}

impl World for InMemoryWorld {
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    fn main(&self) -> FileId {
        self.main_id
    }

    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.main_id {
            Ok(self.source.clone())
        } else {
            Err(FileError::NotFound(id.vpath().get_without_slash().into()))
        }
    }

    fn file(&self, id: FileId) -> FileResult<Bytes> {
        Err(FileError::NotFound(id.vpath().get_without_slash().into()))
    }

    fn font(&self, index: usize) -> Option<Font> {
        self.fonts.get(index).cloned()
    }

    fn today(&self, _offset: Option<Duration>) -> Option<Datetime> {
        Some(Datetime::from_ymd(2026, 1, 1).unwrap())
    }
}

pub fn compile_typst_to_svg(typst_code: &str) -> Result<String, String> {
    let world = InMemoryWorld::new(typst_code);
    let output = typst::compile::<PagedDocument>(&world);
    match output.output {
        Ok(document) => {
            if document.pages().is_empty() {
                return Err("Document produced no pages".to_string());
            }
            let svg = typst_svg::svg(&document.pages()[0], &SvgOptions::default());
            Ok(svg)
        }
        Err(diags) => {
            let err_msgs: Vec<String> = diags.iter().map(|d| d.message.to_string()).collect();
            Err(err_msgs.join("; "))
        }
    }
}
