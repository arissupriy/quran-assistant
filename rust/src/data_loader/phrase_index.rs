// src/data-loader/phrase_index.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;
use anyhow::{Result, Context, bail}; // <--- TAMBAHKAN 'Context' DI SINI

// Represents the object under each phrase ID (e.g., "50": { ... })
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct PhraseIndexEntry {
    #[serde(rename = "phraseId")] // Memperbaiki peringatan non_snake_case
    pub phrase_id: u32,
    pub source: String,
    pub range: Vec<u32>,
    pub ayahs: HashMap<String, Vec<Vec<u32>>>, // Kunci ayat dipetakan ke daftar rentang indeks
}

// Represents the top-level structure of phrase_index.json
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct PhraseIndex {
    #[serde(flatten)] // Mengizinkan HashMap langsung menjadi struct root
    pub map: HashMap<String, PhraseIndexEntry>, // Kunci adalah Phrase ID sebagai String
}

// Tambahkan di AKHIR FILE src/data-loader/phrase_index.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::{Result, bail};

    #[test]
    fn test_phrase_index_deserialization() -> Result<()> {
        let test_file_path = "data/phrase_index.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/phrase_index.json' ada.");

        let phrase_index_data: PhraseIndex = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke PhraseIndex. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!phrase_index_data.map.is_empty(), "Map PhraseIndex tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci tingkat atas yang diketahui
        let key1 = "50".to_string();
        assert!(phrase_index_data.map.contains_key(&key1), "Map tidak mengandung kunci {}.", key1);
        if let Some(entry) = phrase_index_data.map.get(&key1) {
            assert_eq!(entry.phrase_id, 50, "phraseId tidak cocok untuk kunci {}.", key1);
            assert!(!entry.source.is_empty(), "Source kosong untuk kunci {}.", key1);
            assert_eq!(entry.range, vec![15, 17], "Range tidak cocok untuk kunci {}.", key1);
            assert!(!entry.ayahs.is_empty(), "Ayahs map kosong untuk kunci {}.", key1);
            assert!(entry.ayahs.contains_key("19:48"), "Ayahs map untuk {} tidak mengandung '19:48'.", key1);
            assert_eq!(entry.ayahs["19:48"], vec![vec![4, 6]], "Nilai untuk '19:48' di ayahs map {} tidak cocok.", key1);
        }

        let key2 = "16739".to_string();
        assert!(phrase_index_data.map.contains_key(&key2), "Map tidak mengandung kunci {}.", key2);
        if let Some(entry) = phrase_index_data.map.get(&key2) {
            assert_eq!(entry.phrase_id, 16739, "phraseId tidak cocok untuk kunci {}.", key2);
            assert_eq!(entry.source, "43:43".to_string(), "Source tidak cocok untuk kunci {}.", key2);
        }

        // Validasi umum untuk semua entri
        for (phrase_id_str, entry) in &phrase_index_data.map {
            // Pastikan phrase_id_str dapat diurai sebagai u32 dan cocok dengan entry.phrase_id
            let parsed_id = phrase_id_str.parse::<u32>()
                .context(format!("Kunci phrase ID '{}' bukan angka.", phrase_id_str))?;
            if parsed_id != entry.phrase_id {
                bail!("Kunci map ({}) tidak cocok dengan phraseId ({}) di entri.", phrase_id_str, entry.phrase_id);
            }

            assert!(!entry.source.is_empty(), "Source kosong untuk phrase ID {}.", phrase_id_str);
            assert!(!entry.range.is_empty(), "Range kosong untuk phrase ID {}.", phrase_id_str);
            assert_eq!(entry.range.len(), 2, "Range tidak memiliki 2 elemen untuk phrase ID {}.", phrase_id_str);
            assert!(!entry.ayahs.is_empty(), "Ayahs map kosong untuk phrase ID {}.", phrase_id_str);

            for (ayah_key, ranges_list) in &entry.ayahs {
                assert!(!ayah_key.is_empty(), "Kunci ayat kosong di ayahs map untuk phrase ID {}.", phrase_id_str);
                assert!(!ranges_list.is_empty(), "Daftar range kosong di ayahs map untuk phrase ID {} dan kunci ayat {}.", phrase_id_str, ayah_key);
                for range_pair in ranges_list {
                    assert_eq!(range_pair.len(), 2, "Pasangan range tidak memiliki 2 elemen untuk phrase ID {} dan kunci ayat {}.", phrase_id_str, ayah_key);
                    // Anda bisa menambahkan validasi lebih lanjut untuk nilai dalam range_pair
                }
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi phrase_index.json.");

        Ok(())
    }
}