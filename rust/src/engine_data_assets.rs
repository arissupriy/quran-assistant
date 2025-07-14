use anyhow::{Context, Result};
use bincode::{config, Decode};
use once_cell::sync::OnceCell;
use rmp_serde::from_slice;
use std::collections::HashMap;
use std::sync::RwLock;
use zstd::stream::decode_all;

use crate::data_loader::*;
use crate::data_loader::{
    all_verse_keys::AllVerseKeys, arabic_stop_words::ArabicStopWords, ayah_texts::AyahTexts,
    chapters::Chapters, juzs::Juzs, phrase_index::PhraseIndex, search_models::InvertedIndex,
    translation_metadata::TranslationMetadata, translations::TranslationTextMap,
    valid_matching_ayah::ValidMatchingAyah, verse_by_chapter::Verse,
};

#[derive(Clone)]
pub struct EngineData {
    pub chapters: Chapters,
    pub all_verse_keys: AllVerseKeys,
    pub ayah_texts: AyahTexts,
    pub juzs: Juzs,
    pub phrase_index: PhraseIndex,
    pub translation_metadata: TranslationMetadata,
    pub translations_33: TranslationTextMap,
    pub valid_matching_ayah: ValidMatchingAyah,
    pub arabic_stop_words: ArabicStopWords,
    pub verses_by_chapter: HashMap<u32, Vec<Verse>>,
    pub inverted_index: InvertedIndex,
}

/// Global container yang bisa dibaca & ditulis (reset)
static ENGINE_DATA_ASSETS: OnceCell<RwLock<EngineData>> = OnceCell::new();

/// Digunakan untuk akses global seperti GLOBAL_DATA.clone()
pub fn get_engine_data() -> Result<EngineData> {
    Ok(ENGINE_DATA_ASSETS
        .get()
        .ok_or_else(|| anyhow::anyhow!("ENGINE_DATA belum pernah di-load"))?
        .read()
        .map_err(|_| anyhow::anyhow!("RwLock poisoned"))?
        .clone())
}

/// Load pertama kali atau update jika sudah ada
pub fn load_all_engine_data_from_assets(map: HashMap<String, Vec<u8>>) -> Result<()> {
    let engine_data = decode_all_engine_data(map)?;

    if let Some(lock) = ENGINE_DATA_ASSETS.get() {
        // Sudah pernah di-set, lakukan update
        let mut writer = lock.write().map_err(|_| anyhow::anyhow!("RwLock poisoned"))?;
        *writer = engine_data;
    } else {
        // Belum pernah di-set, lakukan inisialisasi
        ENGINE_DATA_ASSETS
            .set(RwLock::new(engine_data))
            .map_err(|_| anyhow::anyhow!("Gagal set ENGINE_DATA_ASSETS"))?;
    }

    Ok(())
}

/// Reset paksa engine dengan data baru.
/// Akan gagal jika belum pernah di-load sebelumnya.
pub fn reset_engine_data(map: HashMap<String, Vec<u8>>) -> Result<()> {
    let engine_data = decode_all_engine_data(map)?;
    let lock = ENGINE_DATA_ASSETS
        .get()
        .ok_or_else(|| anyhow::anyhow!("ENGINE_DATA belum pernah di-load"))?;
    let mut writer = lock.write().map_err(|_| anyhow::anyhow!("RwLock poisoned"))?;
    *writer = engine_data;
    Ok(())
}

/// Decode seluruh konten dari Flutter asset ke EngineData
fn decode_all_engine_data(map: HashMap<String, Vec<u8>>) -> Result<EngineData> {
    fn decode_bin<T: for<'a> Decode<()>>(bytes: &[u8], label: &str) -> Result<T> {
        let decompressed = decode_all(bytes).context(format!("Gagal decompress '{}'", label))?;
        let (data, _) = bincode::decode_from_slice(&decompressed, config::standard())
            .context(format!("Gagal decode bincode '{}'", label))?;
        Ok(data)
    }

    fn decode_msgpack<T: serde::de::DeserializeOwned>(bytes: &[u8], label: &str) -> Result<T> {
        let decompressed = decode_all(bytes).context(format!("Gagal decompress '{}'", label))?;
        from_slice::<T>(&decompressed).context(format!("Gagal decode msgpack '{}'", label))
    }

    let chapters = decode_bin(&map["chapters.bin"], "chapters")?;
    let all_verse_keys = decode_bin(&map["all_verse_keys.bin"], "all_verse_keys")?;
    let ayah_texts = decode_bin(&map["ayah_texts.bin"], "ayah_texts")?;
    let juzs = decode_bin(&map["juzs.bin"], "juzs")?;
    let phrase_index = decode_bin(&map["phrase_index.bin"], "phrase_index")?;
    let translation_metadata = decode_bin(&map["translation_metadata.bin"], "translation_metadata")?;
    let translations_33 = decode_bin(&map["translations_33.bin"], "translations_33")?;
    let valid_matching_ayah = decode_bin(&map["valid-matching-ayah.bin"], "valid-matching-ayah")?;
    let arabic_stop_words = decode_bin(&map["stop_words_arabic.bin"], "stop_words_arabic")?;
    let inverted_index = decode_msgpack(&map["inverted_index.bin"], "inverted_index")?;

    let mut verses_by_chapter = HashMap::new();
    for i in 1..=114 {
        let key = format!("verse-by-chapter/chapter-{}.bin", i);
        let verses: Vec<Verse> = decode_bin(&map[&key], &key)?;
        verses_by_chapter.insert(i, verses);
    }

    Ok(EngineData {
        chapters,
        all_verse_keys,
        ayah_texts,
        juzs,
        phrase_index,
        translation_metadata,
        translations_33,
        valid_matching_ayah,
        arabic_stop_words,
        verses_by_chapter,
        inverted_index,
    })
}
