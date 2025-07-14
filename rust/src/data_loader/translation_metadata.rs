// src/data-loader/translation_metadata.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct TranslationMetadata {
    // Karena translation_metadata.json adalah objek langsung (map),
    // kita gunakan #[serde(flatten)] untuk memetakannya ke dalam struct.
    #[serde(flatten)]
    pub map: HashMap<String, String>,
}

// Tambahkan di AKHIR FILE src/data-loader/translation_metadata.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_translation_metadata_deserialization() -> Result<()> {
        let test_file_path = "data/translation_metadata.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/translation_metadata.json' ada.");

        let metadata: TranslationMetadata = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke TranslationMetadata. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!metadata.map.is_empty(), "Map TranslationMetadata tidak boleh kosong.");

        // Contoh validasi: periksa beberapa ID terjemahan yang diketahui
        let id1 = "19".to_string();
        assert!(metadata.map.contains_key(&id1), "Map tidak mengandung ID terjemahan {}.", id1);
        assert_eq!(metadata.map[&id1], "M. Pickthall".to_string(), "Nama untuk ID terjemahan {} tidak cocok.", id1);

        let id_indo = "33".to_string();
        assert!(metadata.map.contains_key(&id_indo), "Map tidak mengandung ID terjemahan {}.", id_indo);
        assert_eq!(metadata.map[&id_indo], "Indonesian Islamic Affairs Ministry".to_string(), "Nama untuk ID terjemahan {} tidak cocok.", id_indo);

        // Memastikan semua nilai (nama penerjemah) tidak kosong
        for (id, name) in &metadata.map {
            assert!(!name.is_empty(), "Nama penerjemah kosong untuk ID {}.", id);
            // Anda bisa menambahkan validasi bahwa ID adalah angka jika diperlukan (gunakan .parse::<u32>())
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi translation_metadata.json.");

        Ok(())
    }
}