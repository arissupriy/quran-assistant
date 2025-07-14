// src/data-loader/phrase_highlight_map.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;
use anyhow::{Result, Context, bail}; // <--- TAMBAHKAN 'Context' DI SINI

// Re-use HighlightMap from highlight_index_combined.rs
// Assuming highlight_index_combined.rs defines 'pub type HighlightMap = HashMap<String, Vec<u32>>;'.
// Jika tidak, Anda bisa mendefinisikannya di sini sebagai: pub type VerseHighlightMap = HashMap<String, Vec<u32>>;
#[path = "highlight_index_combined.rs"]
mod highlight_index_combined_types; // Pastikan Anda punya path yang benar ke file ini

pub type VerseHighlightMap = highlight_index_combined_types::HighlightMap;


// Represents the top-level structure of phrase_highlight_map.json
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default)]
pub struct PhraseHighlightMap {
    #[serde(flatten)] // Mengizinkan HashMap langsung menjadi struct root
    pub map: HashMap<String, VerseHighlightMap>, // Kunci adalah Phrase ID sebagai String
}

// Tambahkan di AKHIR FILE src/data-loader/phrase_highlight_map.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::{Result, bail};

    #[test]
    fn test_phrase_highlight_map_deserialization() -> Result<()> {
        let test_file_path = "data/phrase_highlight_map.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/phrase_highlight_map.json' ada.");

        let phrase_highlight_data: PhraseHighlightMap = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke PhraseHighlightMap. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!phrase_highlight_data.map.is_empty(), "Map PhraseHighlightMap tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci tingkat atas yang diketahui
        let key1 = "50".to_string();
        assert!(phrase_highlight_data.map.contains_key(&key1), "Map tidak mengandung kunci {}.", key1);
        if let Some(verse_map) = phrase_highlight_data.map.get(&key1) {
            assert!(!verse_map.is_empty(), "Verse map untuk {} tidak boleh kosong.", key1);
            assert!(verse_map.contains_key("19:48"), "Verse map untuk {} tidak mengandung kunci '19:48'.", key1);
            assert_eq!(verse_map["19:48"], vec![4, 5, 6], "Nilai untuk '19:48' di verse map {} tidak cocok.", key1);
        }

        let key2 = "16738".to_string();
        assert!(phrase_highlight_data.map.contains_key(&key2), "Map tidak mengandung kunci {}.", key2);
        if let Some(verse_map) = phrase_highlight_data.map.get(&key2) {
            assert!(verse_map.contains_key("6:29"), "Verse map untuk {} tidak mengandung kunci '6:29'.", key2);
            assert_eq!(verse_map["6:29"], vec![7, 8, 9], "Nilai untuk '6:29' di verse map {} tidak cocok.", key2);
        }

        // Validasi umum untuk semua entri PhraseHighlightMap
        for (phrase_id_str, verse_map) in &phrase_highlight_data.map {
            assert!(!phrase_id_str.is_empty(), "Kunci phrase ID kosong.");
            // Pastikan phrase_id_str dapat diurai sebagai u32 jika itu yang diharapkan
            let _parsed_phrase_id = phrase_id_str.parse::<u32>()
                .context(format!("Kunci phrase ID '{}' bukan angka.", phrase_id_str))?;

            assert!(!verse_map.is_empty(), "Verse map kosong untuk phrase ID {}.", phrase_id_str);
            for (verse_key, indices) in verse_map {
                assert!(!verse_key.is_empty(), "Kunci ayat kosong di verse map untuk phrase ID {}.", phrase_id_str);
                assert!(!indices.is_empty(), "Daftar indeks kosong untuk phrase ID {} dan kunci ayat {}.", phrase_id_str, verse_key);
                // Anda bisa menambahkan validasi format verse_key (e.g., "X:Y") jika diperlukan
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi phrase_highlight_map.json.");

        Ok(())
    }
}