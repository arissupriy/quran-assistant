use std::fs;
use std::path::Path;
use anyhow::{Result, Context};
use serde_json;
use bincode;
use zstd::stream;

// Import model TajweedIndex
#[path = "../src/data_loader/verse_by_chapter.rs"]
mod tajweed_index;
use tajweed_index::TajweedIndex;

pub fn convert_tajweed_index() -> Result<()> {
    let input_path = Path::new("output/tajweed_index.json");
    let output_path = Path::new("data-bin-compressed/tajweed_index.json.bin");

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent).context("Gagal membuat direktori output")?;
    }

    println!("📄 Membaca file: {:?}", input_path);
    let content = fs::read_to_string(input_path)
        .with_context(|| format!("Gagal membaca file input {:?}", input_path))?;

    let index: TajweedIndex = serde_json::from_str(&content)
        .with_context(|| "Gagal mem-parse JSON menjadi TajweedIndex")?;

    let bin_data = bincode::encode_to_vec(&index, bincode::config::standard())
        .with_context(|| "Gagal men-serialize TajweedIndex")?;

    let compressed_data = stream::encode_all(&bin_data[..], 0)
        .with_context(|| "Gagal mengompresi TajweedIndex")?;

    fs::write(&output_path, compressed_data)
        .with_context(|| format!("Gagal menulis file {:?}", output_path))?;

    println!("✅ Sukses dikompresi -> {:?}", output_path);
    Ok(())
}
