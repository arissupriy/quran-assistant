// src/data-loader/stem_index_arab.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct StemIndexArab {
    // Karena stem_index_arab.json adalah objek langsung (map),
    // kita gunakan #[serde(flatten)] untuk memetakannya ke dalam struct.
    #[serde(flatten)]
    pub map: HashMap<String, Vec<String>>,
}

// Tambahkan di AKHIR FILE src/data-loader/stem_index_arab.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_stem_index_arab_deserialization() -> Result<()> {
        let test_file_path = "data/stem_index_arab.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/stem_index_arab.json' ada.");

        let stem_data: StemIndexArab = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke StemIndexArab. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!stem_data.map.is_empty(), "Map StemIndexArab tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci yang diketahui
        let key1 = "دواير".to_string();
        assert!(stem_data.map.contains_key(&key1), "Map tidak mengandung kunci {}.", key1);
        assert_eq!(stem_data.map[&key1], vec!["9:98".to_string()], "Nilai untuk {} tidak cocok.", key1);

        let key2 = "يجزي".to_string();
        assert!(stem_data.map.contains_key(&key2), "Map tidak mengandung kunci {}.", key2);
        if let Some(verse_keys) = stem_data.map.get(&key2) {
            assert!(!verse_keys.is_empty(), "Daftar kunci ayat untuk {} kosong.", key2);
            assert!(verse_keys.contains(&"24:38".to_string()), "Daftar kunci ayat untuk {} tidak mengandung '24:38'.", key2);
        }

        // Memastikan semua daftar kunci ayat tidak kosong (jika ini validasi yang Anda inginkan)
        for (stem_key, verse_keys) in &stem_data.map {
            // Jika Anda ingin mengizinkan daftar kosong, komentari baris ini:
            assert!(!verse_keys.is_empty(), "Daftar kunci ayat kosong untuk stem key {}.", stem_key);
            for vk in verse_keys {
                assert!(!vk.is_empty(), "Kunci ayat kosong di daftar untuk stem key {}.", stem_key);
                // Anda bisa menambahkan validasi format kunci ayat (misalnya, "X:Y") jika diperlukan (menggunakan regex)
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi stem_index_arab.json.");

        Ok(())
    }
}