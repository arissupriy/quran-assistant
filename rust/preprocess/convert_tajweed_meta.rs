use std::fs;
use std::path::Path;
use anyhow::{Result, Context};
use serde_json;
use bincode;
use zstd::stream;

// Import model TajweedMeta
#[path = "../src/data_loader/verse_by_chapter.rs"]
mod tajweed_meta;
use tajweed_meta::TajweedMetaMap;

pub fn convert_tajweed_meta() -> Result<()> {
    let input_path = Path::new("output/tajweed_meta.json");
    let output_path = Path::new("data-bin-compressed/tajweed_meta.json.bin");

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent).context("Gagal membuat direktori output")?;
    }

    println!("📄 Membaca file: {:?}", input_path);
    let content = fs::read_to_string(input_path)
        .with_context(|| format!("Gagal membaca file input {:?}", input_path))?;

    // ✅ Perbaikan di sini: parse ke HashMap<String, TajweedMeta>
    let meta_map: TajweedMetaMap = serde_json::from_str(&content)
        .with_context(|| "Gagal mem-parse JSON menjadi HashMap<String, TajweedMeta>")?;

    let bin_data = bincode::encode_to_vec(&meta_map, bincode::config::standard())
        .with_context(|| "Gagal men-serialize TajweedMeta")?;

    let compressed_data = stream::encode_all(&bin_data[..], 0)
        .with_context(|| "Gagal mengompresi TajweedMeta")?;

    fs::write(&output_path, compressed_data)
        .with_context(|| format!("Gagal menulis file {:?}", output_path))?;

    println!("✅ Sukses dikompresi -> {:?}", output_path);
    Ok(())
}
