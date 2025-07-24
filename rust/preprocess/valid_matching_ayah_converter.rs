// preprocessor/valid_matching_ayah_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct ValidMatchingAyah dari data-loader
#[path = "../src/data_loader/valid_matching_ayah.rs"]
mod valid_matching_ayah_struct;
use valid_matching_ayah_struct::ValidMatchingAyah;

pub fn convert_valid_matching_ayah() -> Result<()> {
    let input_file = Path::new("data/valid-matching-ayah.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("valid-matching-ayah.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk valid-matching-ayah.bin")?;

    println!("Memulai konversi data valid-matching-ayah.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke ValidMatchingAyah
    let valid_matching_ayah_data: ValidMatchingAyah = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON valid-matching-ayah dari {:?}", input_file))?;

    // Serialisasi ValidMatchingAyah ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&valid_matching_ayah_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi valid-matching-ayah dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner valid-matching-ayah ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data valid-matching-ayah.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_valid_matching_ayah_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/valid-matching-ayah.json");
        
        println!("\nMemulai test konversi valid-matching-ayah.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let valid_matching_ayah_data: ValidMatchingAyah = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let bin_data = bincode::encode_to_vec(&valid_matching_ayah_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if valid_matching_ayah_data.map.is_empty() {
                bail!("Map ValidMatchingAyah kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi valid-matching-ayah.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi valid-matching-ayah.json berhasil.");
        }

        Ok(())
    }
}