// src/api/metadata_api.rs

use std::collections::HashSet;
use std::i32;

use crate::api::mushaf::get_page_metadata;
use crate::data_loader::chapters::Chapter;
use crate::data_loader::juzs::{Juz, JuzWithPage};
use crate::data_loader::mushaf_page_info::MushafPageInfo;
use crate::models::GlyphPosition;
use crate::GLOBAL_DATA;
use anyhow::{Context, Ok, Result};
use flutter_rust_bridge::frb;
use log::{error, info, warn};

use crate::api::mushaf::PACK_STATE;

/// Mengembalikan informasi lengkap tentang Juz berdasarkan nomornya.
/// Jika tidak ditemukan, akan mengembalikan `None` di sisi Dart.
#[frb]
pub fn get_juz_details(juz_number: u32) -> Option<Juz> {
    let engine_data = &GLOBAL_DATA;
    engine_data
        .juzs
        .juzs
        .iter()
        .find(|j| j.juz_number == juz_number)
        .cloned()
}

/// Mengembalikan seluruh daftar Juz.
#[frb]
pub fn get_all_juzs() -> Vec<Juz> {
    GLOBAL_DATA.juzs.juzs.clone()
}

#[frb]
pub fn get_page_from_verse_id(verse_id: u32) -> u32 {
    // info!("Mencari page_number untuk verse_id: {}", verse_id);

    for chapter_verses in GLOBAL_DATA.verses.values() {
        for verse in chapter_verses {
            if verse.id == verse_id {
                return verse.page_number;
            }
        }
    }

    // Jika tidak ditemukan
    1
}

#[frb]
pub fn get_all_juzs_with_page() -> Vec<JuzWithPage> {
    let engine_data = &GLOBAL_DATA;
    let mut seen = HashSet::new();
    let mut result = Vec::new();

    for juz in &engine_data.juzs.juzs {
        if !seen.insert(juz.juz_number) {
            log::warn!("⚠️ Duplikat ditemukan: Juz {}", juz.juz_number);
            continue;
        }

        let page = engine_data
            .verses
            .values()
            .flatten()
            .find(|v| v.id == juz.first_verse_id)
            .map(|v| v.page_number)
            .unwrap_or(1);

        result.push(JuzWithPage {
            juz: juz.clone(),
            page_number: page,
        });
    }

    result
}

/// Mengambil semua informasi kontekstual (nama surah, juz, kata awal halaman berikutnya) untuk halaman Mushaf tertentu.
// src/api/quran/page_info.rs

// ... (imports dan kode lainnya) ...

