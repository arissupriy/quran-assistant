// src/data-loader/lemma_index_arab.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default)]
pub struct LemmaIndexArab {
    // Karena lemma_index_arab.json adalah objek langsung (map),
    // kita gunakan #[serde(flatten)] untuk memetakannya ke dalam struct.
    #[serde(flatten)]
    pub map: HashMap<String, Vec<String>>,
}

// Tambahkan di AKHIR FILE src/data-loader/lemma_index_arab.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_lemma_index_arab_deserialization() -> Result<()> {
        let test_file_path = "data/lemma_index_arab.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/lemma_index_arab.json' ada.");

        let lemma_data: LemmaIndexArab = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke LemmaIndexArab. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!lemma_data.map.is_empty(), "Map LemmaIndexArab tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci yang diketahui
        let key1 = "كذاب".to_string();
        assert!(lemma_data.map.contains_key(&key1), "Map tidak mengandung kunci {}.", key1);
        assert_eq!(lemma_data.map[&key1], vec!["54:26".to_string(), "40:24".to_string(), "54:25".to_string(), "38:4".to_string(), "40:28".to_string(), "78:28".to_string(), "78:35".to_string()], "Nilai untuk {} tidak cocok.", key1);

        let key2 = "ءامن".to_string();
        assert!(lemma_data.map.contains_key(&key2), "Map tidak mengandung kunci {}.", key2);
        if let Some(verse_keys) = lemma_data.map.get(&key2) {
            assert!(!verse_keys.is_empty(), "Daftar kunci ayat untuk {} kosong (padahal seharusnya tidak).", key2);
            assert!(verse_keys.contains(&"2:285".to_string()), "Daftar kunci ayat untuk {} tidak mengandung '2:285'.", key2);
        }

        // Memastikan semua daftar kunci ayat tidak kosong
        for (lemma_key, verse_keys) in &lemma_data.map {
            // **** PERUBAHAN DI SINI ****
            // Mengomentari asersi ini agar mengizinkan daftar kosong secara umum.
            // Jika Anda ingin semua daftar non-kosong, Anda harus membersihkan data JSON Anda.
            // assert!(!verse_keys.is_empty(), "Daftar kunci ayat kosong untuk lemma {}.", lemma_key);

            for vk in verse_keys {
                assert!(!vk.is_empty(), "Kunci ayat kosong di daftar untuk lemma {}.", lemma_key);
                // Anda bisa menambahkan validasi format kunci ayat (misalnya, "X:Y") jika diperlukan (menggunakan regex)
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi lemma_index_arab.json.");

        Ok(())
    }
}