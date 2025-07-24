use anyhow::{Context, Result};
use bincode::{config, Decode};
use log::{debug, error, info};
use once_cell::sync::OnceCell;
use rmp_serde::from_slice;
use std::collections::HashMap;
use std::sync::RwLock;
use zstd::stream::decode_all;

use crate::data_loader::verse_by_chapter::{PageFirstVerse,  TajweedIndex, TajweedMeta, TajweedMetaMap, Translation};
use crate::data_loader::*;
use crate::data_loader::{
    all_verse_keys::AllVerseKeys, arabic_stop_words::ArabicStopWords, ayah_texts::AyahTexts,
    chapters::Chapters, juzs::Juzs, phrase_index::PhraseIndex, search_models::InvertedIndex,
    stem_index_arab::StemIndexArab, valid_matching_ayah::ValidMatchingAyah,
    verse_by_chapter::Verse,
};

#[derive(Clone)]
pub struct EngineData {
    pub chapters: Chapters,
    pub all_verse_keys: AllVerseKeys,
    pub ayah_texts: AyahTexts,
    pub juzs: Juzs,
    pub phrase_index: PhraseIndex,
    // pub translation_metadata: TranslationMetadata,
    // pub translations_33: TranslationTextMap,
    pub valid_matching_ayah: ValidMatchingAyah,
    pub arabic_stop_words: ArabicStopWords,
    pub verses: HashMap<u32, Vec<Verse>>,
    pub inverted_index: InvertedIndex,
    pub semantic_index_arab: crate::data_loader::semantic_index_arab::SemanticIndexArab,
    pub highlight_index_combined:
        crate::data_loader::highlight_index_combined::HighlightIndexCombined,
    pub phrase_highlight_map: crate::data_loader::phrase_highlight_map::PhraseHighlightMap,
    pub stem_index_arab: StemIndexArab,
    pub lemma_index_arab: crate::data_loader::lemma_index_arab::LemmaIndexArab,
    pub words: crate::data_loader::verse_by_chapter::Words,
    pub page_first_verse: PageFirstVerse,
    pub tajweed_meta: TajweedMetaMap,
    pub tajweed_index: TajweedIndex,
    pub translation: HashMap<String, Translation>,

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
        let mut writer = lock
            .write()
            .map_err(|_| anyhow::anyhow!("RwLock poisoned"))?;
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
    let mut writer = lock
        .write()
        .map_err(|_| anyhow::anyhow!("RwLock poisoned"))?;
    *writer = engine_data;
    Ok(())
}

/// Decode seluruh konten dari Flutter asset ke EngineData
fn decode_all_engine_data(map: HashMap<String, Vec<u8>>) -> Result<EngineData> {
    fn try_get<'a>(map: &'a HashMap<String, Vec<u8>>, key: &str) -> Result<&'a [u8]> {
        map.get(key)
            .map(|v| v.as_slice())
            .with_context(|| format!("Key '{}' tidak ditemukan di asset map", key))
    }

    fn decode_bin<T: for<'a> bincode::Decode<()>>(bytes: &[u8], label: &str) -> Result<T> {
        info!("⏳ Decoding binary: {}", label);
        let decompressed = decode_all(bytes).context(format!("❌ Gagal decompress '{}'", label))?;
        debug!("✅ Decompressed '{}', size: {}", label, decompressed.len());

        let (data, _) = bincode::decode_from_slice(&decompressed, config::standard())
            .context(format!("❌ Gagal decode bincode '{}'", label))?;
        info!("✅ Decoded binary '{}'", label);
        Ok(data)
    }

    fn decode_msgpack<T: serde::de::DeserializeOwned>(bytes: &[u8], label: &str) -> Result<T> {
        info!("⏳ Decoding msgpack: {}", label);
        let decompressed = decode_all(bytes).context(format!("❌ Gagal decompress '{}'", label))?;
        debug!("✅ Decompressed '{}', size: {}", label, decompressed.len());

        let data = from_slice::<T>(&decompressed)
            .context(format!("❌ Gagal decode msgpack '{}'", label))?;
        info!("✅ Decoded msgpack '{}'", label);
        Ok(data)
    }

    info!("📦 Mulai decode semua asset engine...");

    let chapters = decode_bin(try_get(&map, "chapters.bin")?, "chapters")?;
    let all_verse_keys = decode_bin(try_get(&map, "all_verse_keys.bin")?, "all_verse_keys")?;
    let ayah_texts = decode_bin(try_get(&map, "ayah_texts.bin")?, "ayah_texts")?;
    let juzs = decode_bin(try_get(&map, "juzs.bin")?, "juzs")?;
    let phrase_index = decode_bin(try_get(&map, "phrase_index.bin")?, "phrase_index")?;
    // let translation_metadata = decode_bin(
    //     try_get(&map, "translation_metadata.bin")?,
    //     "translation_metadata",
    // )?;
    // let translations_33 = decode_bin(try_get(&map, "translations_33.bin")?, "translations_33")?;
    let valid_matching_ayah = decode_bin(
        try_get(&map, "valid-matching-ayah.bin")?,
        "valid-matching-ayah",
    )?;
    let arabic_stop_words =
        decode_bin(try_get(&map, "stop_words_arabic.bin")?, "stop_words_arabic")?;
    let inverted_index = decode_msgpack(try_get(&map, "inverted_index.bin")?, "inverted_index")?;
    let semantic_index_arab = decode_bin(
        try_get(&map, "semantic_index_arab.bin")?,
        "semantic_index_arab",
    )?;
    let highlight_index_combined = decode_bin(
        try_get(&map, "highlight_index_combined.bin")?,
        "highlight_index_combined",
    )?;
    let phrase_highlight_map = decode_bin(
        try_get(&map, "phrase_highlight_map.bin")?,
        "phrase_highlight_map",
    )?;
    let stem_index_arab = decode_bin(try_get(&map, "stem_index_arab.bin")?, "stem_index_arab")?;
    let lemma_index_arab = decode_bin(try_get(&map, "lemma_index_arab.bin")?, "lemma_index_arab")?;

    let mut verses = HashMap::new();
    for i in 1..=114 {
        let key = format!("verse-by-chapter/verses-chapter-{}.bin", i);
        info!("📖 Decoding verses for chapter {}", i);
        let verses_temp: Vec<Verse> = decode_bin(&map[&key], &key)?;
        debug!("✅ Loaded chapter {} with {} verses", i, verses_temp.len());
        verses.insert(i, verses_temp);
    }

    let words = decode_bin(try_get(&map, "words.bin")?, "words")?;
    let page_first_verse = decode_bin(try_get(&map, "page_first_verse.bin")?, "page_first_verse")?;
    let tajweed_meta = decode_bin(try_get(&map, "tajweed_meta.bin")?, "tajweed_meta")?;
    let tajweed_index = decode_bin(try_get(&map, "tajweed_index.bin")?, "tajweed_index")?;
    let translation = decode_bin(try_get(&map, "translation.bin")?, "translation")?;

    info!("✅ Semua data berhasil didecode!");

    Ok(EngineData {
        chapters,
        all_verse_keys,
        ayah_texts,
        juzs,
        phrase_index,
        // translation_metadata,
        // translations_33,
        valid_matching_ayah,
        arabic_stop_words,
        verses,
        inverted_index,
        semantic_index_arab,
        highlight_index_combined,
        phrase_highlight_map,
        stem_index_arab,
        lemma_index_arab,
        words,
        page_first_verse,
        tajweed_meta,
        tajweed_index,
        translation,
    })
}
