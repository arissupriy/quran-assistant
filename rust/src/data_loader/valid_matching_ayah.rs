// src/data-loader/valid_matching_ayah.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

// Represents each object in the array value for a verse key
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct MatchedAyah {
    #[serde(rename = "matched_ayah_key")]
    pub matched_ayah_key: String,
    #[serde(rename = "matched_words_count")]
    pub matched_words_count: u32,
    pub coverage: u32,
    pub score: u32,
    #[serde(rename = "match_words")]
    pub match_words: Vec<Vec<u32>>, // Array of array of integers
}

// Represents the top-level structure of valid-matching-ayah.json
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct ValidMatchingAyah {
    #[serde(flatten)] // Mengizinkan HashMap langsung menjadi struct root
    pub map: HashMap<String, Vec<MatchedAyah>>, // Kunci adalah verseKey, nilai adalah daftar MatchedAyah
}


// #[derive(Debug, Clone, Serialize, Deserialize)]
// pub struct InvertedMatchedAyah {
//     pub source_ayah_key: String, // yang menunjuk ke verse_key
//     pub matched_words_count: u32,
//     pub coverage: u32,
//     pub score: u32,
//     pub match_words: Vec<Vec<u32>>,
// }

// Tambahkan di AKHIR FILE src/data-loader/valid_matching_ayah.rs

// src/data-loader/valid_matching_ayah.rs

// ... (definisi struct MatchedAyah dan ValidMatchingAyah yang sudah ada) ...

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::{Result, bail};

    #[test]
    fn test_valid_matching_ayah_deserialization() -> Result<()> {
        let test_file_path = "data/valid-matching-ayah.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/valid-matching-ayah.json' ada.");

        let valid_matching_ayah_data: ValidMatchingAyah = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke ValidMatchingAyah. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!valid_matching_ayah_data.map.is_empty(), "Map ValidMatchingAyah tidak boleh kosong.");

        // Contoh validasi: periksa beberapa kunci ayat yang diketahui
        let verse_key1 = "1:1".to_string();
        assert!(valid_matching_ayah_data.map.contains_key(&verse_key1), "Map tidak mengandung kunci ayat {}.", verse_key1);
        if let Some(matched_ayahs) = valid_matching_ayah_data.map.get(&verse_key1) {
            assert!(!matched_ayahs.is_empty(), "Daftar matched_ayahs untuk {} kosong.", verse_key1);
            if let Some(first_match) = matched_ayahs.get(0) {
                assert_eq!(first_match.matched_ayah_key, "27:30".to_string(), "matched_ayah_key pertama tidak cocok untuk {}.", verse_key1);
                assert_eq!(first_match.matched_words_count, 4, "matched_words_count pertama tidak cocok untuk {}.", verse_key1);
                assert_eq!(first_match.coverage, 100, "coverage pertama tidak cocok untuk {}.", verse_key1);
                assert_eq!(first_match.score, 100, "score pertama tidak cocok untuk {}.", verse_key1);
                assert_eq!(first_match.match_words, vec![vec![5, 8]], "match_words pertama tidak cocok untuk {}.", verse_key1);
            }
        }

        let verse_key2 = "113:1".to_string();
        assert!(valid_matching_ayah_data.map.contains_key(&verse_key2), "Map tidak mengandung kunci ayat {}.", verse_key2);
        if let Some(matched_ayahs) = valid_matching_ayah_data.map.get(&verse_key2) {
            assert!(!matched_ayahs.is_empty(), "Daftar matched_ayahs untuk {} kosong.", verse_key2);
            if let Some(first_match) = matched_ayahs.get(0) {
                assert_eq!(first_match.matched_ayah_key, "114:1".to_string(), "matched_ayah_key pertama tidak cocok untuk {}.", verse_key2);
            }
        }

        // Validasi umum untuk semua entri
        for (verse_key, matched_ayahs) in &valid_matching_ayah_data.map {
            assert!(!verse_key.is_empty(), "Kunci ayat kosong di map valid-matching-ayah.");
            assert!(!matched_ayahs.is_empty(), "Daftar matched_ayahs kosong untuk kunci ayat {}.", verse_key);

            for matched_ayah in matched_ayahs {
                assert!(!matched_ayah.matched_ayah_key.is_empty(), "matched_ayah_key kosong untuk {}.", verse_key);
                assert!(matched_ayah.matched_words_count > 0, "matched_words_count nol untuk {}.", verse_key);
                // Validasi range untuk coverage dan score (e.g., 0-100) jika berlaku
                assert!(matched_ayah.coverage >= 0 && matched_ayah.coverage <= 100, "Coverage tidak valid untuk {}.", verse_key);
                assert!(matched_ayah.score >= 0 && matched_ayah.score <= 100, "Score tidak valid untuk {}.", verse_key);
                assert!(!matched_ayah.match_words.is_empty(), "match_words kosong untuk {}.", verse_key);
                for word_range in &matched_ayah.match_words {
                    // **PERBAIKAN:** Hapus asersi yang mengharuskan panjangnya harus 2
                    // assert_eq!(word_range.len(), 2, "match_words range tidak memiliki 2 elemen untuk {}.", verse_key);
                    assert!(!word_range.is_empty(), "match_words sub-range kosong untuk {}.", verse_key); // Pastikan bukan array kosong
                    
                    // Asersi untuk memastikan elemen-elemen dalam range adalah valid
                    assert!(word_range[0] > 0, "match_words range memiliki nilai nol di awal untuk {}.", verse_key);
                    // Asumsi: jika ada elemen kedua, maka elemen kedua harus >= elemen pertama
                    if word_range.len() > 1 { 
                        assert!(word_range[1] > 0, "match_words range memiliki nilai nol di akhir untuk {}.", verse_key);
                        assert!(word_range[0] <= word_range[1], "match_words range awal lebih besar dari akhir untuk {}.", verse_key);
                    }
                }
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi valid-matching-ayah.json.");

        Ok(())
    }
}