// preprocessor/chapters_converter.rs

use std::fs;
use std::path::Path;
use serde_json;
use bincode;
use anyhow::{Result, Context, bail};
use zstd::stream; // <--- TAMBAHKAN INI UNTUK KOMPRESI

// Import the Chapter struct from the data_loader module
#[path = "../src/data_loader/chapters.rs"]
mod chapter_struct;
use chapter_struct::Chapter;

pub fn convert_chapters() -> Result<()> {
    let input_file = Path::new("data/chapters.json");
    let output_dir = Path::new("data-bin-compressed/"); // Output ke direktori 'data/'
    let output_file = output_dir.join("chapters.bin");

    // Pastikan direktori output ada
    fs::create_dir_all(output_dir).context("Gagal membuat direktori output")?;

    println!("Memproses {:?}...", input_file);

    // Baca konten file JSON
    let json_data = fs::read_to_string(&input_file)
        .with_context(|| format!("Gagal membaca file JSON dari {:?}", input_file))?;

    // Deserialisasi JSON ke Vec<Chapter>
    let chapters: Vec<Chapter> = serde_json::from_str(&json_data)
        .with_context(|| format!("Gagal mengurai JSON dari {:?}", input_file))?;

    // Serialisasi Vec<Chapter> ke biner menggunakan bincode
    let bin_data = bincode::encode_to_vec(&chapters, bincode::config::standard())
        .with_context(|| format!("Gagal menserialisasi {:?}", input_file))?;

    // --- LANGKAH BARU: KOMPRESI DENGAN ZSTD ---
    let compressed_data = stream::encode_all(&bin_data[..], 0) // Level kompresi 0 (tercepat)
        .context(format!("Gagal mengkompresi data untuk {:?}", input_file))?;
    // --- AKHIR LANGKAH BARU ---

    // Tulis data biner yang SUDAH TERKOMPRESI ke dalam file
    fs::write(&output_file, compressed_data) // <--- Gunakan compressed_data di sini
        .with_context(|| format!("Gagal menulis {:?}", output_file))?;

    println!("✅ Berhasil mengonversi dan mengkompresi {:?} -> {:?}", input_file, output_file);
    println!("🚀 File bab berhasil dikonversi dan dikompresi!");

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*; // Impor semua item dari modul induk
    use std::fs;
    use anyhow::{Result, Context, bail};
    use zstd::stream; // <--- TAMBAHKAN INI UNTUK UJI KOMPRESI

    #[test]
    fn test_chapters_conversion_and_dynamic_validation() -> Result<()> {
        let input_file = Path::new("data/chapters.json");

        println!("\nMemulai test konversi JSON ke BIN dan validasi dinamis untuk chapters.json...");

        let content = fs::read_to_string(&input_file)
            .with_context(|| format!("Gagal membaca file JSON test {:?}", input_file))?;

        // Deserialisasi JSON ke Vec<Chapter>
        let chapters: Vec<Chapter> = serde_json::from_str(&content)
            .with_context(|| format!("Gagal mendeserialisasi JSON dari {:?}", input_file))?;

        // Serialisasi struct Vec<Chapter> ke biner
        let bin_data = bincode::encode_to_vec(&chapters, bincode::config::standard())
            .with_context(|| format!("Gagal menserialisasi ke biner dari {:?}", input_file))?;
        
        // --- LANGKAH BARU: UJI KOMPRESI ---
        let _compressed_data = stream::encode_all(&bin_data[..], 0) // Uji kompresi
            .context(format!("Gagal mengkompresi data untuk test {:?}", input_file))?;
        // --- AKHIR LANGKAH BARU ---

        // --- Validasi Konten Dinamis ---
        if chapters.is_empty() {
            bail!("File chapters.json kosong: tidak ada bab ditemukan.");
        }

        let mut expected_id = 1;
        for chapter in &chapters {
            // Validasi ID bab berurutan
            if chapter.id != expected_id {
                bail!("ID bab tidak berurutan: Diharapkan {}, ditemukan {} untuk bab {}",
                    expected_id, chapter.id, chapter.name_simple);
            }

            // Validasi keberadaan dan konsistensi data penting
            if chapter.name_simple.is_empty() {
                bail!("Nama sederhana kosong untuk bab {}", chapter.id);
            }
            if chapter.name_complex.is_empty() {
                bail!("Nama kompleks kosong untuk bab {}", chapter.id);
            }
            if chapter.name_arabic.is_empty() {
                bail!("Nama Arab kosong untuk bab {}", chapter.id);
            }
            if chapter.revelation_place.is_empty() {
                bail!("Tempat wahyu kosong untuk bab {}", chapter.id);
            }
            if chapter.verses_count == 0 {
                bail!("Jumlah ayat nol untuk bab {}", chapter.id);
            }

            // Validasi array pages
            if chapter.pages.len() != 2 {
                bail!("Array pages tidak memiliki 2 elemen untuk bab {}", chapter.id);
            }
            if chapter.pages[0] == 0 || chapter.pages[1] == 0 {
                bail!("Nomor halaman nol untuk bab {}", chapter.id);
            }
            if chapter.pages[0] > chapter.pages[1] {
                bail!("Halaman awal lebih besar dari halaman akhir untuk bab {}", chapter.id);
            }

            // Validasi translatedName
            if chapter.translated_name.language_name.is_empty() {
                bail!("Nama bahasa terjemahan kosong untuk bab {}", chapter.id);
            }
            if chapter.translated_name.name.is_empty() {
                bail!("Nama terjemahan kosong untuk bab {}", chapter.id);
            }
            // Contoh validasi nilai spesifik jika diperlukan
            if chapter.id == 1 && chapter.name_simple != "Al-Fatihah" {
                 bail!("Nama Al-Fatihah tidak cocok untuk bab 1");
            }

            expected_id += 1;
        }

        // Asersi terakhir: Pastikan jumlah total bab sesuai harapan (jika Anda tahu)
        assert_eq!(chapters.len(), 114, "Jumlah total bab tidak sesuai harapan."); // Total bab di Al-Qur'an adalah 114

        println!("✅ Berhasil menguji konversi dan validasi mendalam untuk chapters.json.");

        Ok(())
    }
}