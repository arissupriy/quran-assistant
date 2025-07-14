// src/data-loader/juzs.rs

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct Juz {
    pub id: u32,
    #[serde(rename = "juzNumber")]
    pub juz_number: u32,
    #[serde(rename = "verseMapping")]
    pub verse_mapping: HashMap<String, String>, // Misal: "1": "1-7", "2": "1-141"
    #[serde(rename = "firstVerseId")]
    pub first_verse_id: u32,
    #[serde(rename = "lastVerseId")]
    pub last_verse_id: u32,
    #[serde(rename = "versesCount")]
    pub verses_count: u32,
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct Juzs {
    // Karena juzs.json adalah array langsung dari objek Juz,
    // kita bungkus dalam sebuah struct untuk tujuan serialisasi/deserialisasi.
    pub juzs: Vec<Juz>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
#[frb]
pub struct JuzWithPage {
    pub juz: Juz,
    pub page_number: u32,
}


// Tambahkan di AKHIR FILE src/data-loader/juzs.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_juzs_deserialization() -> Result<()> {
        let test_file_path = "data/juzs.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/juzs.json' ada.");

        // Deserialisasi langsung ke Vec<Juz>
        let raw_juzs: Vec<Juz> = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke Vec<Juz>. Periksa definisi struct dan format JSON.");

        // Bungkus ke dalam struct Juzs untuk test
        let juzs_data = Juzs { juzs: raw_juzs };

        // --- Validasi Konten Dinamis ---
        assert!(!juzs_data.juzs.is_empty(), "Koleksi Juzs tidak boleh kosong.");

        // Contoh validasi: periksa Juz 1 dan Juz 2
        let juz1_entries: Vec<&Juz> = juzs_data.juzs.iter().filter(|j| j.juz_number == 1).collect();
        assert!(!juz1_entries.is_empty(), "Tidak ada entri untuk Juz 1.");
        // Anda mungkin memiliki dua entri untuk Juz 1 (id: 61 dan id: 1) berdasarkan snippet
        // Jika ada id duplikat, pastikan validasi Anda memperhitungkannya.

        if let Some(juz1_first_entry) = juz1_entries.get(0) { // Ambil entri pertama Juz 1
            assert_eq!(juz1_first_entry.juz_number, 1, "Juz Number tidak cocok untuk Juz 1.");
            assert_eq!(juz1_first_entry.first_verse_id, 1, "firstVerseId Juz 1 tidak cocok.");
            assert_eq!(juz1_first_entry.last_verse_id, 148, "lastVerseId Juz 1 tidak cocok.");
            assert_eq!(juz1_first_entry.verses_count, 148, "versesCount Juz 1 tidak cocok.");
            assert!(!juz1_first_entry.verse_mapping.is_empty(), "verseMapping Juz 1 kosong.");
            assert_eq!(juz1_first_entry.verse_mapping.get("1"), Some(&"1-7".to_string()), "verseMapping Juz 1 (1) tidak cocok.");
            assert_eq!(juz1_first_entry.verse_mapping.get("2"), Some(&"1-141".to_string()), "verseMapping Juz 1 (2) tidak cocok.");
        }

        let juz2_entries: Vec<&Juz> = juzs_data.juzs.iter().filter(|j| j.juz_number == 2).collect();
        assert!(!juz2_entries.is_empty(), "Tidak ada entri untuk Juz 2.");
        if let Some(juz2_first_entry) = juz2_entries.get(0) { // Ambil entri pertama Juz 2
            assert_eq!(juz2_first_entry.juz_number, 2, "Juz Number tidak cocok untuk Juz 2.");
            assert_eq!(juz2_first_entry.first_verse_id, 149, "firstVerseId Juz 2 tidak cocok.");
            assert_eq!(juz2_first_entry.last_verse_id, 259, "lastVerseId Juz 2 tidak cocok.");
            assert_eq!(juz2_first_entry.verses_count, 111, "versesCount Juz 2 tidak cocok.");
            assert!(!juz2_first_entry.verse_mapping.is_empty(), "verseMapping Juz 2 kosong.");
            assert_eq!(juz2_first_entry.verse_mapping.get("2"), Some(&"142-252".to_string()), "verseMapping Juz 2 (2) tidak cocok.");
        }


        // Memastikan semua Juz memiliki data yang valid
        for juz in &juzs_data.juzs {
            assert!(juz.juz_number > 0 && juz.juz_number <= 30, "juzNumber {} tidak valid (harus 1-30).", juz.juz_number);
            assert!(juz.first_verse_id > 0, "firstVerseId nol untuk Juz {}", juz.juz_number);
            assert!(juz.last_verse_id >= juz.first_verse_id, "lastVerseId lebih kecil dari firstVerseId untuk Juz {}", juz.juz_number);
            assert!(juz.verses_count > 0, "versesCount nol untuk Juz {}", juz.juz_number);
            assert!(!juz.verse_mapping.is_empty(), "verseMapping kosong untuk Juz {}", juz.juz_number);

            for (chapter_key, verse_range) in &juz.verse_mapping {
                assert!(!chapter_key.is_empty(), "Kunci bab kosong di verseMapping Juz {}", juz.juz_number);
                assert!(!verse_range.is_empty(), "Rentang ayat kosong di verseMapping Juz {} untuk bab {}", juz.juz_number, chapter_key);
                // Tambahkan validasi format "X-Y" untuk verse_range jika diperlukan (menggunakan regex)
            }
        }

        // Asersi terakhir: Memastikan jumlah total entri Juz jika Anda tahu jumlahnya (misalnya, 30 Juz, tetapi file Anda mungkin memiliki duplikat ID)
        // assert_eq!(juzs_data.juzs.len(), 30, "Jumlah total entri Juz tidak sesuai harapan."); // Sesuaikan jika ada entri duplikat ID


        println!("✅ Berhasil mendeserialisasi dan memvalidasi juzs.json.");

        Ok(())
    }
}