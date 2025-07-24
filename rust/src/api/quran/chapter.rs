// C:\PROJECT\QURAN_ASSISTANT\RUST\SRC\api\quran\chapter.rs

use flutter_rust_bridge::frb;

use crate::GLOBAL_DATA;
use crate::data_loader::chapters::Chapter;
use crate::data_loader::ayah_texts::AyahText;

/// Mengembalikan daftar lengkap semua bab (surah) Al-Quran.
#[frb]
pub fn get_all_chapters() -> Vec<Chapter> {
    GLOBAL_DATA.chapters.chapters.clone()
}

/// Mengembalikan nama sederhana (simple name) dari bab berdasarkan ID bab.
#[frb]
pub fn get_chapter_name_simple(chapter_id: u32) -> String {
    let engine_data = &GLOBAL_DATA;
    if let Some(chapter) = engine_data
        .chapters
        .chapters
        .iter()
        .find(|c| c.id == chapter_id)
    {
        chapter.name_simple.clone()
    } else {
        "Chapter Not Found".to_string()
    }
}

/// Mengembalikan detail lengkap bab berdasarkan ID bab.
pub fn get_chapter_details(chapter_id: u32) -> Option<Chapter> {
    let engine_data = &GLOBAL_DATA;
    engine_data
        .chapters
        .chapters
        .iter()
        .find(|c| c.id == chapter_id)
        .cloned()
}

/// Mengembalikan semua ayat dalam surah (bab) tertentu berdasarkan ID bab.
pub fn get_ayahs_by_surah(chapter_id: u32) -> Vec<AyahText> {
    let engine_data = &GLOBAL_DATA;
    engine_data
        .ayah_texts
        .texts
        .iter()
        .filter(|ayah_text| {
            ayah_text
                .verse_key
                .split(':')
                .next()
                .and_then(|s| s.parse::<u32>().ok())
                == Some(chapter_id)
        })
        .cloned()
        .collect()
}

// #[frb]
// pub fn get_chapter_by_page(page_number: u32) -> Option<Chapter> {
//     let engine_data = &GLOBAL_DATA; // Akses GLOBAL_DATA
//     for chapter in engine_data.chapters.chapters.iter() {
//         if chapter.pages.contains(&page_number) {
//             return Some(chapter.clone());
//         }
//     }
//     None
// }
