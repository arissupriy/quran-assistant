// src/api/metadata_api.rs

use std::collections::HashSet;

use crate::GLOBAL_DATA;
use crate::data_loader::juzs::{Juz, JuzWithPage};
use flutter_rust_bridge::frb;

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