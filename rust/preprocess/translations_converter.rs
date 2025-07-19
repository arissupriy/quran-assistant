// preprocessor/translations_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct TranslationTextMap dari data-loader
#[path = "../src/data_loader/translations.rs"]
mod translations_struct;
use translations_struct::TranslationTextMap;

pub fn convert_translations() -> Result<()> {
    let input_file = Path::new("data/translations_33.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("translations_33.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk translations_33.bin")?;

    println!("Memulai konversi data translations_33.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke HashMap<String, String> langsung
    let raw_map: std::collections::HashMap<String, String> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON translations_33 dari {:?}", input_file))?;

    // Bungkus ke dalam struct TranslationTextMap
    let translations_data = TranslationTextMap { map: raw_map };

    // Serialisasi TranslationTextMap ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&translations_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi translations_33 dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner translations_33 ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data translations_33.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_translations_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/translations_33.json");
        
        println!("\nMemulai test konversi translations_33.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let raw_map: std::collections::HashMap<String, String> = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let translations_data = TranslationTextMap { map: raw_map };

            let bin_data = bincode::encode_to_vec(&translations_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if translations_data.map.is_empty() {
                bail!("Map TranslationTextMap kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi translations_33.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi translations_33.json berhasil.");
        }

        Ok(())
    }
}