// src/data-loader/page_layout.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};
use std::collections::HashMap;

// Struct untuk data kata dalam baris. Tidak ada perubahan di sini.
#[derive(Debug, Serialize, Deserialize, Encode, Decode)]
pub struct WordData {
    #[serde(rename = "textUthmani")]
    pub text_uthmani: String,
    #[serde(rename = "verseKey")]
    pub verse_key: String,
    pub position: u32,
}

// Enum untuk berbagai jenis baris dalam tata letak halaman
// PERBAIKAN UTAMA ADA DI SINI: Menambahkan lineNumber dan field opsional
#[derive(Debug, Serialize, Deserialize, Encode, Decode)]
#[serde(tag = "type")] // Menggunakan field "type" di JSON untuk menentukan varian enum
pub enum Line {
    #[serde(rename = "surah_name")]
    SurahName {
        #[serde(rename = "lineNumber")]
        line_number: u32,
        #[serde(rename = "chapterId")]
        chapter_id: u32,
    },
    #[serde(rename = "basmallah")]
    Basmallah {
        #[serde(rename = "lineNumber")]
        line_number: u32,
        // Gunakan `default` untuk menangani kasus jika "words" tidak ada
        #[serde(default)]
        words: Vec<WordData>,
    },
    #[serde(rename = "ayah")]
    Ayah {
        #[serde(rename = "lineNumber")]
        line_number: u32,
        #[serde(default)]
        words: Vec<WordData>,
    },
}

// Struct untuk tata letak satu halaman. Tidak ada perubahan di sini.
#[derive(Debug, Serialize, Deserialize, Encode, Decode)]
pub struct PageLayout {
    pub page: u32,
    pub is_centered: bool,
    pub lines: Vec<Line>,
}

// Struct pembungkus untuk seluruh data page layout. Tidak ada perubahan di sini.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default)]
pub struct PageLayouts {
    #[serde(flatten)] // Mengizinkan HashMap langsung menjadi struct root
    pub map: HashMap<String, PageLayout>, // Kunci adalah nomor halaman sebagai String
}

// Tambahkan di AKHIR FILE src/data-loader/page_layout.rs
// src/data-loader/page_layout.rs

// ... (kode struct dan enum Anda di bagian atas tetap sama) ...

// --- PERBAIKAN PADA UNIT TEST ---
#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::{Result, Context}; // Tidak perlu bail jika menggunakan assert!

    #[test]
    fn test_page_layout_deserialization() -> Result<()> {
        let test_file_path = "data/page_layout_flutter_with_center.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/page_layout_flutter_with_center.json' ada.");

        let page_layout_data: PageLayouts = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke PageLayouts. Periksa definisi struct dan format JSON.");

        // --- Validasi Konten Dinamis ---
        assert!(!page_layout_data.map.is_empty(), "Map PageLayouts tidak boleh kosong.");

        // Contoh validasi: periksa halaman 1
        let page_key_1 = "1".to_string();
        let page_1 = page_layout_data.map.get(&page_key_1)
            .expect(&format!("Map tidak mengandung halaman {}", page_key_1));
        
        assert_eq!(page_1.page, 1, "Nomor halaman tidak cocok untuk kunci {}.", page_key_1);
        assert!(!page_1.lines.is_empty(), "Halaman {} tidak memiliki baris.", page_key_1);

        // Validasi baris-baris spesifik di halaman 1
        // Baris 1: SurahName
        let first_line = page_1.lines.get(0).expect("Baris pertama tidak ada.");
        match first_line {
            Line::SurahName { line_number, chapter_id } => {
                assert_eq!(*line_number, 1, "lineNumber untuk SurahName tidak cocok.");
                assert_eq!(*chapter_id, 1, "Chapter ID SurahName tidak cocok.");
            },
            _ => panic!("Baris pertama halaman 1 seharusnya bertipe SurahName."),
        }

        // Baris 2: Basmallah
        let basmallah_line = page_1.lines.get(1).expect("Baris kedua tidak ada.");
        match basmallah_line {
            Line::Basmallah { line_number, words } => {
                assert_eq!(*line_number, 2, "lineNumber untuk Basmallah tidak cocok.");
                assert!(!words.is_empty(), "Baris Basmallah kosong.");
                assert_eq!(words[0].text_uthmani, "بِسْمِ".to_string(), "Kata pertama Basmallah tidak cocok.");
            },
            _ => panic!("Baris kedua halaman 1 seharusnya bertipe Basmallah."),
        }
        
        // Baris 3: Ayah
        let ayah_line = page_1.lines.get(2).expect("Baris ketiga tidak ada.");
        match ayah_line {
            Line::Ayah { line_number, words } => {
                assert_eq!(*line_number, 3, "lineNumber untuk Ayah pertama tidak cocok.");
                 assert!(!words.is_empty(), "Baris Ayah kosong.");
                assert_eq!(words[0].text_uthmani, "ٱلْحَمْدُ".to_string(), "Kata pertama di baris Ayah tidak cocok.");
            },
            _ => panic!("Baris ketiga halaman 1 seharusnya bertipe Ayah."),
        }

        // Validasi umum untuk semua halaman dan baris
        for (page_key, page_layout) in &page_layout_data.map {
            let parsed_page_num = page_key.parse::<u32>().context(format!("Kunci halaman '{}' bukan angka.", page_key))?;
            assert_eq!(page_layout.page, parsed_page_num, "Nomor halaman tidak konsisten dengan kunci.");

            for line in &page_layout.lines {
                match line {
                    Line::SurahName { line_number, chapter_id } => {
                        assert!(*line_number > 0, "lineNumber SurahName tidak valid.");
                        assert!(*chapter_id > 0 && *chapter_id <= 114, "Chapter ID SurahName tidak valid.");
                    },
                    Line::Basmallah { line_number, words } | Line::Ayah { line_number, words } => {
                        assert!(*line_number > 0, "lineNumber tidak valid untuk tipe {:?}.", line);
                        for word_data in words {
                            assert!(!word_data.text_uthmani.is_empty(), "textUthmani kosong.");
                            assert!(!word_data.verse_key.is_empty(), "verseKey kosong.");
                            assert!(word_data.position > 0, "Posisi kata tidak valid.");
                        }
                    },
                }
            }
        }

        println!("✅ Berhasil mendeserialisasi dan memvalidasi page_layout_flutter_with_center.json.");

        Ok(())
    }
}