#[frb]
pub async fn get_mushaf_page_context_info(page_number: i32) -> anyhow::Result<MushafPageInfo> {
    info!("Mendapatkan info kontekstual untuk halaman Mushaf: {}", page_number);
    let engine_data = &GLOBAL_DATA;
    let pack_state_guard = PACK_STATE.lock().unwrap();
    let mushaf_bundle = pack_state_guard
        .as_ref()
        .context("Mushaf pack belum di-load. Panggil open_mushaf_pack terlebih dahulu.")?;

    let mut surah_name_arabic = "Tidak Diketahui".to_string();
    let mut juz_number = 0;
    let mut next_page_route_text = "".to_string();

    // Ambil glyph dari halaman saat ini
    let current_glyphs = mushaf_bundle.index.pages
        .get(&(page_number as u16))
        .map(|entry| &entry.glyphs);

    if let Some(glyphs) = current_glyphs {
        if let Some(first_glyph) = glyphs.iter().min_by_key(|g| (g.line_number as u32, g.word_position as u32)) {
            let surah_id = first_glyph.sura as u32;
            let ayah_number = first_glyph.ayah as u32;

            // Ambil nama surah
            if let Some(chapter) = engine_data.chapters.chapters.iter().find(|c| c.id == surah_id) {
                surah_name_arabic = chapter.name_arabic.clone();
            }

            // Ambil juz dari verse yang cocok
            if let Some(verses) = engine_data.verses.get(&surah_id) {
                if let Some(verse) = verses.iter().find(|v| v.verse_number == ayah_number) {
                    juz_number = verse.juz_number;
                }
            }
        }
    }

    // Ambil kata pertama dan kedua dari halaman berikutnya
    let next_page_number = page_number + 1;
    let next_glyphs = mushaf_bundle.index.pages
        .get(&(next_page_number as u16))
        .map(|entry| &entry.glyphs);

    if let Some(glyphs) = next_glyphs {
        if let Some(first_glyph) = glyphs.iter().min_by_key(|g| (g.line_number as u32, g.word_position as u32)) {
            let word_key = format!("{}:{}:{}", first_glyph.sura, first_glyph.ayah, first_glyph.word_position);

            if let Some(word) = engine_data.words.data.get(&word_key) {
                next_page_route_text = word.text_uthmani.clone();

                let next_word_key = format!("{}:{}:{}", first_glyph.sura, first_glyph.ayah, first_glyph.word_position + 1);
                if let Some(next_word) = engine_data.words.data.get(&next_word_key) {
                    next_page_route_text += &format!(" {}", next_word.text_uthmani);
                }
            }
        }
    }

    Ok(MushafPageInfo {
        surah_name_arabic,
        juz_number,
        page_number: page_number as u32,
        next_page_route_text,
    })
}

//// buatkan get_chapter_details_by_page_number(page_number: u32) -> Option<Chapter>

#[frb]
pub fn get_chapter_by_page_number(page_number: u32) -> Option<Chapter> {

    // Mencari chapter yang memiliki halaman dalam range
    let engine_data = &GLOBAL_DATA;

    // Debug: Log parameter input
    info!("🔍 Mencari chapter untuk page_number: {}", page_number);
    
    // Debug: Log jumlah chapters yang tersedia
    info!("📚 Total chapters tersedia: {}", engine_data.chapters.chapters.len());

    // Debug: Log beberapa chapters pertama
    for (i, chapter) in engine_data.chapters.chapters.iter().take(3).enumerate() {
        info!("📖 Chapter {}: id={}, name={}, pages={:?}", 
            i + 1, chapter.id, chapter.name_simple, chapter.pages);
    }

    // Cari chapter yang memiliki halaman dalam range
    let chapter = engine_data
        .chapters
        .chapters
        .iter()
        .find(|c| {
            let matches = match c.pages.as_slice() {
                [start_page, end_page] => {
                    let in_range = page_number >= *start_page && page_number <= *end_page;
                    // Debug: Log setiap pengecekan
                    info!("🔍 Chapter {} ({}): range [{}, {}], page {} in range: {}", 
                        c.id, c.name_simple, start_page, end_page, page_number, in_range);
                    in_range
                }
                [single_page] => {
                    let matches = page_number == *single_page;
                    info!("🔍 Chapter {} ({}): single page {}, page {} matches: {}", 
                        c.id, c.name_simple, single_page, page_number, matches);
                    matches
                }
                _ => {
                    warn!("⚠️ Chapter {} ({}) has invalid pages format: {:?}", 
                        c.id, c.name_simple, c.pages);
                    false
                }
            };
            matches
        })
        .cloned();

    match &chapter {
        Some(ch) => {
            info!("✅ Chapter ditemukan: id={}, name={}, pages={:?}", 
                ch.id, ch.name_simple, ch.pages);
        }
        None => {
            error!("❌ Chapter tidak ditemukan untuk page_number: {}", page_number);
            
            // Debug: Tampilkan semua ranges yang tersedia
            info!("📋 Available page ranges:");
            for ch in &engine_data.chapters.chapters {
                info!("   Chapter {}: pages={:?}", ch.id, ch.pages);
            }
        }
    }

    chapter
}
