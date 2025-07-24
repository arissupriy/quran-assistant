use anyhow::{Context, Result};
use bincode::{config, Decode};
use flutter_rust_bridge::frb;
use once_cell::sync::Lazy;
use rust_embed::RustEmbed;
use std::collections::HashMap;
use std::fs::File;
use std::io::BufReader;
use std::path::{Path, PathBuf};
use zstd::stream;
use rmp_serde::from_slice;

use crate::data_loader::{
    all_verse_keys::AllVerseKeys,
    arabic_stop_words::ArabicStopWords,
    ayah_texts::AyahTexts,
    chapters::Chapters,
    juzs::Juzs,
    phrase_index::PhraseIndex,
    search_models::InvertedIndex,
    translation_metadata::TranslationMetadata,
    translations::TranslationTextMap,
    valid_matching_ayah::ValidMatchingAyah,
    verse_by_chapter::Verse,
};

// --- 🔧 Mode fallback lokal saat debug ---
#[cfg(debug_assertions)]
const USE_FILE_FALLBACK: bool = false;
#[cfg(not(debug_assertions))]
const USE_FILE_FALLBACK: bool = false;

// --- 📦 Embed semua file bin ---
#[derive(RustEmbed)]
#[folder = "data-bin-compressed/"]
#[frb(opaque)]
struct AllEmbeddedCompressedBins;

// --- 🧠 Struct global EngineData ---
pub struct EngineData {
    pub chapters: Chapters,
    pub all_verse_keys: AllVerseKeys,
    pub ayah_texts: AyahTexts,
    pub juzs: Juzs,
    pub phrase_index: PhraseIndex,
    pub translation_metadata: TranslationMetadata,
    pub translations_33: TranslationTextMap,
    pub valid_matching_ayah: ValidMatchingAyah,
    pub verses_by_chapter: HashMap<u32, Vec<Verse>>,
    pub inverted_index: InvertedIndex,
    pub arabic_stop_words: ArabicStopWords,
}

// --- 📂 Helper path saat DEV ---
fn path_in_rust_dir(filename: &str) -> PathBuf {
    Path::new("rust")
        .join("data-bin-compressed")
        .join(filename)
}

// --- 🧩 Helper DEV: file lokal ---
fn load_bin_file<T>(filename: &str) -> Result<T>
where
    T: for<'a> Decode<()> + 'static,
{
    let path = path_in_rust_dir(filename);
    log::info!("📄 Membaca bin file: {:?}", path);
    let file = File::open(&path).context(format!("❌ Tidak bisa buka file '{:?}'", path))?;
    let mut reader = BufReader::new(file);
    let decompressed_bytes = stream::decode_all(&mut reader)
        .context(format!("❌ Gagal dekompres file '{:?}'", path))?;
    let (data, _) = bincode::decode_from_slice(&decompressed_bytes, config::standard())
        .context(format!("❌ Gagal decode bincode dari '{:?}'", path))?;
    Ok(data)
}

fn load_msgpack_file<T>(filename: &str) -> Result<T>
where
    T: serde::de::DeserializeOwned,
{
    let path = path_in_rust_dir(filename);
    log::info!("📄 Membaca msgpack file: {:?}", path);
    let file = File::open(&path).context(format!("❌ Tidak bisa buka file '{:?}'", path))?;
    let mut reader = BufReader::new(file);
    let decompressed_bytes = stream::decode_all(&mut reader)
        .context(format!("❌ Gagal dekompres msgpack dari '{:?}'", path))?;
    from_slice::<T>(&decompressed_bytes)
        .context(format!("❌ Gagal deserialisasi msgpack dari '{:?}'", path))
}

// --- 📦 Helper RELEASE: dari embed ---
fn load_and_decompress_bincode_embed<T>(path: &str) -> Result<T>
where
    T: for<'a> Decode<()> + 'static,
{
    let compressed_bytes = AllEmbeddedCompressedBins::get(path)
        .context(format!("❌ File '{}' tidak ditemukan dalam embedded assets", path))?
        .data;
    let decompressed_bytes = stream::decode_all(&compressed_bytes[..])
        .context(format!("❌ Gagal mendekompresi '{}'", path))?;
    let (data, _) =
        bincode::decode_from_slice(&decompressed_bytes, config::standard())
            .context(format!("❌ Gagal deserialisasi bincode '{}'", path))?;
    Ok(data)
}

fn load_msgpack_embed<T>(path: &str) -> Result<T>
where
    T: serde::de::DeserializeOwned,
{
    let compressed = AllEmbeddedCompressedBins::get(path)
        .context(format!("❌ File '{}' tidak ditemukan dalam embed", path))?
        .data;
    let decompressed = stream::decode_all(&compressed[..])
        .context(format!("❌ Gagal dekompres '{}'", path))?;
    from_slice::<T>(&decompressed)
        .context(format!("❌ Gagal deserialisasi MessagePack '{}'", path))
}

// --- 🚀 Main Loader ---
pub fn load_all_data() -> Result<EngineData> {
    if USE_FILE_FALLBACK {
        log::warn!("🛠 [DEV] Fallback: Memuat data dari file lokal..");

        let chapters = load_bin_file("chapters.bin")?;
        let all_verse_keys = load_bin_file("all_verse_keys.bin")?;
        let ayah_texts = load_bin_file("ayah_texts.bin")?;
        let juzs = load_bin_file("juzs.bin")?;
        let phrase_index = load_bin_file("phrase_index.bin")?;
        let translation_metadata = load_bin_file("translation_metadata.bin")?;
        let translations_33 = load_bin_file("translations_33.bin")?;
        let valid_matching_ayah = load_bin_file("valid-matching-ayah.bin")?;
        let arabic_stop_words = load_bin_file("stop_words_arabic.bin")?;
        let inverted_index = load_msgpack_file("inverted_index.bin")?;

        let mut verses_by_chapter = HashMap::new();
        for i in 1..=114 {
            let path = format!("verse-by-chapter/chapter-{}.bin", i);
            let verses: Vec<Verse> = load_bin_file(&path)?;
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
    } else {
        log::info!("📦 [RELEASE] Memuat data dari embedded binary...");

        let chapters = load_and_decompress_bincode_embed("chapters.bin")?;
        let all_verse_keys = load_and_decompress_bincode_embed("all_verse_keys.bin")?;
        let ayah_texts = load_and_decompress_bincode_embed("ayah_texts.bin")?;
        let juzs = load_and_decompress_bincode_embed("juzs.bin")?;
        let phrase_index = load_and_decompress_bincode_embed("phrase_index.bin")?;
        let translation_metadata = load_and_decompress_bincode_embed("translation_metadata.bin")?;
        let translations_33 = load_and_decompress_bincode_embed("translations_33.bin")?;
        let valid_matching_ayah = load_and_decompress_bincode_embed("valid-matching-ayah.bin")?;
        let arabic_stop_words = load_and_decompress_bincode_embed("stop_words_arabic.bin")?;
        let inverted_index = load_msgpack_embed("inverted_index.bin")?;

        let mut verses_by_chapter = HashMap::new();
        for i in 1..=114 {
            let path = format!("verse-by-chapter/chapter-{}.bin", i);
            let verses: Vec<Verse> = load_and_decompress_bincode_embed(&path)?;
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
}

// --- 🧠 Global Lazy Static untuk akses lintas modul ---
pub static GLOBAL_DATA: Lazy<EngineData> =
    Lazy::new(|| load_all_data().expect("❌ Gagal memuat semua data engine!"));
