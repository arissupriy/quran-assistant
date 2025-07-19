use std::fs;
use std::path::Path;
use std::collections::HashMap;
use anyhow::{Result, Context};
use serde_json;
use bincode;
use zstd::stream;

#[path = "../src/data_loader/verse_by_chapter.rs"]
mod translation;

use translation::Translation;

pub fn convert_translation_id() -> Result<()> {
    let input_path = Path::new("output/translation-id.json");
    let output_path = Path::new("data-bin-compressed/translation-id.bin");

    let content = fs::read_to_string(input_path)
        .with_context(|| format!("Gagal membaca file {:?}", input_path))?;

    // Parse JSON ke HashMap<String, Translation>
    let parsed: HashMap<String, Translation> = serde_json::from_str(&content)
        .context("Gagal mem-parse JSON menjadi HashMap<String, Translation>")?;

    // Encode ke bincode dan kompresi ZSTD
    let binary_data = bincode::encode_to_vec(&parsed, bincode::config::standard())
        .context("Gagal men-serialize data")?;

    let compressed = stream::encode_all(&binary_data[..], 0)
        .context("Gagal mengompresi data")?;

    // Pastikan folder output ada
    fs::create_dir_all(output_path.parent().unwrap())
        .context("Gagal membuat direktori output")?;

    fs::write(output_path, compressed)
        .context("Gagal menulis file output")?;

    println!("✅ Konversi translation-id.json selesai!");
    Ok(())
}
