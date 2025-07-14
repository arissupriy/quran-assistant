use anyhow::{Context, Result};
use bincode::config;
use bincode::{Decode, Encode};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::File;
use std::io::Read;
use zstd::stream::read::Decoder;

#[derive(Serialize, Deserialize, Debug, Encode, Decode, Clone)]
pub struct MushafPackIndex {
    pub pages: HashMap<u16, MushafPageEntry>,
}

#[derive(Serialize, Deserialize, Debug, Encode, Decode, Clone)]
pub struct MushafPageEntry {
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

impl MushafPackIndex {
    pub fn load(path: &str) -> Result<(Self, Vec<u8>)> {
        let mut file = File::open(path).context("❌ Gagal membuka file mushafpack")?;
        let mut decoder = Decoder::new(&mut file).context("❌ Gagal dekompresi Zstd")?;
        let mut decoded_data = vec![];
        decoder.read_to_end(&mut decoded_data)?;

        if decoded_data.len() < 8 {
            anyhow::bail!("❌ File tidak valid: kurang dari 8 byte");
        }

        let index_len = u64::from_le_bytes(decoded_data[0..8].try_into().unwrap()) as usize;

        let config = config::standard();
        let (index, _) = bincode::decode_from_slice(&decoded_data[8..8 + index_len], config)
            .context("❌ Gagal decode MushafPackIndex")?;

        let blob = decoded_data[8 + index_len..].to_vec();
        Ok((index, blob))
    }

    pub fn get_page_with_glyphs(
        &self,
        blob: &[u8],
        page: u16,
    ) -> Result<(Vec<u8>, Vec<GlyphPosition>)> {
        if let Some(entry) = self.pages.get(&page) {
            let start = entry.offset as usize;
            let end = start + entry.size as usize;
            let image = blob[start..end].to_vec();
            Ok((image, entry.glyphs.clone()))
        } else {
            anyhow::bail!("❌ Halaman {} tidak ditemukan", page);
        }
    }

    pub fn load_from_bytes(data: &[u8]) -> Result<(Self, Vec<u8>)> {
        if data.len() < 8 {
            anyhow::bail!("❌ File tidak valid: kurang dari 8 byte");
        }

        let index_len = u64::from_le_bytes(data[0..8].try_into().unwrap()) as usize;

        let config = bincode::config::standard();
        let (index, _) = bincode::decode_from_slice(&data[8..8 + index_len], config)
            .context("❌ Gagal decode MushafPackIndex")?;

        let blob = data[8 + index_len..].to_vec();
        Ok((index, blob))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn dummy_glyph() -> GlyphPosition {
        GlyphPosition {
            glyph_id: 123,
            page_number: 1,
            line_number: 2,
            sura: 3,
            ayah: 4,
            word_position: 5,
            min_x: 10,
            max_x: 20,
            min_y: 30,
            max_y: 40,
        }
    }

    fn dummy_index_and_blob() -> (MushafPackIndex, Vec<u8>) {
        // Buat entry halaman dengan gambar dummy (array byte)
        let mut pages = HashMap::new();
        let glyphs = vec![dummy_glyph()];
        let image_data = vec![0u8, 1, 2, 3, 4, 5, 6, 7, 8, 9]; // contoh gambar 10 byte

        // Simulasi offset 0, size 10 (panjang image_data)
        pages.insert(
            1,
            MushafPageEntry {
                offset: 0,
                size: image_data.len() as u32,
                glyphs: glyphs.clone(),
            },
        );

        let blob = image_data.clone();

        let index = MushafPackIndex { pages };
        (index, blob)
    }

    #[test]
    fn test_get_page_with_glyphs_success() {
        let (index, blob) = dummy_index_and_blob();

        let (image, glyphs) = index.get_page_with_glyphs(&blob, 1).unwrap();

        assert_eq!(image, vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
        assert_eq!(glyphs.len(), 1);
        assert_eq!(glyphs[0].glyph_id, 123);
        assert_eq!(glyphs[0].page_number, 1);
    }

    #[test]
    fn test_get_page_with_glyphs_page_not_found() {
        let (index, blob) = dummy_index_and_blob();

        let res = index.get_page_with_glyphs(&blob, 99);

        assert!(res.is_err());
        assert_eq!(
            res.unwrap_err().to_string(),
            "❌ Halaman 99 tidak ditemukan"
        );
    }

    // Test load bisa dibuat jika kamu sediakan file dummy .mushafpack
    // #[test]
    // fn test_load_from_file() {
    //     let path = "tests/dummy.mushafpack";
    //     let res = MushafPackIndex::load(path);
    //     assert!(res.is_ok());
    // }

    #[test]
    fn test_load_from_file() {
        let path = "dummy/madani-1080.mushafpack";
        let res = MushafPackIndex::load(path);
        assert!(res.is_ok(), "Gagal load file mushafpack: {:?}", res.err());

        let (index, blob) = res.unwrap();
        // Contoh cek halaman tertentu ada di index
        assert!(
            index.pages.contains_key(&1),
            "Halaman 1 tidak ditemukan di index"
        );
        // Contoh cek blob tidak kosong
        assert!(!blob.is_empty(), "Blob kosong setelah load file");
    }
}
