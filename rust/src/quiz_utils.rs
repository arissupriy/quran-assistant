// src/ffi/quiz_generator/quiz_utils.rs

use crate::data_loader::quiz_models::{QuizFilter, QuizScope};
use crate::data_loader::verse_by_chapter::{Verse, Word};
use crate::GLOBAL_DATA;
use anyhow::{bail, Result};
use log::warn;
use rand::{prelude::*, thread_rng};
use regex::Regex;
use std::collections::{HashMap, HashSet};
use strsim::levenshtein;

//======================================================================
// FUNGSI PUBLIK (API untuk modul kuis lain)
//======================================================================

lazy_static::lazy_static! {
    static ref AYAH_NUMBER_REGEX: Regex = Regex::new(
        r"^[\p{N}۰-۹٠-٩]+[\.\:\)\-–—]?\s*"
    ).unwrap();
}

pub fn remove_ayah_number(text: &str) -> String {
    AYAH_NUMBER_REGEX.replace(text.trim_start(), "").to_string()
}


pub fn find_valid_long_verse(
    keys_in_scope: &[String],
    min_word_count: usize,
) -> Option<&'static Verse> {
    let mut rng = thread_rng();
    let mut shuffled_keys = keys_in_scope.to_vec();
    shuffled_keys.shuffle(&mut rng);

    for key in &shuffled_keys {
        if let Some(verse) = get_verse_details_by_key(key) {
            let word_count = verse
                .word_ids
                .iter()
                .filter(|id| GLOBAL_DATA.words.data.contains_key(*id))
                .count();

            if word_count >= min_word_count {
                return Some(verse);
            }
        }
    }

    None
}

pub fn get_verse_details_by_key(verse_key: &str) -> Option<&'static Verse> {
    let parts: Vec<&str> = verse_key.split(':').collect();
    if parts.len() != 2 {
        return None;
    }
    let chapter_id: u32 = parts[0].parse().ok()?;
    let verse_number: u32 = parts[1].parse().ok()?;

    GLOBAL_DATA
        .verses
        .get(&chapter_id)?
        .iter()
        .find(|v| v.verse_number == verse_number)
}

pub fn get_decoy_verses(
    count: usize,
    correct_answer_key: &str,
    keys_in_scope: &[String],
) -> Vec<&'static Verse> {
    let mut decoys = Vec::with_capacity(count);
    let mut used_keys = HashSet::new();
    used_keys.insert(correct_answer_key.to_string());

    if let Some(matching_ayahs) = GLOBAL_DATA.valid_matching_ayah.map.get(correct_answer_key) {
        for matched_ayah_obj in matching_ayahs {
            let current_decoy_key = &matched_ayah_obj.matched_ayah_key;
            if keys_in_scope.contains(current_decoy_key) && !used_keys.contains(current_decoy_key) {
                if let Some(verse) = get_verse_details_by_key(current_decoy_key) {
                    decoys.push(verse);
                    used_keys.insert(current_decoy_key.to_string());
                    if decoys.len() == count {
                        return decoys;
                    }
                }
            }
        }
    }

    if let Some(correct_details) = get_verse_details_by_key(correct_answer_key) {
        let mut smart_decoy_candidates: Vec<(&'static Verse, f32)> = Vec::new();

        for key in keys_in_scope {
            if used_keys.contains(key) {
                continue;
            }

            if let Some(candidate_verse) = get_verse_details_by_key(key) {
                let similarity_score =
                    calculate_verse_similarity(correct_details, candidate_verse);

                if similarity_score > 0.4 && similarity_score < 0.95 {
                    smart_decoy_candidates.push((candidate_verse, similarity_score));
                }
            }
        }

        smart_decoy_candidates
            .sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        for (candidate_verse, _score) in smart_decoy_candidates {
            if !used_keys.contains(&candidate_verse.verse_key) {
                decoys.push(candidate_verse);
                used_keys.insert(candidate_verse.verse_key.clone());
                if decoys.len() == count {
                    return decoys;
                }
            }
        }
    }

    while decoys.len() < count {
        if let Some(random_verse) = get_random_unique_verse(&mut used_keys, keys_in_scope) {
            decoys.push(random_verse);
        } else {
            warn!("QuizGen: Tidak dapat menemukan pengecoh acak unik tambahan dalam cakupan.");
            break;
        }
    }

    decoys
}

