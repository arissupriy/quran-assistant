// C:\PROJECT\QURAN_ASSISTANT\RUST\SRC\api\quran\similarity.rs

use flutter_rust_bridge::frb;

use crate::GLOBAL_DATA;
// Import struct yang relevan
use crate::data_loader::valid_matching_ayah::{ValidMatchingAyah, MatchedAyah}; // MatchedAyah
use crate::data_loader::ayah_phrase_map::AyahPhraseMap; // Jika digunakan di sini, dari data_loader
// use crate::data_loader::phrase_highlight_map::{PhraseHighlightMap, VerseHighlightMap}; // Jika digunakan di sini

// Catatan Penting: Pastikan struct `MatchedAyah` (dari `src/data_loader/valid_matching_ayah.rs`)
// memiliki `#[derive(Clone, serde::Serialize, serde::Deserialize, bincode::Encode, bincode::Decode)]`.
// Ini krusial agar FRB dapat meng-marshal-nya dan Rust dapat mengkloningnya.

#[frb] // Menggunakan #[frb]
pub fn get_similar_ayahs(verse_key: String) -> Vec<MatchedAyah> { // Input `String`, Output `Vec<MatchedAyah>`
    let engine_data = &GLOBAL_DATA;

    if let Some(matched_ayahs) = engine_data.valid_matching_ayah.map.get(&verse_key) {
        matched_ayahs.clone() // Kloning Vec<MatchedAyah> untuk dikembalikan
    } else {
        Vec::new() // Mengembalikan Vec kosong jika tidak ditemukan
    }
}