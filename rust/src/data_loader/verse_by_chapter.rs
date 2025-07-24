// src/data-loader/verse-by-chapter.rs

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct Verse {
    pub id: u32,
    #[serde(rename = "verseNumber")]
    pub verse_number: u32,
    #[serde(rename = "verseKey")]
    pub verse_key: String,
    #[serde(rename = "hizbNumber")]
    pub hizb_number: u32,
    #[serde(rename = "rubElHizbNumber")]
    pub rub_el_hizb_number: u32,
    #[serde(rename = "rukuNumber")]
    pub ruku_number: u32,
    #[serde(rename = "manzilNumber")]
    pub manzil_number: u32,
    #[serde(rename = "sajdahNumber")]
    pub sajdah_number: Option<u32>,
    #[serde(rename = "pageNumber")]
    pub page_number: u32,
    #[serde(rename = "juzNumber")]
    pub juz_number: u32,
    #[serde(rename = "wordIds")]
    pub word_ids: Vec<String>, // ⬅️ word keys seperti "2:1:1"
    #[serde(default)]
    pub translations: Vec<Translation>,
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct Words {
    pub data: HashMap<String, Word>,
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct Word {
    pub id: u32,
    #[serde(rename = "wordKey")]
    pub word_key: String, // ⬅️ "2:1:1"
    pub position: u32,
    #[serde(rename = "charTypeName")]
    pub char_type_name: String,
    #[serde(rename = "textUthmani")]
    pub text_uthmani: String,
    #[serde(rename = "textUthmaniSimple")]
    pub text_uthmani_simple: String,
    #[serde(rename = "textTajweed")]
    pub text_tajweed: Vec<TajweedSegment>,
    #[serde(rename = "pageNumber")]
    pub page_number: u32,
    #[serde(rename = "lineNumber")]
    pub line_number: u32,
    #[serde(rename = "chapterId")]
    pub chapter_id: u32,
    #[serde(rename = "verseId")]
    pub verse_id: u32,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct VerseDetailWithWords {
    pub verse: Verse,
    pub words: Vec<Word>,
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct Translation {
    #[serde(rename = "t")]
    pub text: String, // ⬅️ Berisi teks HTML (dengan <sup foot_note>)
    
    #[serde(rename = "f")]
    #[serde(default)]
    pub footnotes: HashMap<String, String>, // ⬅️ Key footnote -> isi
}

#[derive(Debug, Serialize, Deserialize, Clone, Encode, Decode)]
pub enum TranslationPart {
    Text(String),
    Sup { foot_note: String, label: String },
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct TajweedSegment {
    pub rule: String,    // contoh: "madda_necessary"
    pub text: String     // bagian teks
}

#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, Default)]
pub struct Segment {
    pub r#type: String, // "text" | "rule"
    pub value: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub class: Option<String>
}


#[derive(Debug, Clone, Serialize, Deserialize, Encode, Decode, Default)]
pub struct PageFirstVerse(HashMap<u16, String>);

#[derive(Debug, Clone, Serialize, Deserialize, Encode, Decode, Default)]
pub struct TajweedMeta {
    pub name: String,
    pub description: String,
    pub alias: String,
}

pub type TajweedMetaMap = HashMap<String, TajweedMeta>;

#[derive(Debug, Clone, Serialize, Deserialize, Encode, Decode, Default)]
pub struct TajweedIndex(pub HashMap<String, Vec<String>>); // rule → [word_key]




// #[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
// pub struct WordTranslation {
//     pub text: String,
//     #[serde(rename = "languageName")]
//     pub language_name: String,
// }

// #[derive(Debug, Serialize, Deserialize, Encode, Decode, Default, Clone)]
// pub struct WordTransliteration {
//     pub text: Option<String>,
//     #[serde(rename = "languageName")]
//     pub language_name: String,
// }

// #[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
// pub struct Translation {
//     pub id: u32,
//     #[serde(rename = "resourceId")]
//     pub resource_id: u32,
//     pub text: String,
// }

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use std::fs;
//     use anyhow::Result;

//     #[test]
//     fn test_verse_deserialization_and_deep_validation() -> Result<()> {
//         let test_file_path = "data/verse-by-chapter/chapter-2.json"; // Menggunakan chapter-2.json sebagai contoh
//         let json_content = fs::read_to_string(test_file_path)
//             .expect("Gagal membaca file JSON test. Pastikan 'data/verse-by-chapter/chapter-2.json' ada.");

//         let verses: Vec<Verse> = serde_json::from_str(&json_content)
//             .expect("Gagal mendeserialisasi JSON ke Vec<Verse>. Periksa definisi struct dan format JSON.");

//         assert!(!verses.is_empty(), "Vektor ayat yang dideserialisasi tidak boleh kosong.");

//         let mut expected_verse_number = 1;
//         let chapter_id_from_file = 2; // Mengasumsikan ini untuk chapter-2.json

//         for (_verse_index, verse) in verses.iter().enumerate() {
//             // Validasi di level Verse
//             assert_eq!(verse.verse_number, expected_verse_number,
//                 "Nomor ayat tidak berurutan: Diharapkan {}, ditemukan {} untuk verse_key {}",
//                 expected_verse_number, verse.verse_number, verse.verse_key);
//             assert!(!verse.words.is_empty(), "Ayat {} tidak memiliki kata.", verse.verse_key);
//             assert!(!verse.translations.is_empty(), "Ayat {} tidak memiliki terjemahan.", verse.verse_key);
//             // Contoh validasi spesifik untuk Juz Number, sesuaikan jika bab Anda mencakup banyak juz
//             // assert_eq!(verse.juz_number, 1, "Juz Number tidak sesuai untuk {}", verse.verse_key);

//             // **PENTING: BARIS YANG MENYEBABKAN ERROR 'no field chapter_id' TELAH DIHAPUS.**
//             // 'chapter_id' adalah field dari 'Word', bukan 'Verse'.


//             // Validasi di level Word
//             let mut expected_word_position = 1;
//             let mut previous_word_id: Option<u32> = None;

//             for (_word_index, word) in verse.words.iter().enumerate() {
//                 assert_eq!(word.position, expected_word_position,
//                     "Posisi kata tidak berurutan: Diharapkan {}, ditemukan {} untuk kata di {}",
//                     expected_word_position, word.position, word.location);
//                 // Validasi chapter_id di struct Word
//                 assert_eq!(word.chapter_id, chapter_id_from_file as u32, "Chapter ID kata tidak sesuai untuk {}", word.location);
//                 assert_eq!(word.verse_id, verse.id, "Verse ID kata tidak sesuai untuk {}", word.location);
//                 assert_eq!(word.verse_key, verse.verse_key, "Verse Key kata tidak sesuai untuk {}", word.location);
//                 assert!(!word.text_uthmani.is_empty(), "Teks Uthmani kosong untuk kata di {}", word.location);
//                 assert!(!word.translation.text.is_empty(), "Terjemahan kata kosong untuk kata di {}", word.location);
//                 assert!(!word.translation.language_name.is_empty(), "Nama bahasa terjemahan kata kosong untuk kata di {}", word.location);
//                 if let Some(prev_id) = previous_word_id {
//                     assert!(word.id > prev_id, "ID kata tidak meningkat: {} setelah {}", word.id, prev_id);
//                 }
//                 previous_word_id = Some(word.id);

//                 expected_word_position += 1;
//             }

//             // Validasi di level Translation (terjemahan ayat)
//             let mut found_resource_id_33 = false;
//             for translation in &verse.translations {
//                 assert!(!translation.text.is_empty(), "Teks terjemahan ayat kosong untuk {}", verse.verse_key);
//                 // Asersi untuk 'resource_id' spesifik di dalam loop ini juga tidak ada di sini lagi.
//                 if translation.resource_id == 33 {
//                     found_resource_id_33 = true;
//                 }
//             }
//             // Asersi ini memeriksa keberadaan resourceId 33 di SETIDAKNYA SATU terjemahan.
//             assert!(found_resource_id_33, "Ayat {} tidak memiliki terjemahan dengan Resource ID 33 yang diharapkan.", verse.verse_key);


//             expected_verse_number += 1;
//         }

//         println!("✅ Berhasil mendeserialisasi dan melakukan validasi mendalam untuk {} ayat dari {}.", verses.len(), test_file_path);

//         Ok(())
//     }
// }