pub fn find_valid_question_verse(keys_in_scope: Vec<String>) -> Option<&'static Verse> {
    let mut rng = thread_rng();
    if keys_in_scope.is_empty() {
        return None;
    }
    let text_map: HashMap<String, String> = keys_in_scope
    .iter()
    .filter_map(|key| get_text_for_key(key).map(|text| (key.clone(), text)))
    .collect();
    let mut text_counts: HashMap<&str, u32> = HashMap::new();
    for text in text_map.values() {
        *text_counts.entry(text).or_insert(0) += 1;
    }
    let mut shuffled_keys: Vec<&String> = keys_in_scope.iter().collect();
    shuffled_keys.shuffle(&mut rng);
    for key in shuffled_keys {
        if let Some(text) = text_map.get(key.as_str()) {
            if text_counts.get(text.as_str()) == Some(&1) {
                if get_next_verse_key(key).is_some() {
                    if let Some(verse) = get_verse_details_by_key(key) {
                        return Some(verse);
                    }
                }
            }
        }
    }
    None
}

pub fn get_next_verse_key(verse_key: &str) -> Option<String> {
    let parts: Vec<&str> = verse_key.split(':').collect();
    if parts.len() != 2 {
        return None;
    }
    let chapter_id: u32 = parts[0].parse().ok()?;
    let verse_number: u32 = parts[1].parse().ok()?;
    let next_verse_number = verse_number + 1;
    if let Some(chapter_details) = GLOBAL_DATA
        .chapters
        .chapters
        .iter()
        .find(|c| c.id == chapter_id)
    {
        if next_verse_number <= chapter_details.verses_count {
            return Some(format!("{}:{}", chapter_id, next_verse_number));
        }
    }
    None
}

pub fn get_text_for_key(verse_key: &str) -> Option<String> {
    let verse = GLOBAL_DATA.verses
        .values()
        .flat_map(|v| v.iter())
        .find(|v| v.verse_key == verse_key)?;

    let words: Vec<&Word> = verse.word_ids
        .iter()
        .filter_map(|id| GLOBAL_DATA.words.data.get(id))
        .collect();

    if words.is_empty() {
        return None;
    }

    Some(
        words.iter()
            .map(|w| w.text_uthmani.as_str())
            .collect::<Vec<_>>()
            .join(" ")
    )
}

pub fn get_prev_verse_key(verse_key: &str) -> Option<String> {
    let parts: Vec<&str> = verse_key.split(':').collect();
    if parts.len() != 2 {
        return None;
    }
    let chapter_id: u32 = parts[0].parse().ok()?;
    let verse_number: u32 = parts[1].parse().ok()?;
    let prev_verse_number = verse_number.checked_sub(1)?;

    if prev_verse_number == 0 {
        return None; // tidak ada ayat sebelum 1
    }

    Some(format!("{}:{}", chapter_id, prev_verse_number))
}

pub fn get_contextual_decoys(
    target_prev_word: Option<String>,
    word_count: usize,
    correct_fragment: &str,
    available_keys: &[String],
) -> Vec<String> {
    use crate::GLOBAL_DATA;
    use rand::seq::SliceRandom;
    use std::collections::HashSet;

    let mut decoys = HashSet::new();
    let mut rng = rand::thread_rng();

    let Some(target_prev) = target_prev_word else {
        return vec![];
    };

    for key in available_keys {
        // Parse "2:5" → (chapter_id, verse_number)
        let parts: Vec<&str> = key.split(':').collect();
        if parts.len() != 2 {
            continue;
        }

        let chapter_id: u32 = match parts[0].parse() {
            Ok(id) => id,
            Err(_) => continue,
        };
        let verse_number: u32 = match parts[1].parse() {
            Ok(n) => n,
            Err(_) => continue,
        };

        if let Some(verses) = GLOBAL_DATA.verses.get(&chapter_id) {
            if let Some(verse) = verses.iter().find(|v| v.verse_number == verse_number) {
                let words: Vec<_> = verse
                    .word_ids
                    .iter()
                    .filter_map(|id| GLOBAL_DATA.words.data.get(id))
                    .collect();

                for i in 0..words.len().saturating_sub(word_count) {
                    if words[i].text_uthmani == target_prev {
                        let candidate_words = &words[i + 1..i + 1 + word_count];
                        let candidate_text = candidate_words
                            .iter()
                            .map(|w| w.text_uthmani.as_str())
                            .collect::<Vec<_>>()
                            .join(" ");
                        let norm = crate::quiz_utils::normalize_text(&candidate_text);
                        if norm != correct_fragment {
                            decoys.insert(norm);
                        }
                    }
                }
            }
        }
    }

    let mut result: Vec<String> = decoys.into_iter().collect();
    result.shuffle(&mut rng);
    result
}




