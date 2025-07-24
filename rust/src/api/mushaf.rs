use flutter_rust_bridge::frb;
use std::fs::File;
use std::io::{Read, Cursor};
use std::sync::Mutex;
use once_cell::sync::Lazy;
use anyhow::{Result, Context};

use zstd::stream::read::Decoder;
use bincode::config;
use crate::models::{MushafPackIndex, GlyphPosition};

pub static PACK_STATE: Lazy<Mutex<Option<MushafBundle>>> = Lazy::new(|| Mutex::new(None));

pub struct MushafBundle {
    pub index: MushafPackIndex,
    pub images_blob: Vec<u8>,
}

#[frb]
pub fn open_mushaf_pack(path: String) -> Result<bool> {
    let mut file = File::open(&path).context("Gagal membuka mushaf.pack")?;
    let mut compressed = Vec::new();
    file.read_to_end(&mut compressed)?;

    let mut decoder = Decoder::new(Cursor::new(compressed))?;

    let mut index_len_bytes = [0u8; 8];
    decoder.read_exact(&mut index_len_bytes)?;
    let index_len = u64::from_le_bytes(index_len_bytes) as usize;

    let mut index_buf = vec![0u8; index_len];
    decoder.read_exact(&mut index_buf)?;
    let config = config::standard();
    let (index, _) = bincode::decode_from_slice::<MushafPackIndex, _>(&index_buf, config)?;

    let mut images_blob = Vec::new();
    decoder.read_to_end(&mut images_blob)?;

    let bundle = MushafBundle { index, images_blob };
    let mut state = PACK_STATE.lock().unwrap();
    *state = Some(bundle);

    Ok(true)
}

#[frb]
pub fn get_page_image(page: u16) -> Option<Vec<u8>> {
    let state = PACK_STATE.lock().ok()?;
    let bundle = state.as_ref()?;

    let entry = bundle.index.pages.get(&page)?;
    let start = entry.offset as usize;
    let end = start + entry.size as usize;

    if end > bundle.images_blob.len() {
        return None;
    }

    Some(bundle.images_blob[start..end].to_vec())
}

#[frb]
pub fn get_page_metadata(page: u16) -> Option<Vec<GlyphPosition>> {
    let state = PACK_STATE.lock().ok()?;
    let bundle = state.as_ref()?;

    let entry = bundle.index.pages.get(&page)?;
    Some(entry.glyphs.clone())
}
