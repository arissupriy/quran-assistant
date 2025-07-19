// preprocessor/phrase_highlight_map_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct PhraseHighlightMap dari data-loader
#[path = "../src/data_loader/phrase_highlight_map.rs"]
mod phrase_highlight_map_struct;
use phrase_highlight_map_struct::PhraseHighlightMap;

pub fn convert_phrase_highlight_map() -> Result<()> {
    let input_file = Path::new("data/phrase_highlight_map.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("phrase_highlight_map.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk phrase_highlight_map.bin")?;

    println!("Memulai konversi data phrase_highlight_map.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke PhraseHighlightMap
    let phrase_highlight_data: PhraseHighlightMap = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON phrase_highlight_map dari {:?}", input_file))?;

    // Serialisasi PhraseHighlightMap ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&phrase_highlight_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi phrase_highlight_map dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner phrase_highlight_map ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data phrase_highlight_map.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_phrase_highlight_map_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/phrase_highlight_map.json");
        
        println!("\nMemulai test konversi phrase_highlight_map.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let phrase_highlight_data: PhraseHighlightMap = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let bin_data = bincode::encode_to_vec(&phrase_highlight_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if phrase_highlight_data.map.is_empty() {
                bail!("Map PhraseHighlightMap kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi phrase_highlight_map.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi phrase_highlight_map.json berhasil.");
        }

        Ok(())
    }
}