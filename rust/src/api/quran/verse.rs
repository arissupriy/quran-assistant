// C:\PROJECT\QURAN_ASSISTANT\RUST\SRC\api\quran\verse.rs

use flutter_rust_bridge::frb;

use crate::GLOBAL_DATA;
use crate::data_loader::ayah_texts::AyahText;
use crate::data_loader::verse_by_chapter::{Translation, Verse, Word};
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
pub fn get_verse_texts(verse_key: String) -> AyahText {
    let engine_data = &GLOBAL_DATA;
    engine_data
        .ayah_texts
        .texts
        .iter()
        .find(|at| at.verse_key == verse_key)
        .cloned()
        .unwrap_or_else(|| {
            warn!("⚠️ Ayat dengan kunci {} tidak ditemukan dalam ayah_texts", verse_key);
            AyahText {
                verse_key,
                text_uthmani_simple: String::new(),
                text_uthmani: String::new(),
                text_qpc_hafs: String::new(),
            }
        })

    
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

    engine_data.verses.get(&chapter_id)
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

    if let Some(verses_in_chapter) = engine_data.verses.get(&chapter_number) {
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
pub fn get_translation_text(verse_key: &str) -> Option<String> {
    // Pastikan translation data sudah dimuat
    let engine_data = &GLOBAL_DATA;

    // Ambil dari hashmap berdasarkan key seperti "2:1"
    engine_data.translation.get(verse_key).map(|t| t.text.clone())
}

#[frb]
/// Mengembalikan detail objek Word (kata) berdasarkan `word_key`, misalnya "2:1:3"
pub fn get_word_details(verse_key: String) -> Option<Translation> {
    let engine_data = &GLOBAL_DATA;
    engine_data.translation.get(&verse_key).cloned()
}