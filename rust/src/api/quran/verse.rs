// C:\PROJECT\QURAN_ASSISTANT\RUST\SRC\api\quran\verse.rs

use flutter_rust_bridge::frb;

use crate::GLOBAL_DATA;
use crate::data_loader::ayah_texts::AyahText;
use crate::data_loader::verse_by_chapter::{Verse, Word};
use log::{debug, info, warn};

#[frb]
/// Mengembalikan teks ayat Uthmani (lengkap dengan harakat) berdasarkan kunci ayat (contoh: "1:1").
pub fn get_verse_text_uthmani(verse_key: String) -> Option<String> {
    let engine_data = &GLOBAL_DATA;
    engine_data
        .ayah_texts
        .texts
        .iter()
        .find(|at| at.verse_key == verse_key)
        .map(|at| at.text_uthmani.clone())
}

#[frb]
/// Mengembalikan nomor juz untuk sebuah ayat berdasarkan kunci ayat.
pub fn get_juz_number_for_verse(verse_key: String) -> Option<u32> {
    let engine_data = &GLOBAL_DATA;

    let parts: Vec<&str> = verse_key.split(':').collect();
    if parts.len() != 2 {
        return None;
    }
    let chapter_id = parts[0].parse::<u32>().ok()?;
    let verse_number = parts[1].parse::<u32>().ok()?;

    engine_data.verses_by_chapter.get(&chapter_id)
        .and_then(|verses_in_chapter| {
            verses_in_chapter.iter().find(|v| v.verse_number == verse_number)
        })
        .map(|verse| verse.juz_number)
}


/// Mengembalikan data lengkap ayat (termasuk kata-kata dan terjemahan) berdasarkan nomor bab dan nomor ayat.
#[flutter_rust_bridge::frb]
pub fn get_verse_by_chapter_and_verse_number(
    chapter_number: u32,
    verse_number: u32,
) -> Option<Verse> {
    let engine_data = &GLOBAL_DATA;

    info!(
        "🔍 Mencari ayat pada surah {} ayat {}",
        chapter_number, verse_number
    );

    if let Some(verses_in_chapter) = engine_data.verses_by_chapter.get(&chapter_number) {
        debug!("✅ Ditemukan {} ayat dalam surah {}", verses_in_chapter.len(), chapter_number);

        if let Some(verse) = verses_in_chapter
            .iter()
            .find(|v| v.verse_number == verse_number)
            .cloned()
        {
            // debug!("✅ Ayat ditemukan: {:?}", verse);
            return Some(verse);
        } else {
            warn!("⚠️ Ayat {} tidak ditemukan dalam surah {}", verse_number, chapter_number);
        }
    } else {
        warn!("⚠️ Surah {} tidak ditemukan dalam verses_by_chapter", chapter_number);
    }

    None
}

#[frb]
/// Mengembalikan teks terjemahan untuk ayat tertentu berdasarkan kunci ayat dan ID sumber terjemahan.
pub fn get_translation_text(verse_key: String, resource_id: u32) -> Option<String> {
    let engine_data = &GLOBAL_DATA;

    if resource_id == 33 {
        engine_data
            .translations_33
            .map
            .get(&verse_key)
            .cloned()
    } else {
        None
    }
}

#[frb]
/// Mengembalikan detail objek Word (kata) untuk kata spesifik dalam sebuah ayat.
pub fn get_word_details(chapter_id: u32, verse_number: u32, word_position: u32) -> Option<Word> {
    let engine_data = &GLOBAL_DATA;
    engine_data
        .verses_by_chapter
        .get(&chapter_id)
        .and_then(|verses_in_chapter| {
            verses_in_chapter.iter().find(|v| v.verse_number == verse_number)
        })
        .and_then(|verse| {
            verse.words.iter().find(|w| w.position == word_position).cloned()
        })
}