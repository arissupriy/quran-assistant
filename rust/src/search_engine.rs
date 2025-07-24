use crate::data_loader::search_models::{InvertedIndex, Occurrence, SearchResult, WordResult};
use crate::GLOBAL_DATA;
use regex::Regex;
use std::collections::{HashMap, HashSet};

lazy_static::lazy_static! {
    static ref WORD_REGEX: Regex = Regex::new(r"\b\w+\b").unwrap();
}

#[derive(Default, Debug, Clone)]
struct VerseMatchInfo {
    occurrences: Vec<Occurrence>,
    matched_query_terms: HashSet<String>,
    term_frequencies: HashMap<String, u16>,
}

/// 🔤 Normalisasi teks Arab (tanpa harakat, dan bentuk standar)
fn normalize_arabic_text_rust(text: &str) -> String {
    let diacritics: &[char] = &[
        '\u{064B}', '\u{064C}', '\u{064D}', '\u{064E}', '\u{064F}', '\u{0650}', '\u{0651}',
        '\u{0652}', '\u{0670}', '\u{0653}', '\u{0654}', '\u{0655}', '\u{0656}', '\u{0657}',
        '\u{0658}',
    ];

    let mut cleaned = text
        .chars()
        .filter(|c| !diacritics.contains(c))
        .collect::<String>();

    let replacements = [
        ("أ", "ا"),
        ("إ", "ا"),
        ("آ", "ا"),
        ("ٱ", "ا"),
        ("ى", "ي"),
        ("ئ", "ي"),
        ("ؤ", "و"),
        ("ة", "ه"),
        ("ء", ""),
        ("ـ", ""),
    ];

    for (from, to) in replacements {
        cleaned = cleaned.replace(from, to);
    }

    cleaned.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn stem_indonesian_text_rust(text: &str) -> String {
    text.to_lowercase()
}

fn preprocess_query(query: &str) -> Result<Vec<String>, String> {
    let stop_words = &GLOBAL_DATA.arabic_stop_words.stop_words;
    let mut terms = Vec::new();

    for mat in WORD_REGEX.find_iter(query) {
        let token = mat.as_str();
        let norm = normalize_arabic_text_rust(token).to_lowercase();

        if !norm.is_empty() && !stop_words.contains(&norm) {
            terms.push(norm.clone());
        }

        let is_arabic = token.chars().any(|c| c >= '\u{0600}' && c <= '\u{06FF}');
        if !is_arabic {
            let stemmed = stem_indonesian_text_rust(token);
            if !stemmed.is_empty() && stemmed != norm {
                terms.push(stemmed);
            }
        }
    }

    Ok(terms)
}

/// 🔍 Fungsi utama pencarian
pub fn search(query_str: &str) -> Result<Vec<SearchResult>, String> {
    log::info!("🔍 Pencarian: '{}'", query_str);
    let terms = preprocess_query(query_str)?;
    if terms.is_empty() {
        return Ok(vec![]);
    }

    let index: &InvertedIndex = &GLOBAL_DATA.inverted_index;
    let mut verse_matches: HashMap<String, VerseMatchInfo> = HashMap::new();

    for term in &terms {
        if let Some(occurrences) = index.get(term) {
            for occ in occurrences {
                let entry = verse_matches.entry(occ.vk.clone()).or_default();
                entry.occurrences.push(occ.clone());
                entry.matched_query_terms.insert(term.clone());
                if let Some(tf) = occ.tf {
                    *entry.term_frequencies.entry(term.clone()).or_insert(0) += tf;
                }
            }
        }
    }

    let mut results = Vec::new();

    for (vk, info) in verse_matches {
        let score = calculate_relevance_score(&vk, &info);
        let mut words = Vec::new();

        if let Some((s, v)) = vk.split_once(':') {
            if let (Ok(surah), Ok(verse)) = (s.parse::<u32>(), v.parse::<u32>()) {
                if let Some(verses) = GLOBAL_DATA.verses.get(&surah) {
                    if let Some(verse_data) = verses.iter().find(|v| v.verse_number == verse) {
                        for word_key in &verse_data.word_ids {
                            if let Some(word) = GLOBAL_DATA.words.data.get(word_key) {
                                let norm =
                                    normalize_arabic_text_rust(&word.text_uthmani).to_lowercase();
                                let is_highlighted = terms.contains(&norm);
                                words.push(WordResult {
                                    id: word.id,
                                    position: word.position,
                                    text_uthmani: word.text_uthmani.clone(),
                                    // translation_text: word.translation.text.clone(),
                                    highlighted: is_highlighted,
                                });
                            }
                        }
                    }
                }
            }
        }

        results.push(SearchResult {
            verse_key: vk,
            score,
            words,
        });
    }

    results.sort_by(|a, b| {
        b.score
            .partial_cmp(&a.score)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                let get_surah = |k: &str| {
                    k.split(':')
                        .next()
                        .and_then(|x| x.parse::<u32>().ok())
                        .unwrap_or(u32::MAX)
                };
                get_surah(&a.verse_key).cmp(&get_surah(&b.verse_key))
            })
    });

    Ok(results)
}

fn calculate_relevance_score(_vk: &str, info: &VerseMatchInfo) -> f32 {
    info.matched_query_terms.len() as f32
}

// --- UNIT TEST DENGAN EKSPEKTASI YANG BENAR ---
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_normalization_consistency() {
        println!("Menjalankan tes normalisasi teks Arab...");

        let test_cases = vec![
            // Kasus 1: Menghapus harakat dan Dagger Alif.
            ("الرَّحْمَٰنِ", "الرحمن"),
            ("رَحْمٰن", "رحمن"),
            // Kasus 2: Menyeragamkan bentuk Alif.
            ("أَحَدٌ", "احد"),
            // Kasus 3: Memastikan kata tanpa harakat (tetapi dengan Alif standar) TIDAK berubah.
            // Ini adalah perbaikan penting pada ekspektasi tes.
            ("رحمان", "رحمان"),
            // Kasus 4: Memastikan kata yang sudah bersih sepenuhnya tidak berubah.
            ("رحمن", "رحمن"),
            // Kasus 5: Kasus kompleks
            ("بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ", "بسم الله الرحمن الرحيم"),
        ];

        for (input, expected) in test_cases {
            let actual = normalize_arabic_text_rust(input);
            assert_eq!(actual, expected, "Kegagalan pada input: '{}'", input);
        }
        println!("✅ Semua tes normalisasi kunci berhasil!");
    }
}
