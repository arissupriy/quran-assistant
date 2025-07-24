// src/data_loader/arabic_stop_words.rs

use bincode::{Decode, Encode}; // Diperlukan untuk mendeserialisasi dari bincode
use serde::{Deserialize, Serialize}; // Diperlukan untuk derive Decode/Encode

/// Struktur untuk menampung daftar stop words Arab.
/// Ini sesuai dengan format JSON asli (array of strings).
/// Dapat di-decode oleh bincode.
#[derive(Debug, Encode, Decode, Serialize, Deserialize, Clone, Default)] // Tambahkan Decode untuk bincode
pub struct ArabicStopWords {
    pub stop_words: Vec<String>,
}