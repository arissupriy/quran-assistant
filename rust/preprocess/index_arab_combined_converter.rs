use std::fs; // Tambahkan ini jika belum ada
use std::path::Path;
use serde_json;
use bincode; // Untuk serialisasi biner
use anyhow::{Result, Context}; // Untuk penanganan error
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Impor struct dari modul data_loader
#[path = "../src/data_loader/index_arab_combined.rs"] // <--- Pastikan path ini benar
mod index_arab_combined_struct;
use index_arab_combined_struct::{CombinedIndex}; // Impor struct yang diperlukan

// Ubah nama fungsi dari main menjadi pub fn convert_index_arab_combined
pub fn convert_index_arab_combined() -> Result<()> {
    // Definisikan jalur file input
    let input_file = Path::new("data/index_arab_combined.json");
    // Definisikan direktori output ke 'data-bin-compressed/'
    let output_dir = Path::new("data-bin-compressed/");
    let output_file = output_dir.join("index_arab_combined.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk index_arab_combined.bin")?;

    println!("Memulai konversi data index_arab_combined.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke struct CombinedIndex
    let data_to_convert: CombinedIndex = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON index_arab_combined dari {:?}", input_file))?;
    

    // Serialisasi data ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&data_to_convert, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi valid-matching-ayah dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner index_arab_combined ke {:?}", output_file))?;

    println!("   ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data index_arab_combined.");
    Ok(())
}