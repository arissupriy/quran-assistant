use std::fs;
use std::path::Path;
use std::collections::HashMap;
use serde_json;
use bincode;
use anyhow::{Result, Context};
use zstd::stream;

// Import model Words dan Word
#[path = "../src/data_loader/verse_by_chapter.rs"]
mod words;
use words::{Words, Word};

pub fn convert_words() -> Result<()> {
    let input_path = Path::new("output/words_formatted.json");
    let output_path = Path::new("data-bin-compressed/words_formatted.json.bin");

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent).context("Gagal membuat direktori output")?;
    }

    println!("📄 Membaca file: {:?}", input_path);
    let content = fs::read_to_string(input_path)
        .with_context(|| format!("Gagal membaca file input {:?}", input_path))?;

    // Langsung deserialisasi ke HashMap<String, Word>
    let map: HashMap<String, Word> = serde_json::from_str(&content)
        .with_context(|| "Gagal mem-parse JSON menjadi HashMap<String, Word>")?;

    let words = Words { data: map };

    let bin_data = bincode::encode_to_vec(&words, bincode::config::standard())
        .with_context(|| "Gagal men-serialize Words ke bincode")?;

    let compressed_data = stream::encode_all(&bin_data[..], 0)
        .with_context(|| "Gagal mengompresi data Words")?;

    fs::write(&output_path, compressed_data)
        .with_context(|| format!("Gagal menulis file {:?}", output_path))?;

    println!("✅ Sukses dikompresi -> {:?}", output_path);
    Ok(())
}
