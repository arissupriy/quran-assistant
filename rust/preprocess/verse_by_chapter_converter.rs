// preprocessor/verse_by_chapter_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail}; // Tambahkan 'bail' untuk error yang lebih mudah
use regex::Regex; // Diperlukan untuk test dinamis
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import the Verse struct from the data_loader module
#[path = "../src/data_loader/verse_by_chapter.rs"]
mod verse_by_chapter;
use verse_by_chapter::Verse;

pub fn convert_verses_by_chapter() -> Result<()> {
    let input_dir = Path::new("output/chapters");
    let output_dir = Path::new("data-bin-compressed/verse-by-chapter");

    fs::create_dir_all(output_dir).context("Gagal membuat direktori output")?;

    println!("Memulai konversi data ayat per bab...");
    for entry in fs::read_dir(input_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().and_then(|e| e.to_str()) == Some("json") {
            let content = fs::read_to_string(&path)?;
            let verses: Vec<Verse> = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mem-parse JSON dari {:?}", path))?;

            let bin_data = bincode::encode_to_vec(&verses, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi {:?}", path))?;

            // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
            let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
                .context(format!("Gagal mengkompresi data untuk {:?}", path))?;
            // --- AKHIR LANGKAH BARU ---

            let file_name = path.file_stem().unwrap().to_string_lossy();
            let output_path = output_dir.join(format!("{}.bin", file_name));
            fs::write(&output_path, compressed_data) // <--- Tulis data terkompresi
                .with_context(|| format!("Gagal menulis {:?}", output_path))?;

            println!("✅ Converted and compressed {:?} -> {:?}", path, output_path);
        }
    }

    println!("🚀 All files converted and compressed.");
    Ok(())
}

// #[cfg(test)]
// mod tests {
//     use super::*; // Impor semua item dari modul induk
//     use std::fs;
//     use std::path::Path;
//     use anyhow::{Result, Context, bail}; // Tambahkan 'bail'
//     use regex::Regex; // Diperlukan untuk mengekstrak chapter ID dari nama file
//     use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

//     #[test]
//     fn test_all_chapter_json_conversion_and_dynamic_validation() -> Result<()> {
//         let input_dir = Path::new("data/verse-by-chapter");
        
//         println!("\nMemulai test konversi JSON ke BIN dan validasi dinamis untuk semua chapter...");

//         let mut processed_files_count = 0;
//         let mut validation_errors = Vec::new();

//         // Regex untuk mengekstrak nomor bab dari nama file (e.g., "chapter-2.json" -> 2)
//         let re_chapter_id = Regex::new(r"chapter-(\d+)\.json$")
//             .context("Gagal membuat regex untuk chapter ID")?;

//         // Iterasi melalui semua file di direktori input
//         for entry_result in fs::read_dir(input_dir)? {
//             let entry = entry_result?;
//             let path = entry.path();

//             // Pastikan ini adalah file JSON
//             if path.extension().and_then(|e| e.to_str()) == Some("json") {
//                 let file_name = path.file_name().and_then(|n| n.to_str()).unwrap_or("unknown");
//                 println!("  Menguji file: {:?}", file_name);
//                 processed_files_count += 1;

//                 let chapter_id_match = re_chapter_id.captures(file_name);
//                 let chapter_id_from_file: u32 = match chapter_id_match {
//                     Some(caps) => caps[1].parse().context(format!("Gagal mengurai chapter ID dari {:?}", file_name))?,
//                     None => {
//                         validation_errors.push(format!("Nama file tidak sesuai pola chapter-X.json: {:?}", file_name));
//                         continue; // Lewati file ini jika nama tidak sesuai
//                     }
//                 };

//                 let result: Result<()> = (|| {
//                     let content = fs::read_to_string(&path)
//                         .with_context(|| format!("Gagal membaca file JSON {:?}", path))?;

//                     // Deserialisasi JSON ke struct Verse
//                     let verses: Vec<Verse> = serde_json::from_str(&content)
//                         .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", path))?;

//                     // Serialisasi struct Verse ke biner
//                     let bin_data = bincode::encode_to_vec(&verses, bincode::config::standard())
//                         .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", path))?;
                    
//                     // --- LANGKAH BARU: UJI KOMPRESI ---
//                     let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
//                         .context(format!("Gagal mengkompresi data untuk test {:?}", path))?;
//                     // --- AKHIR LANGKAH BARU ---

//                     // --- Validasi Konten Dinamis ---
//                     if verses.is_empty() {
//                         bail!("Bab kosong: tidak ada ayat ditemukan di {:?}", path);
//                     }

//                     let mut expected_verse_number = 1;
//                     for verse in &verses {
//                         // Validasi nomor ayat berurutan
//                         if verse.verse_number != expected_verse_number {
//                             bail!("Nomor ayat tidak berurutan: Diharapkan {}, ditemukan {} untuk verse_key {} di {:?}",
//                                 expected_verse_number, verse.verse_number, verse.verse_key, file_name);
//                         }
//                         // Validasi Juz Number (nilai bervariasi, tidak di-hardcode)
//                         if verse.juz_number == 0 { // Contoh validasi: pastikan juz_number bukan 0
//                             bail!("Juz Number tidak valid (0) untuk {} di {:?}", verse.verse_key, file_name);
//                         }

//                         // Validasi keberadaan words dan translations
//                         if verse.words.is_empty() {
//                             bail!("Ayat {} tidak memiliki kata di {:?}", verse.verse_key, file_name);
//                         }
//                         if verse.translations.is_empty() {
//                             bail!("Ayat {} tidak memiliki terjemahan di {:?}", verse.verse_key, file_name);
//                         }

//                         // Validasi di level Word
//                         let mut expected_word_position = 1;
//                         let mut previous_word_id: Option<u32> = None;
//                         for word in &verse.words {
//                             if word.position != expected_word_position {
//                                 bail!("Posisi kata tidak berurutan: Diharapkan {}, ditemukan {} untuk kata di {} di {:?}",
//                                     expected_word_position, word.position, word.location, file_name);
//                             }
//                             if word.chapter_id != chapter_id_from_file {
//                                 bail!("Chapter ID kata tidak sesuai: Diharapkan {}, ditemukan {} untuk kata di {} di {:?}",
//                                     chapter_id_from_file, word.chapter_id, word.location, file_name);
//                             }
//                             if word.verse_id != verse.id {
//                                 bail!("Verse ID kata tidak sesuai: Diharapkan {}, ditemukan {} untuk kata di {} di {:?}",
//                                     verse.id, word.verse_id, word.location, file_name);
//                             }
//                             if word.verse_key != verse.verse_key {
//                                 bail!("Verse Key kata tidak sesuai: Diharapkan {}, ditemukan {} untuk kata di {} di {:?}",
//                                     verse.verse_key, word.verse_key, word.location, file_name);
//                             }
//                             if word.text_uthmani.is_empty() {
//                                 bail!("Teks Uthmani kosong untuk kata di {} di {:?}", word.location, file_name);
//                             }
//                             if word.translation.text.is_empty() {
//                                 bail!("Terjemahan kata kosong untuk kata di {} di {:?}", word.location, file_name);
//                             }
//                             if word.translation.language_name.is_empty() {
//                                 bail!("Nama bahasa terjemahan kata kosong untuk kata di {} di {:?}", word.location, file_name);
//                             }
//                             if let Some(prev_id) = previous_word_id {
//                                 if word.id <= prev_id { 
//                                     bail!("ID kata tidak meningkat: {} setelah {} untuk kata di {} di {:?}", word.id, prev_id, word.location, file_name);
//                                 }
//                             }
//                             previous_word_id = Some(word.id);

//                             expected_word_position += 1;
//                         }

//                         // Validasi di level Translation (terjemahan ayat)
//                         let mut found_resource_id_33 = false;
//                         for translation in &verse.translations {
//                             if translation.text.is_empty() {
//                                 bail!("Teks terjemahan ayat kosong untuk {} di {:?}", verse.verse_key, file_name);
//                             }
//                             if translation.resource_id == 33 { // Memastikan resourceId 33 ada
//                                 found_resource_id_33 = true;
//                             }
//                         }
//                         if !found_resource_id_33 {
//                             bail!("Ayat {} tidak memiliki terjemahan dengan Resource ID 33 yang diharapkan di {:?}", verse.verse_key, file_name);
//                         }

//                         expected_verse_number += 1;
//                     }
//                     Ok(())
//                 })(); // Panggil closure untuk menangkap error per file

//                 if let Err(e) = result {
//                     validation_errors.push(format!("Validasi GAGAL untuk {:?}: {:?}", file_name, e));
//                 } else {
//                     println!("  ✅ Validasi & Konversi {:?} berhasil.", file_name);
//                 }
//             }
//         }

//         // Final assertion: Pastikan ada file yang diproses dan tidak ada error validasi
//         assert!(processed_files_count > 0, "Tidak ada file JSON chapter yang ditemukan untuk diuji.");
//         if !validation_errors.is_empty() {
//             panic!("Ditemukan {} error validasi atau konversi:\n{}", validation_errors.len(), validation_errors.join("\n"));
//         } else {
//              println!("\n🎉 Berhasil menguji konversi dan validasi mendalam untuk semua {} file chapter JSON.", processed_files_count);
//         }

//         Ok(())
//     }
// }