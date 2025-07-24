// preprocessor/all_verse_keys_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context}; // Tambahkan 'bail'
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import struct AllVerseKeys dari data-loader
#[path = "../src/data_loader/all_verse_keys.rs"]
mod all_verse_keys_struct;
use all_verse_keys_struct::AllVerseKeys;

pub fn convert_all_verse_keys() -> Result<()> {
    let input_file = Path::new("data/all_verse_keys.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("all_verse_keys.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output untuk all_verse_keys.bin")?;

    println!("Memulai konversi data all_verse_keys.json...");

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke Vec<String>
    let keys_vec: Vec<String> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON all_verse_keys dari {:?}", input_file))?;

    let all_verse_keys = AllVerseKeys { keys: keys_vec };

    // Serialisasi AllVerseKeys ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&all_verse_keys, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi all_verse_keys dari {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Tulis data terkompresi
        .with_context(|| format!("Gagal menulis file biner all_verse_keys ke {:?}", output_file))?;

    println!("  ✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("Selesai mengonversi data all_verse_keys.");
    Ok(())
}

// preprocessor/all_verse_keys_converter.rs

// ... (kode yang sudah ada untuk fungsi convert_all_verse_keys) ...

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    // use regex::Regex; // Diperlukan jika ada pola string kompleks yang ingin divalidasi

    #[test]
    fn test_all_verse_keys_conversion_and_dynamic_validation() -> Result<()> {
        let input_file = Path::new("data/all_verse_keys.json");

        println!("\nMemulai test konversi JSON ke BIN dan validasi dinamis untuk all_verse_keys.json...");

        let content = fs::read_to_string(&input_file)
            .with_context(|| format!("Gagal membaca file JSON test {:?}", input_file))?;

        let keys_vec: Vec<String> = serde_json::from_str(&content)
            .with_context(|| format!("Gagal mendeserialisasi JSON all_verse_keys dari {:?}", input_file))?;

        let all_verse_keys = AllVerseKeys { keys: keys_vec };

        let bin_data = bincode::encode_to_vec(&all_verse_keys, bincode::config::standard())
            .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;

        let _compressed_data = stream::encode_all(&bin_data[..], 0)
            .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;

        // --- Validasi Konten Dinamis ---
        if all_verse_keys.keys.is_empty() {
            bail!("File all_verse_keys.json kosong: tidak ada kunci ayat ditemukan.");
        }

        // Validasi beberapa elemen pertama
        if all_verse_keys.keys.get(0) != Some(&"1:1".to_string()) {
            bail!("Kunci ayat pertama tidak sesuai harapan: {:?}", all_verse_keys.keys.get(0));
        }
        if all_verse_keys.keys.get(6) != Some(&"1:7".to_string()) {
            bail!("Kunci ayat ketujuh tidak sesuai harapan: {:?}", all_verse_keys.keys.get(6));
        }
        if all_verse_keys.keys.get(7) != Some(&"2:1".to_string()) {
            bail!("Kunci ayat kedelapan tidak sesuai harapan: {:?}", all_verse_keys.keys.get(7));
        }

        // **** PERBAIKAN DI SINI ****
        // Loop ini harus mengiterasi all_verse_keys.keys (Vec<String>), bukan all_verse_keys.map
        for verse_key in &all_verse_keys.keys { // Mengiterasi langsung Vec<String>
            if verse_key.is_empty() {
                bail!("Kunci ayat kosong di daftar all_verse_keys: {}", verse_key);
            }
            // Anda bisa menambahkan validasi format kunci ayat (misalnya, harus "X:Y") di sini
            // if !Regex::new(r"^\d+:\d+$")?.is_match(verse_key) {
            //     bail!("Format kunci ayat tidak valid: {}", verse_key);
            // }
        }

        // Asersi terakhir: Pastikan jumlah total kunci ayat sesuai harapan (jika Anda tahu jumlah pastinya, e.g., 6236)
        // if all_verse_keys.keys.len() != 6236 {
        //     bail!("Jumlah total kunci ayat tidak sesuai harapan: ditemukan {}, diharapkan 6236.", all_verse_keys.keys.len());
        // }

        println!("✅ Berhasil menguji konversi dan validasi mendalam untuk all_verse_keys.json.");

        Ok(())
    }
}