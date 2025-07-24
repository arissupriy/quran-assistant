// src/data-loader/ayah_texts.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)] 
pub struct AyahText {
    #[serde(rename = "verseKey")]
    pub verse_key: String,
    #[serde(rename = "textUthmaniSimple")]
    pub text_uthmani_simple: String,
    #[serde(rename = "textUthmani")]
    pub text_uthmani: String,
    #[serde(rename = "textQpcHafs")]
    pub text_qpc_hafs: String,
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct AyahTexts {
    // Karena ayah_texts.json adalah array langsung dari objek AyahText,
    // kita bungkus dalam sebuah struct untuk tujuan serialisasi/deserialisasi
    // agar lebih mudah diakses nanti.
    pub texts: Vec<AyahText>,
}

// Tambahkan di AKHIR FILE src/data-loader/ayah_texts.rs

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_ayah_texts_deserialization() -> Result<()> {
        let test_file_path = "data/ayah_texts.json";
        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/ayah_texts.json' ada.");

        // Deserialisasi langsung ke Vec<AyahText>
        let raw_texts: Vec<AyahText> = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON ke Vec<AyahText>. Periksa format JSON.");

        // Bungkus ke dalam struct AyahTexts untuk test
        let ayah_texts_data = AyahTexts { texts: raw_texts };

        // --- Validasi Konten Dinamis ---
        assert!(!ayah_texts_data.texts.is_empty(), "Koleksi AyahTexts tidak boleh kosong.");

        // Contoh validasi: periksa beberapa elemen pertama untuk konsistensi
        if let Some(first_ayah) = ayah_texts_data.texts.get(0) {
            assert_eq!(first_ayah.verse_key, "1:1".to_string(), "Kunci ayat pertama tidak cocok.");
            assert!(!first_ayah.text_uthmani_simple.is_empty(), "Teks Uthmani Simple kosong untuk 1:1.");
            assert!(!first_ayah.text_uthmani.is_empty(), "Teks Uthmani kosong untuk 1:1.");
            assert!(!first_ayah.text_qpc_hafs.is_empty(), "Teks QpcHafs kosong untuk 1:1.");
        } else {
            panic!("Tidak ada teks ayat ditemukan.");
        }

        if let Some(ayah_113_5) = ayah_texts_data.texts.iter().find(|t| t.verse_key == "113:5") {
            assert!(!ayah_113_5.text_uthmani_simple.is_empty(), "Teks Uthmani Simple kosong untuk 113:5.");
        } else {
            panic!("Ayat 113:5 tidak ditemukan.");
        }
        
        // Memastikan semua teks tidak kosong
        for ayah_text in &ayah_texts_data.texts {
            assert!(!ayah_text.verse_key.is_empty(), "Kunci ayat kosong.");
            assert!(!ayah_text.text_uthmani_simple.is_empty(), "Teks Uthmani Simple kosong untuk {}.", ayah_text.verse_key);
            assert!(!ayah_text.text_uthmani.is_empty(), "Teks Uthmani kosong untuk {}.", ayah_text.verse_key);
            assert!(!ayah_text.text_qpc_hafs.is_empty(), "Teks QpcHafs kosong untuk {}.", ayah_text.verse_key);
        }


        // Asersi terakhir: Memastikan jumlah total ayat jika Anda tahu jumlahnya (misalnya, 6236)
        // assert_eq!(ayah_texts_data.texts.len(), 6236, "Jumlah total ayat tidak sesuai harapan.");

        println!("✅ Berhasil mendeserialisasi dan memvalidasi ayah_texts.json.");

        Ok(())
    }
}