use std::fs;
use std::path::Path;
use std::collections::HashMap;
use serde_json;
use bincode;
use anyhow::{Result, Context};
use zstd::stream;

#[path = "../src/data_loader/verse_by_chapter.rs"]
mod verse_by_chapter;
use verse_by_chapter::PageFirstVerse;

pub fn convert_page_first_verse_json() -> Result<()> {
    let input_path = Path::new("output/page_first_verse.json");
    let output_path = Path::new("data-bin-compressed/page_first_verse.bin");

    // Pastikan direktori output ada
    if let Some(parent_dir) = output_path.parent() {
        fs::create_dir_all(parent_dir).context("Gagal membuat direktori output")?;
    }

    println!("📄 Membaca file: {:?}", input_path);
    let content = fs::read_to_string(&input_path)
        .with_context(|| format!("Gagal membaca file input {:?}", input_path))?;

    // Langsung parse ke HashMap<u16, String>
    let data: PageFirstVerse = serde_json::from_str(&content)
        .with_context(|| format!("Gagal mem-parse JSON ke HashMap dari {:?}", input_path))?;

    // Encode ke bincode
    let bin_data = bincode::encode_to_vec(&data, bincode::config::standard())
        .with_context(|| format!("Gagal melakukan serialisasi bincode untuk {:?}", input_path))?;

    // Kompres menggunakan Zstd
    let compressed_data = stream::encode_all(&bin_data[..], 0)
        .context("Gagal melakukan kompresi Zstd")?;

    // Tulis hasil ke output
    fs::write(&output_path, compressed_data)
        .with_context(|| format!("Gagal menulis file output {:?}", output_path))?;

    println!("✅ File berhasil dikonversi dan dikompresi ke {:?}", output_path);
    Ok(())
}
