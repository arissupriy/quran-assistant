// src/data-loader/semantic_index_arab.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default)]
pub struct SemanticIndexArab {
    // Karena semantic_index_arab.json adalah objek langsung (map),
    // kita gunakan #[serde(flatten)] untuk memetakannya ke dalam struct.
    #[serde(flatten)]
    pub map: HashMap<String, Vec<String>>,
}

// Tambahkan di AKHIR FILE src/data-loader/semantic_index_arab.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_semantic_index_arab_deserialization() -> Result<()> {
        let test_file_path = "data/semantic_index_arab.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/semantic_index_arab.json' ada.");

        let semantic_data: SemanticIndexArab = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke SemanticIndexArab. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!semantic_data.map.is_empty(), "Map SemanticIndexArab tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci yang diketahui
        let key1 = "ثوي".to_string();
        assert!(semantic_data.map.contains_key(&key1), "Map tidak mengandung kunci {}.", key1);
        assert!(semantic_data.map[&key1].contains(&"41:24".to_string()), "Daftar kunci ayat untuk {} tidak mengandung '41:24'.", key1);

        let key2 = "قدس".to_string();
        assert!(semantic_data.map.contains_key(&key2), "Map tidak mengandung kunci {}.", key2);
        if let Some(verse_keys) = semantic_data.map.get(&key2) {
            assert!(!verse_keys.is_empty(), "Daftar kunci ayat untuk {} kosong.", key2);
            assert!(verse_keys.contains(&"5:21".to_string()), "Daftar kunci ayat untuk {} tidak mengandung '5:21'.", key2);
        }

        // Memastikan semua daftar kunci ayat tidak kosong (jika ini validasi yang Anda inginkan)
        for (semantic_key, verse_keys) in &semantic_data.map {
            // Jika Anda ingin mengizinkan daftar kosong, komentari baris ini:
            assert!(!verse_keys.is_empty(), "Daftar kunci ayat kosong untuk semantic key {}.", semantic_key);
            for vk in verse_keys {
                assert!(!vk.is_empty(), "Kunci ayat kosong di daftar untuk semantic key {}.", semantic_key);
                // Anda bisa menambahkan validasi format kunci ayat (misalnya, "X:Y") jika diperlukan (menggunakan regex)
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi semantic_index_arab.json.");

        Ok(())
    }
}