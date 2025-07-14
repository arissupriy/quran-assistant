// src/engine_data_loader.rs

// Import crate yang diperlukan
use anyhow::{Context, Result};
use bincode::{config, Decode};
use rust_embed::RustEmbed;
use std::collections::HashMap;
use zstd::stream;
// TAMBAHAN: Import rmp_serde untuk deserialisasi MessagePack dari memori
use rmp_serde::from_slice;

// Import semua struct data dari modul data_loader
use crate::data_loader::all_verse_keys::AllVerseKeys;
use crate::data_loader::arabic_stop_words::ArabicStopWords;
use crate::data_loader::ayah_phrase_map::AyahPhraseMap;
use crate::data_loader::ayah_texts::{AyahText, AyahTexts};
use crate::data_loader::chapters::{Chapter, Chapters};
use crate::data_loader::highlight_index_combined::{
    HighlightEntry, HighlightIndexCombined, HighlightMap,
};
use crate::data_loader::juzs::{Juz, Juzs};
use crate::data_loader::lemma_index_arab::LemmaIndexArab;
use crate::data_loader::page_layout::{Line, PageLayout, PageLayouts, WordData};
use crate::data_loader::phrase_highlight_map::PhraseHighlightMap;
use crate::data_loader::phrase_index::{PhraseIndex, PhraseIndexEntry};
// Import tipe data InvertedIndex dari search_models
use crate::data_loader::search_models::InvertedIndex;
use crate::data_loader::semantic_index_arab::SemanticIndexArab;
use crate::data_loader::stem_index_arab::StemIndexArab;
use crate::data_loader::translation_metadata::TranslationMetadata;
use crate::data_loader::translations::TranslationTextMap;
use crate::data_loader::valid_matching_ayah::{MatchedAyah, ValidMatchingAyah};
use crate::data_loader::verse_by_chapter::Verse;

// Meng-embed SEMUA file .bin di direktori yang ditentukan
#[derive(RustEmbed)]
#[folder = "data-bin-compressed/"]
struct AllEmbeddedCompressedBins;

// Struct untuk menampung semua data yang dimuat ke memori
pub struct EngineData {
    pub chapters: Chapters,
    pub all_verse_keys: AllVerseKeys,
    pub ayah_phrase_map: AyahPhraseMap,
    pub ayah_texts: AyahTexts,
    pub highlight_index_combined: HighlightIndexCombined,
    pub juzs: Juzs,
    pub lemma_index_arab: LemmaIndexArab,
    pub page_layout: PageLayouts,
    pub phrase_highlight_map: PhraseHighlightMap,
    pub phrase_index: PhraseIndex,
    pub semantic_index_arab: SemanticIndexArab,
    pub stem_index_arab: StemIndexArab,
    pub translation_metadata: TranslationMetadata,
    pub translations_33: TranslationTextMap,
    pub valid_matching_ayah: ValidMatchingAyah,
    pub verses_by_chapter: HashMap<u32, Vec<Verse>>,
    pub inverted_index: InvertedIndex,
    pub arabic_stop_words: ArabicStopWords,
}

