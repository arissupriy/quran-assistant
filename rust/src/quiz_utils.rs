// src/ffi/quiz_generator/quiz_utils.rs

use crate::data_loader::ayah_texts::AyahText;
use crate::data_loader::quiz_models::{QuizFilter, QuizScope};
use crate::data_loader::verse_by_chapter::Verse;
use crate::GLOBAL_DATA;
use anyhow::{bail, Result};
use log::info;
use std::collections::{HashMap, HashSet};

// --- PERBAIKAN FINAL DI SINI ---
// Impor "prelude" untuk mendapatkan semua trait DAN fungsi umum dari `rand`
// termasuk Rng, SliceRandom, dan juga thread_rng().
use rand::{prelude::*, thread_rng}; // Pastikan thread_rng diimpor secara eksplisit

//======================================================================
// FUNGSI PUBLIK (API untuk modul kuis lain)
//======================================================================

pub fn find_valid_long_verse(keys_in_scope: &[String], min_word_count: usize) -> Option<&'static Verse> {
    let mut rng = thread_rng(); // Perbaikan: Gunakan thread_rng()
    let mut shuffled_keys = keys_in_scope.to_vec();
    shuffled_keys.shuffle(&mut rng);

    for key in &shuffled_keys {
        if let Some(verse) = get_verse_details_by_key(key) {
            if verse.words.len() >= min_word_count {
                // Untuk kuis fragmen, keunikan teks tidak sekrusial kuis lanjut ayat,
                // jadi kita langsung kembalikan ayat yang memenuhi syarat panjang.
                return Some(verse);
            }
        }
    }
    None
}

/// Mengambil detail `Verse` lengkap (termasuk semua kata) berdasarkan `verse_key`.
pub fn get_verse_details_by_key(verse_key: &str) -> Option<&'static Verse> {
    let parts: Vec<&str> = verse_key.split(':').collect();
    if parts.len() != 2 { return None; }
    let chapter_id: u32 = parts[0].parse().ok()?;
    let verse_number: u32 = parts[1].parse().ok()?;
    
    GLOBAL_DATA.verses_by_chapter
        .get(&chapter_id)?
        .iter()
        .find(|v| v.verse_number == verse_number)
}

/// Menghasilkan sejumlah ayat pengecoh (decoy) yang unik.
pub fn get_decoy_verses(count: usize, correct_answer_key: &str) -> Vec<&'static AyahText> {
    let mut decoys = Vec::with_capacity(count);
    let mut used_keys = HashSet::new();
    used_keys.insert(correct_answer_key.to_string());

    while decoys.len() < count {
        if let Some(verse) = get_random_verse() {
            if used_keys.insert(verse.verse_key.clone()) {
                decoys.push(verse);
            }
        } else {
            // Jika tidak bisa mendapatkan ayat acak lagi, hentikan
            break; 
        }
    }
    decoys
}

/// Menghasilkan pengecoh berupa potongan kata acak dari ayat lain.
pub fn get_decoy_fragments(count: usize, fragment_word_count: usize, correct_fragment: &str) -> Vec<String> {
    let mut decoys = Vec::with_capacity(count);
    let mut used_fragments = std::collections::HashSet::new();
    used_fragments.insert(correct_fragment.to_string());

    let all_keys = &GLOBAL_DATA.all_verse_keys.keys;
    let mut attempts = 0;
    // Tentukan batas percobaan yang wajar, misalnya 10x dari jumlah yang diminta
    let max_attempts_for_decoys = count * 10;

    while decoys.len() < count && attempts < max_attempts_for_decoys {
        attempts += 1; // Tingkatkan attempts di setiap iterasi loop
        
        if let Some(random_verse) = find_valid_long_verse(all_keys, fragment_word_count + 1) {
            if random_verse.words.len() > fragment_word_count {
                let mut rng = thread_rng();
                // Pastikan `start_index` tidak melewati batas.
                // `random_verse.words.len() - fragment_word_count` bisa jadi 0 jika ukurannya pas.
                // `gen_range(a..=b)` membutuhkan `a <= b`.
                let max_range_for_start_index = random_verse.words.len().saturating_sub(fragment_word_count);

                if max_range_for_start_index == 0 {
                    // Jika ayat terlalu pendek untuk diambil fragmen acak dengan ukuran yang diminta
                    continue; 
                }
                
                let start_index = rng.gen_range(0..max_range_for_start_index); 
                let end_index = start_index + fragment_word_count;
                
                // Pastikan `end_index` tidak keluar dari batas, meskipun seharusnya sudah dijamin oleh `max_range_for_start_index`
                if end_index > random_verse.words.len() {
                    // Ini seharusnya tidak terpicu jika perhitungan `start_index` benar,
                    // tapi sebagai sanity check tidak ada salahnya.
                    continue; 
                }

                let fragment_text = random_verse.words[start_index..end_index]
                    .iter()
                    .map(|w| w.text_uthmani.as_str())
                    .collect::<Vec<_>>()
                    .join(" ");

                // Jika fragmen baru berhasil ditambahkan, artinya unik
                if used_fragments.insert(fragment_text.clone()) {
                    decoys.push(fragment_text);
                }
            }
        }
        // Jika find_valid_long_verse mengembalikan None, loop tetap berlanjut
        // dan `attempts` akan terus bertambah, mencegah infinite loop.
    }

    // DEBUGGING: Tambahkan log untuk melihat berapa banyak pengecoh yang berhasil didapat
    info!("DEBUG: get_decoy_fragments mencoba {} kali, berhasil mengumpulkan {} dari {} pengecoh.", attempts, decoys.len(), count);

    decoys // Mengembalikan apa pun yang berhasil dikumpulkan
}

