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

    for chapter_verses in GLOBAL_DATA.verses_by_chapter.values() {
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
            .verses_by_chapter
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
    // Menggunakan anyhow::Result
    info!(
        "Mendapatkan info kontekstual untuk halaman Mushaf: {}",
        page_number
    );

    let engine_data = &GLOBAL_DATA;
    let pack_state_guard = PACK_STATE.lock().unwrap();
    let mushaf_bundle = pack_state_guard
        .as_ref()
        .context("Mushaf pack belum di-load. Panggil open_mushaf_pack terlebih dahulu.")?;

    let mut surah_name_arabic = "Tidak Diketahui".to_string();
    let mut juz_number = 0;
    let mut next_page_route_text = "".to_string();

    let current_glyphs: Option<&Vec<GlyphPosition>> = mushaf_bundle
        .index
        .pages
        .get(&(page_number as u16))
        .map(|entry| &entry.glyphs);

    if let Some(glyphs) = current_glyphs {
        if let Some(first_glyph_on_page) = glyphs
            .iter()
            .min_by_key(|&g| (g.line_number as u32, g.word_position as u32))
        {
            // Konversi ke u32
            // Ambil ID Surah dan Ayat, konversi ke u32
            let current_surah_id_from_glyph: u32 = first_glyph_on_page.sura as u32;
            let current_ayah_number: u32 = first_glyph_on_page.ayah as u32;

            // Ambil Nama Surah Arab dari GLOBAL_DATA.chapters
            // Chapter.id adalah u32, jadi bandingkan dengan u32
            if let Some(chapter_details) = engine_data
                .chapters
                .chapters
                .iter()
                .find(|c| c.id == current_surah_id_from_glyph)
            {
                surah_name_arabic = chapter_details.name_arabic.clone();
            } else {
                warn!(
                    "Detail chapter tidak ditemukan di GLOBAL_DATA untuk surah ID: {}",
                    current_surah_id_from_glyph
                );
            }

            // Ambil Nomor Juz dari ayat pertama di halaman ini
            // engine_data.verses_by_chapter adalah HashMap<u32, Vec<Verse>>
            // Verse.verse_number adalah u32
            // Verse.juz_number adalah u32
            if let Some(chapter_verses) = engine_data
                .verses_by_chapter
                .get(&current_surah_id_from_glyph)
            {
                if let Some(current_verse) = chapter_verses
                    .iter()
                    .find(|v| v.verse_number == current_ayah_number)
                {
                    juz_number = current_verse.juz_number; // Langsung ambil u32
                } else {
                    warn!(
                        "Ayat {} tidak ditemukan di GLOBAL_DATA untuk surah {}.",
                        current_ayah_number, current_surah_id_from_glyph
                    );
                }
            } else {
                warn!(
                    "Chapter {} tidak ditemukan di GLOBAL_DATA.verses_by_chapter.",
                    current_surah_id_from_glyph
                );
            }
        } else {
            warn!(
                "Tidak ada glyph yang valid ditemukan di halaman {}.",
                page_number
            );
        }
    } else {
        warn!(
            "Metadata glyph tidak ditemukan di PACK_STATE untuk halaman {}.",
            page_number
        );
    }

    let next_page_number = page_number + 1; // page_number input adalah i32
    let next_glyphs: Option<&Vec<GlyphPosition>> = mushaf_bundle
        .index
        .pages
        .get(&(next_page_number as u16))
        .map(|entry| &entry.glyphs);

    if let Some(glyphs) = next_glyphs {
        if !glyphs.is_empty() {
            let first_glyph_on_next_page_option = glyphs
                .iter()
                .min_by_key(|&g| (g.line_number as u32, g.word_position as u32)); // Konversi ke u32

            if let Some(glyph) = first_glyph_on_next_page_option {
                if (glyph.page_number as i32) == next_page_number {
                    // page_number di GlyphPosition adalah u16, next_page_number adalah i32
                    let next_glyph_sura: u32 = glyph.sura as u32;
                    let next_glyph_ayah: u32 = glyph.ayah as u32;

                    if let Some(next_chapter_verses) =
                        engine_data.verses_by_chapter.get(&next_glyph_sura)
                    {
                        if let Some(next_verse) = next_chapter_verses
                            .iter()
                            .find(|v| v.verse_number == next_glyph_ayah)
                        {
                            if !next_verse.words.is_empty() {
                                next_page_route_text = next_verse.words[0].text_uthmani.clone();
                                if next_verse.words.len() > 1 {
                                    next_page_route_text +=
                                        &format!(" {}", next_verse.words[1].text_uthmani);
                                }
                            } else {
                                warn!(
                                    "Ayat berikutnya kosong kata untuk halaman {}.",
                                    next_page_number
                                );
                            }
                        } else {
                            warn!("Detail verse tidak ditemukan di GLOBAL_DATA untuk halaman berikutnya {}.", next_page_number);
                        }
                    } else {
                        warn!("Chapter {} tidak ditemukan di GLOBAL_DATA.verses_by_chapter untuk halaman berikutnya.", next_glyph_sura);
                    }
                } else {
                    warn!("Glyph pertama yang ditemukan di PACK_STATE untuk halaman {} bukan dari halaman itu sendiri.", next_page_number);
                }
            } else {
                warn!("Tidak ada glyph valid yang ditemukan di PACK_STATE untuk halaman berikutnya {}.", next_page_number);
            }
        }
    } else {
        warn!(
            "Metadata glyph tidak ditemukan di PACK_STATE untuk halaman berikutnya {}.",
            next_page_number
        );
    }

    Ok(MushafPageInfo {
        surah_name_arabic,
        juz_number,
        page_number: page_number as u32,
        next_page_route_text,
        
    }) 

    // Ok(MushafPageInfo { surah_name_arabic: "contoh".to_string(), juz_number: "1".to_string(), page_number: "1".to_string(), next_page_route_text: "2".to_string() })
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
