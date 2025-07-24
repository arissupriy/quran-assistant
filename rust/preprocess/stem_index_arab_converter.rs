// preprocessor/stem_index_arab_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct StemIndexArab dari data-loader
#[path = "../src/data_loader/stem_index_arab.rs"]
mod stem_index_arab_struct;
use stem_index_arab_struct::StemIndexArab;

pub fn convert_stem_index_arab() -> Result<()> {
    let input_file = Path::new("data/stem_index_arab.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("stem_index_arab.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk stem_index_arab.bin")?;

    println!("Memulai konversi data stem_index_arab.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke HashMap<String, Vec<String>> langsung
    let raw_map: std::collections::HashMap<String, Vec<String>> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON stem_index_arab dari {:?}", input_file))?;

    // Bungkus ke dalam struct StemIndexArab
    let stem_index_arab_data = StemIndexArab { map: raw_map };

    // Serialisasi StemIndexArab ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&stem_index_arab_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi stem_index_arab dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner stem_index_arab ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data stem_index_arab.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_stem_index_arab_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/stem_index_arab.json");
        
        println!("\nMemulai test konversi stem_index_arab.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let raw_map: std::collections::HashMap<String, Vec<String>> = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let stem_data = StemIndexArab { map: raw_map };

            let bin_data = bincode::encode_to_vec(&stem_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if stem_data.map.is_empty() {
                bail!("Map StemIndexArab kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi stem_index_arab.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi stem_index_arab.json berhasil.");
        }

        Ok(())
    }
}