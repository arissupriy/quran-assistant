// src/search_models.rs

use std::collections::HashMap;
use serde::{Deserialize, Serialize}; // Impor derive macros dari crate serde

/// Struktur untuk setiap kemunculan istilah dalam inverted index.
/// Ini harus sesuai dengan format yang dihasilkan oleh Python msgpack.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Occurrence {
    pub vk: String,     // Verse Key (e.g., "1:1", "114:3")
    pub pos: u16,       // Position in Verse (0-indexed)
    pub t: String,      // Term Type (1-character code: "w", "l", "r", "s", "iw", "is")
    pub tf: Option<u16>,// Term Frequency in Verse (Optional, None jika TF tidak ada atau 0)
}

/// Alias tipe untuk Inverted Index utama.
/// Key: Istilah pencarian yang dinormalisasi (String).
/// Value: Vector dari kemunculan (Vec<Occurrence>).
pub type InvertedIndex = HashMap<String, Vec<Occurrence>>;

// --- TAMBAH DEFINISI STRUCT INI: WordResult ---
/// Struktur untuk merepresentasikan detail kata dalam hasil pencarian.
/// Ini adalah versi Word dari data asli, ditambah dengan field untuk highlight.
#[derive(Debug, Serialize, Deserialize, Clone, Default)] // <-- Tambahkan Default
pub struct WordResult {
    pub id: u32,                     // ID kata dalam ayat (1-indexed dari data asli)
    pub position: u32,               // Posisi kata dalam ayat (1-indexed dari data asli)
    #[serde(rename = "textUthmani")]
    pub text_uthmani: String,        // Teks Uthmani asli kata tersebut
    #[serde(rename = "translationText")] // Nama field diubah untuk konsistensi di JSON
    // pub translation_text: String,    // Terjemahan Bahasa Indonesia untuk kata tersebut
    pub highlighted: bool,           // <-- TAMBAH INI: True jika kata ini harus disorot
    // Anda bisa menambahkan field lain dari Word asli yang relevan jika diperlukan.
    // Contoh: #[serde(rename = "charTypeName")] pub char_type_name: String,
}
// --- AKHIR DEFINISI STRUCT WordResult ---

/// Struktur untuk menyimpan hasil pencarian yang akan dikembalikan ke Dart.
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct SearchResult {
    pub verse_key: String,       // Kunci ayat (e.g., "1:1")
    pub score: f32,              // Skor relevansi pencarian
    pub words: Vec<WordResult>,  // <-- PERBAIKAN DI SINI: Gunakan Vec<WordResult>
    // pub highlighted_word_positions: Vec<u16>, // <-- Ini bisa dihapus jika `highlighted` di `WordResult` sudah cukup
}