use bincode::{Decode, Encode};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug, Encode, Decode)]
pub struct MushafPackIndex {
    pub pages: HashMap<u16, PageEntry>,
}

#[derive(Serialize, Deserialize, Debug, Encode, Decode, Clone)]
pub struct PageEntry {
    pub offset: u64,
    pub size: u32,
    pub glyphs: Vec<GlyphPosition>,
}

#[derive(Serialize, Deserialize, Debug, Encode, Decode, Clone)]
pub struct GlyphPosition {
    pub glyph_id: u32,
    pub page_number: u16,
    pub line_number: u8,
    pub sura: u16,
    pub ayah: u16,
    pub word_position: u16,
    pub min_x: u32,
    pub max_x: u32,
    pub min_y: u32,
    pub max_y: u32,
}