// Fungsi utama untuk memuat semua data dari embedded binaries
pub fn load_all_data() -> Result<EngineData> {
    log::info!("Memulai inisialisasi data engine dari embedded binaries...");

    // Helper untuk memuat dan mendekompilasi satu file bincode+zstd
    fn load_and_decompress<T>(path: &str) -> Result<T>
    where
        T: for<'a> Decode<()> + 'static,
    {
        log::info!("Memuat (bincode+zstd): '{}'...", path);
        let compressed_bytes = AllEmbeddedCompressedBins::get(path)
            .context(format!("File '{}' tidak ditemukan dalam embedded assets", path))?
            .data;
        let decompressed_bytes = stream::decode_all(&compressed_bytes[..])
            .context(format!("Gagal mendekompresi '{}'", path))?;
        let (data, _): (T, _) =
            bincode::decode_from_slice(&decompressed_bytes, config::standard())
                .context(format!("Gagal deserialisasi bincode untuk '{}'", path))?;
        log::info!("Sukses memuat: '{}'", path);
        Ok(data)
    }

    // --- Memuat semua file .bin yang menggunakan bincode+zstd ---
    let chapters: Chapters = load_and_decompress("chapters.bin")?;
    let all_verse_keys: AllVerseKeys = load_and_decompress("all_verse_keys.bin")?;
    let ayah_phrase_map: AyahPhraseMap = load_and_decompress("ayah_phrase_map.bin")?;
    let ayah_texts: AyahTexts = load_and_decompress("ayah_texts.bin")?;
    let highlight_index_combined: HighlightIndexCombined =
        load_and_decompress("highlight_index_combined.bin")?;
    let juzs: Juzs = load_and_decompress("juzs.bin")?;
    let lemma_index_arab: LemmaIndexArab = load_and_decompress("lemma_index_arab.bin")?;
    let page_layout: PageLayouts = load_and_decompress("page_layout_flutter_with_center.bin")?;
    let phrase_highlight_map: PhraseHighlightMap =
        load_and_decompress("phrase_highlight_map.bin")?;
    let phrase_index: PhraseIndex = load_and_decompress("phrase_index.bin")?;
    let semantic_index_arab: SemanticIndexArab = load_and_decompress("semantic_index_arab.bin")?;
    let stem_index_arab: StemIndexArab = load_and_decompress("stem_index_arab.bin")?;
    let translation_metadata: TranslationMetadata =
        load_and_decompress("translation_metadata.bin")?;
    let translations_33: TranslationTextMap = load_and_decompress("translations_33.bin")?;
    let valid_matching_ayah: ValidMatchingAyah = load_and_decompress("valid-matching-ayah.bin")?;
    let arabic_stop_words: ArabicStopWords = load_and_decompress("stop_words_arabic.bin")?;

    // --- PERBAIKAN: Memuat Inverted Index (msgpack) dari data yang sudah di-embed ---
    let inverted_index: InvertedIndex = {
        let path = "inverted_index.bin";
        log::info!("Memuat (msgpack): '{}'...", path);
        
        let embedded_file = AllEmbeddedCompressedBins::get(path)
            .context(format!("KRITIS: File '{}' tidak ditemukan dalam embedded assets saat kompilasi.", path))?;
        
        let file_bytes = embedded_file.data;
        log::info!("'{}' ditemukan dalam embed, ukuran: {} bytes.", path, file_bytes.len());

        // Deserialisasi dari slice byte dan tangani error dengan logging
        from_slice::<InvertedIndex>(&file_bytes).map_err(|e| {
            log::error!("KRITIS: Gagal deserialisasi '{}' dari format MessagePack: {:?}", path, e);
            e // Kembalikan error asli
        }).context(format!("Gagal mem-parse '{}' yang di-embed", path))?
    };
    log::info!("Sukses memuat: 'inverted_index.bin'. Jumlah istilah unik: {}", inverted_index.len());


    // --- Memuat data verse-by-chapter ---
    log::info!("Memuat semua data chapter (1-114)...");
    let mut verses_by_chapter_map = HashMap::new();
    for i in 1..=114 {
        let file_name = format!("verse-by-chapter/chapter-{}.bin", i);
        let verses: Vec<Verse> = load_and_decompress(&file_name)?;
        verses_by_chapter_map.insert(i, verses);
    }
    log::info!("Semua file chapter-X.bin berhasil dimuat.");
    log::info!("INISIALISASI ENGINE BERHASIL: Semua data telah dimuat ke memori.");

    // Mengembalikan struct EngineData yang lengkap
    Ok(EngineData {
        chapters,
        all_verse_keys,
        ayah_phrase_map,
        ayah_texts,
        highlight_index_combined,
        juzs,
        lemma_index_arab,
        page_layout,
        phrase_highlight_map,
        phrase_index,
        semantic_index_arab,
        stem_index_arab,
        translation_metadata,
        translations_33,
        valid_matching_ayah,
        arabic_stop_words,
        verses_by_chapter: verses_by_chapter_map,
        inverted_index,
    })
}