// src/data-loader/ayah_phrase_map.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default)]
pub struct AyahPhraseMap {
    // Kunci ayat (e.g., "19:48") dipetakan ke daftar ID frasa
    // #[serde(flatten)] // Gunakan flatten jika struct ini hanya membungkus map tanpa field lain
    pub map: HashMap<String, Vec<u32>>,
}

// Tambahkan di AKHIR FILE src/data-loader/ayah_phrase_map.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_ayah_phrase_map_deserialization() -> Result<()> {
        let test_file_path = "data/ayah_phrase_map.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/ayah_phrase_map.json' ada.");

        // Deserialisasi langsung ke HashMap<String, Vec<u32>>
        let raw_map: HashMap<String, Vec<u32>> = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke HashMap<String, Vec<u32>>. Periksa format JSON.");

        // Bungkus ke dalam struct AyahPhraseMap untuk test
        let ayah_phrase_map_data = AyahPhraseMap { map: raw_map };

        // --- Validasi Konten Dinamis ---
        assert!(!ayah_phrase_map_data.map.is_empty(), "Map AyahPhraseMap tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci ayat yang diketahui
        let key1 = "19:48".to_string();
        assert!(ayah_phrase_map_data.map.contains_key(&key1), "Map tidak mengandung kunci ayat {}.", key1);
        assert_eq!(ayah_phrase_map_data.map[&key1], vec![50, 16131, 16379], "Nilai untuk {} tidak cocok.", key1);

        let key2 = "2:23".to_string();
        assert!(ayah_phrase_map_data.map.contains_key(&key2), "Map tidak mengandung kunci ayat {}.", key2);
        assert_eq!(ayah_phrase_map_data.map[&key2], vec![50, 16379], "Nilai untuk {} tidak cocok.", key2);

        // Memastikan semua nilai (Vec<u32>) tidak kosong
        for (key, value) in &ayah_phrase_map_data.map {
            assert!(!value.is_empty(), "Nilai kosong untuk kunci ayat {}.", key);
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi ayah_phrase_map.json.");

        Ok(())
    }
}