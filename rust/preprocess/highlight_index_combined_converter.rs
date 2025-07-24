// preprocessor/highlight_index_combined_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct HighlightIndexCombined dari data-loader
#[path = "../src/data_loader/highlight_index_combined.rs"]
mod highlight_index_combined_struct;
use highlight_index_combined_struct::HighlightIndexCombined;

pub fn convert_highlight_index_combined() -> Result<()> {
    let input_file = Path::new("data/highlight_index_combined.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("highlight_index_combined.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk highlight_index_combined.bin")?;

    println!("Memulai konversi data highlight_index_combined.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke HighlightIndexCombined
    let highlight_data: HighlightIndexCombined = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON highlight_index_combined dari {:?}", input_file))?;

    // Serialisasi HighlightIndexCombined ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&highlight_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi highlight_index_combined dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner highlight_index_combined ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data highlight_index_combined.");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_highlight_index_combined_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/highlight_index_combined.json");
        
        println!("\nMemulai test konversi highlight_index_combined.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let highlight_data: HighlightIndexCombined = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let bin_data = bincode::encode_to_vec(&highlight_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if highlight_data.map.is_empty() {
                bail!("Map HighlightIndexCombined kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi highlight_index_combined.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi highlight_index_combined.json berhasil.");
        }

        Ok(())
    }
}