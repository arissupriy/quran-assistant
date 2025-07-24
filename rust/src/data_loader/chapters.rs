// src/data-loader/chapter.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct Chapter {
    pub id: u32,
    #[serde(rename = "revelationPlace")]
    pub revelation_place: String,
    #[serde(rename = "revelationOrder")]
    pub revelation_order: u32,
    #[serde(rename = "bismillahPre")]
    pub bismillah_pre: bool,
    #[serde(rename = "nameSimple")]
    pub name_simple: String,
    #[serde(rename = "nameComplex")]
    pub name_complex: String,
    #[serde(rename = "nameArabic")]
    pub name_arabic: String,
    #[serde(rename = "versesCount")]
    pub verses_count: u32,
    pub pages: Vec<u32>,
    #[serde(rename = "translatedName")]
    pub translated_name: TranslatedName,
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct TranslatedName {
    #[serde(rename = "languageName")]
    pub language_name: String,
    pub name: String,
}

// --- TAMBAHKAN DEFINISI STRUCT INI ---
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct Chapters {
    // Ini akan memetakan array JSON tingkat atas ke dalam sebuah field
    // Ketika chapters.json dideserialisasi ke Vec<Chapter> di konverter,
    // kita akan membungkusnya ke dalam struct Chapters ini.
    // #[serde(flatten)] // Tidak diperlukan karena kita membungkus Vec<Chapter> secara manual di konverter
    pub chapters: Vec<Chapter>,
}


#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk (struct Anda)
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_chapter_deserialization() -> Result<()> {
        // Definisikan path ke file JSON contoh.
        let test_file_path = "data/chapters.json";

        // Baca konten file JSON test
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/chapters.json' ada.");

        // Coba untuk mendeserialisasi konten JSON ke Vec<Chapter>
        // Note: Kita mendeserialisasi ke Vec<Chapter> dulu, lalu bisa membungkusnya ke Chapters
        let chapters_vec: Vec<Chapter> = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke Vec<Chapter>. Periksa definisi struct dan format JSON.");

        // Bungkus Vec<Chapter> ke dalam struct Chapters untuk test
        let chapters_data = Chapters { chapters: chapters_vec };

        // Asersi untuk memastikan integritas data dan format.
        assert!(!chapters_data.chapters.is_empty(), "Vektor bab yang dideserialisasi tidak boleh kosong.");

        // Asersi bahwa bab tertentu (misalnya, yang pertama) memiliki data yang diharapkan
        if let Some(first_chapter) = chapters_data.chapters.get(0) {
            assert_eq!(first_chapter.id, 1, "ID bab pertama tidak cocok.");
            assert_eq!(first_chapter.name_simple, "Al-Fatihah", "Nama sederhana bab pertama tidak cocok.");
            assert_eq!(first_chapter.revelation_place, "makkah", "Tempat wahyu bab pertama tidak cocok.");
            assert_eq!(first_chapter.verses_count, 7, "Jumlah ayat bab pertama tidak cocok.");
            assert_eq!(first_chapter.translated_name.name, "Pembukaan", "Nama terjemahan bab pertama tidak cocok.");
            assert!(!first_chapter.pages.is_empty(), "Bab pertama harus memiliki informasi halaman.");
        } else {
            panic!("Tidak ada bab yang ditemukan setelah deserialisasi.");
        }

        println!("Berhasil mendeserialisasi dan memvalidasi {} bab dari {}.", chapters_data.chapters.len(), test_file_path);

        Ok(())
    }
}