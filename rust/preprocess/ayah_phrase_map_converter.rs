// preprocessor/ayah_phrase_map_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct AyahPhraseMap dari data-loader
#[path = "../src/data_loader/ayah_phrase_map.rs"]
mod ayah_phrase_map_struct;
use ayah_phrase_map_struct::AyahPhraseMap;

pub fn convert_ayah_phrase_map() -> Result<()> {
    let input_file = Path::new("data/ayah_phrase_map.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("ayah_phrase_map.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk ayah_phrase_map.bin")?;

    println!("Memulai konversi data ayah_phrase_map.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke HashMap<String, Vec<u32>> langsung
    let raw_map: std::collections::HashMap<String, Vec<u32>> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON ayah_phrase_map dari {:?}", input_file))?;

    // Bungkus ke dalam struct AyahPhraseMap
    let ayah_phrase_map_data = AyahPhraseMap { map: raw_map };

    // Serialisasi AyahPhraseMap ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&ayah_phrase_map_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi ayah_phrase_map dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner ayah_phrase_map ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data ayah_phrase_map.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail}; // Tambahkan 'bail'
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_ayah_phrase_map_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/ayah_phrase_map.json");
        
        println!("\nMemulai test konversi ayah_phrase_map.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let raw_map: std::collections::HashMap<String, Vec<u32>> = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let ayah_phrase_map_data = AyahPhraseMap { map: raw_map };

            let bin_data = bincode::encode_to_vec(&ayah_phrase_map_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if ayah_phrase_map_data.map.is_empty() {
                bail!("Map AyahPhraseMap kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi ayah_phrase_map.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi ayah_phrase_map.json berhasil.");
        }

        Ok(())
    }
}