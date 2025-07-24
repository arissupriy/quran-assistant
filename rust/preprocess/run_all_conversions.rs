// preprocessor/run_all_conversions.rs

use anyhow::{Result, Context};


// Deklarasikan modul-modul konverter lokal
mod verse_by_chapter_converter; // Memanggil verse_by_chapter_converter.rs
mod chapter_converter;         // Memanggil chapter_converter.rs
mod all_verse_keys_converter;  // Memanggil all_verse_keys_converter.rs
mod ayah_phrase_map_converter; // Deklarasikan modul baru
mod ayah_texts_converter;
mod highlight_index_combined_converter; // Deklarasikan modul baru
mod juzs_converter; // Deklarasikan modul baru
mod lemma_index_arab_converter; // Deklarasikan modul baru
mod page_layout_converter; // Deklarasikan modul baru
mod phrase_highlight_map_converter; // Deklarasikan modul baru
mod phrase_index_converter; // Deklarasikan modul baru
mod semantic_index_arab_converter; // Deklarasikan modul baru
mod stem_index_arab_converter; // Deklarasikan modul baru
mod translation_metadata_converter; // Deklarasikan modul baru
mod translations_converter; // Deklarasikan modul baru
mod valid_matching_ayah_converter; // Deklarasikan modul baru
mod arabic_stop_words_converter;
mod convert_page_verses;
mod convert_words; // Deklarasikan modul baru
mod convert_tajweed_meta; // Deklarasikan modul baru
mod convert_tajweed_index; // Deklarasikan modul baru
mod convert_translation_id; // Deklarasikan modul baru

fn main() -> Result<()> {
    println!("🚀 Memulai semua proses konversi data...");

    // Panggil fungsi konversi dari setiap modul
    verse_by_chapter_converter::convert_verses_by_chapter()
        .context("Gagal mengonversi data ayat per bab")?;

    chapter_converter::convert_chapters()
        .context("Gagal mengonversi data bab")?;

    all_verse_keys_converter::convert_all_verse_keys()
        .context("Gagal mengonversi data all_verse_keys")?;

    ayah_phrase_map_converter::convert_ayah_phrase_map()
        .context("Gagal mengonversi data ayah_phrase_map")?;

    ayah_texts_converter::convert_ayah_texts()
        .context("Gagal mengonversi data ayah_texts")?;

    // highlight_index_combined_converter::convert_highlight_index_combined()
    //     .context("Gagal mengonversi data highlight_index_combined")?;

    juzs_converter::convert_juzs()
        .context("Gagal mengonversi data juzs")?;

    lemma_index_arab_converter::convert_lemma_index_arab()
        .context("Gagal mengonversi data lemma_index_arab")?;
    
    page_layout_converter::convert_page_layout()
        .context("Gagal mengonversi data page_layout")?;

    phrase_highlight_map_converter::convert_phrase_highlight_map()
        .context("Gagal mengonversi data phrase_highlight_map")?;

    phrase_index_converter::convert_phrase_index()
        .context("Gagal mengonversi data phrase_index")?;

    semantic_index_arab_converter::convert_semantic_index_arab()
        .context("Gagal mengonversi data semantic_index_arab")?;

    stem_index_arab_converter::convert_stem_index_arab()
        .context("Gagal mengonversi data stem_index_arab")?;

    translation_metadata_converter::convert_translation_metadata()
        .context("Gagal mengonversi data translation_metadata")?;

    translations_converter::convert_translations()
        .context("Gagal mengonversi data translations_33")?;

    // ... (panggilan fungsi konversi lainnya) ...
    valid_matching_ayah_converter::convert_valid_matching_ayah()
        .context("Gagal mengonversi data valid_matching_ayah")?;

    arabic_stop_words_converter::convert_arabic_stop_words()
        .context("Gagal mengonversi data arabic_stop_words")?;

    convert_page_verses::convert_page_first_verse_json()
        .context("Gagal mengonversi data page_verse_first")?;

    convert_words::convert_words()
        .context("Gagal mengonversi data words")?;

    convert_tajweed_meta::convert_tajweed_meta()
        .context("Gagal mengonversi data tajweed_meta")?;

    convert_tajweed_index::convert_tajweed_index()
        .context("Gagal mengonversi data tajweed_index")?;

    convert_translation_id::convert_translation_id()
        .context("Gagal mengonversi data translation_id")?;

    





    println!("\n🎉 Semua konversi data selesai dengan sukses!");
    Ok(())
}