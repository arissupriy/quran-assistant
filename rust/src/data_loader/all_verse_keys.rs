// src/data-loader/all_verse_keys.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
pub struct AllVerseKeys {
    // Karena all_verse_keys.json adalah array langsung dari string,
    // kita bungkus dalam sebuah struct untuk tujuan serialisasi/deserialisasi
    // agar lebih mudah diakses nanti.
    #[serde(rename = "keys")] // Anda bisa menghilangkan rename jika nama fieldnya 'keys'
    pub keys: Vec<String>,
}

// src/data-loader/all_verse_keys.rs

// ... (definisi struct AllVerseKeys yang sudah ada) ...

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk (struct Anda)
    use std::fs;
    use anyhow::Result;

    #[test]
    fn test_all_verse_keys_deserialization() -> Result<()> {
        let test_file_path = "data/all_verse_keys.json";

        let json_content = fs::read_to_string(test_file_path)
            .expect("Gagal membaca file JSON test. Pastikan 'data/all_verse_keys.json' ada.");

        // **** KOREKSI PENTING DI SINI ****
        // Mendeserialisasi JSON langsung ke Vec<String> karena all_verse_keys.json adalah array string.
        let raw_keys: Vec<String> = serde_json::from_str(&json_content)
            .expect("Gagal mendeserialisasi JSON all_verse_keys ke Vec<String>. Periksa format JSON.");

        // Kemudian, bungkus Vec<String> ini ke dalam struct AllVerseKeys
        // untuk menguji bahwa struct tersebut bisa diisi dengan data yang benar.
        let all_verse_keys = AllVerseKeys { keys: raw_keys };
        // **********************************

        // Asersi untuk memastikan integritas data dan format.
        assert!(!all_verse_keys.keys.is_empty(), "Vektor kunci ayat tidak boleh kosong.");

        // Sesuaikan dengan data aktual di all_verse_keys.json Anda
        assert_eq!(all_verse_keys.keys.get(0), Some(&"1:1".to_string()), "Kunci ayat pertama tidak cocok.");
        assert_eq!(all_verse_keys.keys.get(6), Some(&"1:7".to_string()), "Kunci ayat ketujuh tidak cocok.");
        assert_eq!(all_verse_keys.keys.get(7), Some(&"2:1".to_string()), "Kunci ayat kedelapan tidak cocok.");

        println!("Berhasil mendeserialisasi dan memvalidasi {} kunci ayat dari {}.", all_verse_keys.keys.len(), test_file_path);

        Ok(())
    }
}