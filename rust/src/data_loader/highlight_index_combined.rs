// src/data-loader/highlight_index_combined.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

// Represents the innermost map: "41:24": [4]
pub type HighlightMap = HashMap<String, Vec<u32>>;

// Represents the object that contains "root", "stem", "lemma"
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct HighlightEntry {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub root: Option<HighlightMap>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub stem: Option<HighlightMap>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub lemma: Option<HighlightMap>,
}

// Represents the top-level structure of highlight_index_combined.json
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct HighlightIndexCombined {
    #[serde(flatten)] // Mengizinkan HashMap langsung menjadi struct root
    pub map: HashMap<String, HighlightEntry>,
}

// Tambahkan di AKHIR FILE src/data-loader/highlight_index_combined.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_highlight_index_combined_deserialization() -> Result<()> {
        let test_file_path = "data/highlight_index_combined.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/highlight_index_combined.json' ada.");

        let highlight_data: HighlightIndexCombined = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke HighlightIndexCombined. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!highlight_data.map.is_empty(), "Map HighlightIndexCombined tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci tingkat atas yang diketahui
        let key1 = "مثوى".to_string();
        assert!(highlight_data.map.contains_key(&key1), "Map tidak mengandung kunci {}.", key1);
        if let Some(entry) = highlight_data.map.get(&key1) {
            assert!(entry.root.is_some(), "Entry {} seharusnya memiliki field 'root'.", key1);
            assert!(entry.stem.is_some(), "Entry {} seharusnya memiliki field 'stem'.", key1);
            assert!(entry.lemma.is_some(), "Entry {} seharusnya memiliki field 'lemma'.", key1);
            
            // Validasi lebih dalam pada salah satu sub-map
            if let Some(root_map) = &entry.root {
                assert!(!root_map.is_empty(), "Root map untuk {} tidak boleh kosong.", key1);
                assert!(root_map.contains_key("41:24"), "Root map untuk {} tidak mengandung kunci '41:24'.", key1);
                assert_eq!(root_map["41:24"], vec![4], "Nilai untuk '41:24' di root map {} tidak cocok.", key1);
            }
        }

        let key2 = "ومنه".to_string();
        assert!(highlight_data.map.contains_key(&key2), "Map tidak mengandung kunci {}.", key2);
        if let Some(entry) = highlight_data.map.get(&key2) {
            assert!(entry.root.is_none(), "Entry {} seharusnya tidak memiliki field 'root'.", key2);
            assert!(entry.stem.is_some(), "Entry {} seharusnya memiliki field 'stem'.", key2);
        }

        // Validasi umum untuk semua entri
        for (top_key, entry) in &highlight_data.map {
            if let Some(root_map) = &entry.root {
                for (verse_key, indices) in root_map {
                    assert!(!verse_key.is_empty(), "Kunci ayat root kosong untuk {}", top_key);
                    assert!(!indices.is_empty(), "Daftar indeks root kosong untuk {}:{}", top_key, verse_key);
                }
            }
            // Ulangi untuk stem dan lemma
            if let Some(stem_map) = &entry.stem {
                for (verse_key, indices) in stem_map {
                    assert!(!verse_key.is_empty(), "Kunci ayat stem kosong untuk {}", top_key);
                    assert!(!indices.is_empty(), "Daftar indeks stem kosong untuk {}:{}", top_key, verse_key);
                }
            }
            if let Some(lemma_map) = &entry.lemma {
                for (verse_key, indices) in lemma_map {
                    assert!(!verse_key.is_empty(), "Kunci ayat lemma kosong untuk {}", top_key);
                    assert!(!indices.is_empty(), "Daftar indeks lemma kosong untuk {}:{}", top_key, verse_key);
                }
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi highlight_index_combined.json.");

        Ok(())
    }
}