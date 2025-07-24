// preprocessor/page_layout_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct PageLayouts dari data-loader
#[path = "../src/data_loader/page_layout.rs"]
mod page_layout_struct;
use page_layout_struct::{PageLayouts, PageLayout, Line, WordData};

pub fn convert_page_layout() -> Result<()> {
    let input_file = Path::new("data/final-layout.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("page_layout_flutter_with_center.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk page_layout_flutter_with_center.bin")?;

    println!("Memulai konversi data page_layout_flutter_with_center.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke PageLayouts
    let page_layout_data: PageLayouts = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON page_layout_flutter_with_center dari {:?}", input_file))?;

    // Serialisasi PageLayouts ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&page_layout_data, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi page_layout_flutter_with_center dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner page_layout_flutter_with_center ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data page_layout_flutter_with_center.");
    Ok(())
}


#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_page_layout_full_conversion_robustness() -> Result<()> {
        let input_file = Path::new("data/page_layout_flutter_with_center.json");
        
        println!("\nMemulai test konversi page_layout_flutter_with_center.json ke BIN...");

        let result: Result<()> = (|| {
            let content = fs::read_to_string(&input_file)
                .with_context(|| format!("Gagal membaca file JSON {:?}", input_file))?;

            let page_layout_data: PageLayouts = serde_json::from_str(&content)
                .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;
            
            let bin_data = bincode::encode_to_vec(&page_layout_data, bincode::config::standard())
                .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
            
            // --- LANGKAH BARU: UJI KOMPRESI ---
            let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
                .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
            // --- AKHIR LANGKAH BARU ---

            // Basic validation after conversion (similar to loader test but minimal)
            if page_layout_data.map.is_empty() {
                bail!("Map PageLayouts kosong setelah deserialisasi dari {:?}", input_file);
            }

            Ok(())
        })();

        if let Err(e) = result {
            panic!("Test konversi page_layout_flutter_with_center.json GAGAL: {:?}", e);
        } else {
            println!("✅ Konversi page_layout_flutter_with_center.json berhasil.");
        }

        Ok(())
    }
}