/// Mengambil semua kunci ayat ('verse_key') dalam cakupan (scope) yang ditentukan.
pub fn get_verse_keys_in_scope(filter: &QuizFilter) -> Result<Vec<String>> {
    let engine_data = &GLOBAL_DATA;
    match &filter.scope {
        QuizScope::All => Ok(engine_data.all_verse_keys.keys.clone()),
        QuizScope::BySurah { surah_id } => {
            let prefix = format!("{}:", surah_id);
            let keys = engine_data.ayah_texts.texts
                .iter()
                .filter(|at| at.verse_key.starts_with(&prefix))
                .map(|at| at.verse_key.clone())
                .collect();
            Ok(keys)
        }
        QuizScope::ByJuz { juz_numbers } => {
            if juz_numbers.is_empty() || juz_numbers.len() > 2 {
                bail!("Parameter Juz tidak valid. Harus berisi 1 atau 2 elemen.");
            }
            let start_juz = juz_numbers[0];
            let end_juz = if juz_numbers.len() == 2 { juz_numbers[1] } else { start_juz };
            if start_juz == 0 || end_juz == 0 || start_juz > end_juz || end_juz > 30 {
                bail!("Nomor Juz tidak valid. Harus antara 1 dan 30.");
            }
            let mut keys_in_juz = Vec::new();
            for juz_num in start_juz..=end_juz {
                if let Some(juz_data) = engine_data.juzs.juzs.iter().find(|j| j.juz_number == juz_num) {
                    for (chapter_str, verse_range_str) in &juz_data.verse_mapping {
                        // Error handling untuk parse chapter_id
                        let chapter_id: u32 = chapter_str.parse().map_err(|e| anyhow::anyhow!("Gagal parse chapter_id '{}': {}", chapter_str, e))?;
                        let range_parts: Vec<&str> = verse_range_str.split('-').collect();
                        if range_parts.len() == 2 {
                            // Error handling untuk parse start_verse dan end_verse
                            let start_verse: u32 = range_parts[0].parse().map_err(|e| anyhow::anyhow!("Gagal parse start_verse '{}': {}", range_parts[0], e))?;
                            let end_verse: u32 = range_parts[1].parse().map_err(|e| anyhow::anyhow!("Gagal parse end_verse '{}': {}", range_parts[1], e))?;
                            for verse_num in start_verse..=end_verse {
                                keys_in_juz.push(format!("{}:{}", chapter_id, verse_num));
                            }
                        } else {
                            // Error handling jika format range_parts tidak sesuai
                            bail!("Format range_parts tidak valid untuk {}:{}", chapter_str, verse_range_str);
                        }
                    }
                } else {
                    // Jika data juz tidak ditemukan (seharusnya tidak terjadi jika data lengkap)
                    bail!("Data Juz {} tidak ditemukan.", juz_num);
                }
            }
            Ok(keys_in_juz)
        }
    }
}

/// Mencari kandidat ayat soal yang valid (teksnya unik & punya lanjutan) dari dalam cakupan tertentu.
pub fn find_valid_question_verse(keys_in_scope: Vec<String>) -> Option<&'static AyahText> {
    let mut rng = thread_rng(); // Perbaikan: Gunakan thread_rng()
    if keys_in_scope.is_empty() { return None; }
    let text_map: HashMap<_, _> = keys_in_scope.iter()
        .filter_map(|key| get_text_for_key(key).map(|text| (key.as_str(), text)))
        .collect();
    let mut text_counts: HashMap<&str, u32> = HashMap::new();
    for text in text_map.values() {
        *text_counts.entry(text).or_insert(0) += 1;
    }
    let mut shuffled_keys: Vec<&String> = keys_in_scope.iter().collect();
    shuffled_keys.shuffle(&mut rng); // <-- Sekarang akan berfungsi
    for key in shuffled_keys {
        if let Some(text) = text_map.get(key.as_str()) {
            if text_counts.get(text) == Some(&1) {
                if get_next_verse_key(key).is_some() {
                    if let Some(verse) = GLOBAL_DATA.ayah_texts.texts.iter().find(|at| &at.verse_key == key) {
                        return Some(verse);
                    }
                }
            }
        }
    }
    None
}

/// Mendapatkan teks Utsmani dari sebuah verse_key.
pub fn get_text_for_key(verse_key: &str) -> Option<&'static str> {
    GLOBAL_DATA.ayah_texts.texts
        .iter()
        .find(|at| at.verse_key == verse_key)
        .map(|at| at.text_uthmani.as_str())
}

/// Mendapatkan kunci ayat selanjutnya dalam surah yang sama.
pub fn get_next_verse_key(verse_key: &str) -> Option<String> {
    let parts: Vec<&str> = verse_key.split(':').collect();
    if parts.len() != 2 { return None; }
    let chapter_id: u32 = parts[0].parse().ok()?;
    let verse_number: u32 = parts[1].parse().ok()?;
    let next_verse_number = verse_number + 1;
    if let Some(chapter_details) = GLOBAL_DATA.chapters.chapters.iter().find(|c| c.id == chapter_id) {
        if next_verse_number <= chapter_details.verses_count {
            return Some(format!("{}:{}", chapter_id, next_verse_number));
        }
    }
    None
}

//======================================================================
// FUNGSI INTERNAL
//======================================================================

/// Mengambil satu `AyahText` acak dari seluruh Al-Qur'an.
fn get_random_verse() -> Option<&'static AyahText> {
    let engine_data = &GLOBAL_DATA;
    // --- PERUBAHAN DI SINI ---
    let mut rng = thread_rng(); // Perbaikan: Gunakan thread_rng()
    if let Some(random_key) = engine_data.all_verse_keys.keys.choose(&mut rng) {
        engine_data.ayah_texts.texts.iter().find(|at| &at.verse_key == random_key)
    } else {
        None
    }
}