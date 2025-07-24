// preprocessor/translation_metadata_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct TranslationMetadata dari data-loader
#[path = "../src/data_loader/translation_metadata.rs"]
mod translation_metadata_struct;
use translation_metadata_struct::TranslationMetadata;

pub fn convert_translation_metadata() -> Result<()> {
    let input_file = Path::new("data/translation_metadata.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("translation_metadata.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk translation_metadata.bin")?;

    println!("Memulai konversi data translation_metadata.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke HashMap<String, String> langsung
    let raw_map: std::collections::HashMap<String, String> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON translation_metadata dari {:?}", input_file))?;

    // Bungkus ke dalam struct TranslationMetadata
    let translation_metadata_data = TranslationMetadata { map: raw_map };

    // Serialisasi TranslationMetadata ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&translation_metadata_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi translation_metadata dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner translation_metadata ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data translation_metadata.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_translation_metadata_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/translation_metadata.json");
        
        println!("\nMemulai test konversi translation_metadata.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let raw_map: std::collections::HashMap<String, String> = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let metadata: TranslationMetadata = TranslationMetadata { map: raw_map };

            let bin_data = bincode::encode_to_vec(&metadata, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if metadata.map.is_empty() {
                bail!("Map TranslationMetadata kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi translation_metadata.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi translation_metadata.json berhasil.");
        }

        Ok(())
    }
}