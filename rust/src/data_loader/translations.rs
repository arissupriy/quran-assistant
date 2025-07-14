// src/data-loader/translations.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct TranslationTextMap {
    // Karena translations_33.json adalah objek langsung (map),
    // kita gunakan #[serde(flatten)] untuk memetakannya ke dalam struct.
    #[serde(flatten)]
    pub map: HashMap<String, String>, // Kunci adalah verseKey (e.g., "1:1"), nilai adalah teks terjemahan
}

// Tambahkan di AKHIR FILE src/data-loader/translations.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_translations_deserialization() -> Result<()> {
        let test_file_path = "data/translations_33.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/translations_33.json' ada.");

        let translations: TranslationTextMap = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke TranslationTextMap. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!translations.map.is_empty(), "Map TranslationTextMap tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci ayat yang diketahui
        let verse1 = "1:1".to_string();
        assert!(translations.map.contains_key(&verse1), "Map tidak mengandung kunci ayat {}.", verse1);
        assert!(!translations.map[&verse1].is_empty(), "Teks terjemahan untuk {} kosong.", verse1);
        
        let verse_end = "114:6".to_string();
        assert!(translations.map.contains_key(&verse_end), "Map tidak mengandung kunci ayat {}.", verse_end);
        assert!(!translations.map[&verse_end].is_empty(), "Teks terjemahan untuk {} kosong.", verse_end);

        // Memastikan semua teks terjemahan tidak kosong
        for (verse_key, text) in &translations.map {
            assert!(!verse_key.is_empty(), "Kunci ayat kosong di map terjemahan.");
            assert!(!text.is_empty(), "Teks terjemahan kosong untuk kunci ayat {}.", verse_key);
            // Anda bisa menambahkan validasi format verse_key (e.g., "X:Y") jika diperlukan
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi translations_33.json.");

        Ok(())
    }
}