fn get_random_unique_verse(
    used_keys: &mut HashSet<String>,
    scope_keys: &[String],
) -> Option<&'static Verse> {
    let mut rng = thread_rng();
    let mut shuffled_scope_keys = scope_keys.to_vec();
    shuffled_scope_keys.shuffle(&mut rng);

    for random_key in shuffled_scope_keys {
        if !used_keys.contains(&random_key) {
            if let Some(verse) = get_verse_details_by_key(&random_key) {
                used_keys.insert(random_key);
                return Some(verse);
            }
        }
    }
    None
}

fn calculate_verse_similarity(verse1: &'static Verse, verse2: &'static Verse) -> f32 {
    if verse1.verse_key == verse2.verse_key {
        return 0.0;
    }

    let words1: Vec<String> = verse1.word_ids.iter()
        .filter_map(|id| GLOBAL_DATA.words.data.get(id))
        .map(|w| w.text_uthmani.clone())
        .collect();

    let words2: Vec<String> = verse2.word_ids.iter()
        .filter_map(|id| GLOBAL_DATA.words.data.get(id))
        .map(|w| w.text_uthmani.clone())
        .collect();

    let joined1 = normalize_text(&words1.join(" "));
    let joined2 = normalize_text(&words2.join(" "));

    let set1: HashSet<String> = get_words_from_fragment_string(&joined1).into_iter().collect();
    let set2: HashSet<String> = get_words_from_fragment_string(&joined2).into_iter().collect();

    let jaccard = calculate_jaccard_similarity(&set1, &set2);
    let levenshtein = calculate_normalized_levenshtein(&joined1, &joined2);

    // Kombinasi berbobot
    (jaccard * 0.6) + (levenshtein * 0.4)
}

fn calculate_jaccard_similarity(set1: &HashSet<String>, set2: &HashSet<String>) -> f32 {
    if set1.is_empty() && set2.is_empty() {
        return 1.0;
    }
    let intersection = set1.intersection(set2).count();
    let union = set1.len() + set2.len() - intersection;

    if union == 0 {
        return 0.0;
    }
    intersection as f32 / union as f32
}



/// Mendapatkan semua verse_key berdasarkan cakupan (QuizScope)
pub fn get_verse_keys_in_scope(filter: &QuizFilter) -> Result<Vec<String>> {
    let mut keys = Vec::new();

    for (chapter_id, verses) in GLOBAL_DATA.verses.iter() {
        for verse in verses {
            let include = match &filter.scope {
                QuizScope::BySurah { surah_id } => chapter_id == surah_id,
                QuizScope::ByJuz { juz_numbers } => {
                    juz_numbers.contains(&verse.juz_number)
                }
                QuizScope::All => true,
            };

            if include {
                keys.push(verse.verse_key.clone());
            }
        }
    }

    Ok(keys)
}

/// Membagi teks Utsmani menjadi kata-kata individual berbasis spasi.
/// Biasanya digunakan untuk deduplikasi opsi jawaban kuis.
pub fn get_words_from_fragment_string(fragment: &str) -> Vec<String> {
    fragment
        .split_whitespace()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

pub fn remove_arabic_numbers(input: &str) -> String {
    input
        .chars()
        .filter(|c| !matches!(c, '٠'..='٩')) // Unicode Arabic-Indic digits
        .collect()
}

pub fn normalize_text(input: &str) -> String {
    let no_numbers = remove_arabic_numbers(input);
    no_numbers
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

pub fn get_decoy_fragments(
    count: usize,
    word_count: usize,
    correct_text: &str,
    keys_in_scope: &[String],
) -> Vec<String> {
    let mut rng = thread_rng();
    let mut candidates = Vec::new();
    let normalized_target = normalize_text(correct_text);
    let mut used_texts = HashSet::new();
    used_texts.insert(normalized_target.clone());

    for key in keys_in_scope {
        if let Some(verse) = get_verse_details_by_key(key) {
            let words: Vec<String> = verse
                .word_ids
                .iter()
                .filter_map(|id| GLOBAL_DATA.words.data.get(id))
                .map(|w| w.text_uthmani.clone())
                .collect();

            if words.len() < word_count {
                continue;
            }

            for i in 0..=words.len() - word_count {
                let slice = &words[i..i + word_count];
                let raw = slice.join(" ");
                let normalized = normalize_text(&raw);

                if !used_texts.contains(&normalized) {
                    candidates.push(normalized.clone());
                    used_texts.insert(normalized);
                    if candidates.len() == count {
                        return candidates;
                    }
                }
            }
        }
    }

    candidates.shuffle(&mut rng);
    candidates.truncate(count);
    candidates
}



fn calculate_normalized_levenshtein(s1: &str, s2: &str) -> f32 {
    let distance = levenshtein(s1, s2);
    let max_len = s1.len().max(s2.len());
    if max_len == 0 {
        return 1.0;
    }
    1.0 - (distance as f32 / max_len as f32)
}
