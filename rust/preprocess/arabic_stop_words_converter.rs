use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct AyahPhraseMap dari data-loader
#[path = "../src/data_loader/arabic_stop_words.rs"]
mod arabic_stop_words_struct;
use arabic_stop_words_struct::ArabicStopWords;

pub fn convert_arabic_stop_words() -> Result<()> {
    let input_file = Path::new("data/stop_words_arabic.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("stop_words_arabic.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk arabic_stop_words.bin")?;

    println!("Memulai konversi data arabic_stop_words.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke Vec<String>
    let raw_stop_words: Vec<String> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON arabic_stop_words dari {:?}", input_file))?;

    // Bungkus Vec<String> ke dalam struct ArabicStopWords Anda
    let arabic_stop_words_data = ArabicStopWords {
        stop_words: raw_stop_words,
    };

    // Serialisasi struct ArabicStopWords ke bincode
    // Pastikan struct ArabicStopWords memiliki derive [Encode]
    let bin_data = bincode::encode_to_vec(&arabic_stop_words_data, bincode::config::standard())
        .context(format!("Gagal mengkodekan ArabicStopWords ke bincode dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data terkompresi ke file output
    fs::write(&output_file, compressed_data) // <-- Tulis compressed_data
        .with_context(|| format!("Gagal menulis file biner ke {:?}", output_file))?;

    println!("Konversi arabic_stop_words.json selesai. File bin: {:?}", output_file);
    Ok(())
}