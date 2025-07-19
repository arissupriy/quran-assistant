use flutter_rust_bridge::frb;
use rand::Rng;
use rand::{seq::SliceRandom, thread_rng};

use crate::data_loader::quiz_models::{
    QuizFilter, QuizGenerationError, QuizGenerationResult, QuizOption, QuizQuestion, QuizQuestions,
};
use crate::quiz_utils::{
    self, get_text_for_key, get_verse_details_by_key, get_verse_keys_in_scope,
};
use crate::GLOBAL_DATA;

const NUM_VERSES: usize = 5; // Jumlah ayat dalam satu puzzle urutan

#[frb]
pub fn generate_batch_verse_order_quizzes(filter: QuizFilter) -> QuizQuestions {
    let mut questions = Vec::with_capacity(filter.quiz_count as usize);
    let mut attempts = 0;

    while questions.len() < filter.quiz_count as usize && attempts < filter.quiz_count as usize * 3
    {
        if let Some(q) = generate_single_verse_order_quiz(&filter) {
            questions.push(q);
        }
        attempts += 1;
    }

    QuizQuestions { questions }
}

fn generate_single_verse_order_quiz(filter: &QuizFilter) -> Option<QuizQuestion> {
    let keys_in_scope = quiz_utils::get_verse_keys_in_scope(filter).ok()?;
    if keys_in_scope.len() < NUM_VERSES {
        return None;
    }

    let mut rng = thread_rng();
    let max_start = keys_in_scope.len().saturating_sub(NUM_VERSES);
    let start_idx = rng.gen_range(0..=max_start);
    let slice_keys = &keys_in_scope[start_idx..start_idx + NUM_VERSES];

    let mut verse_pairs: Vec<(String, String)> = Vec::with_capacity(NUM_VERSES);
    for verse_key in slice_keys {
        let raw = quiz_utils::get_text_for_key(verse_key)?;
        let clean = quiz_utils::remove_ayah_number(&raw);
        verse_pairs.push((verse_key.clone(), clean));
    }

    if verse_pairs.len() != NUM_VERSES {
        return None;
    }

    let correct_keys: Vec<String> = verse_pairs.iter().map(|(k, _)| k.clone()).collect();

    // Shuffle
    let mut shuffled = verse_pairs.clone();
    shuffled.shuffle(&mut rng);

    // Buat teks dan key yang sudah diacak
    let shuffled_texts: Vec<String> = shuffled.iter().map(|(_, text)| text.clone()).collect();
    let shuffled_keys: Vec<String> = shuffled.iter().map(|(key, _)| key.clone()).collect();

    // Hitung correct_order_indices berdasarkan posisi teks dalam verse_pairs
    let correct_order_indices: Vec<u32> = shuffled
    .iter()
    .map(|(key, _)| {
        correct_keys
            .iter()
            .position(|k| k == key)
            .unwrap_or(0) as u32
    })
    .collect();

    // Semua opsi dianggap "benar" untuk puzzle
    let options: Vec<QuizOption> = shuffled_texts
        .iter()
        .map(|text| QuizOption {
            text: text.clone(),
            is_correct: true,
        })
        .collect();

    Some(QuizQuestion {
        verse_key: slice_keys[0].clone(),
        question_text_part1: String::new(),
        question_text_part2: String::new(),
        missing_part_text: String::new(),
        options,
        correct_answer_index: 0,
        correct_order_indices: Some(correct_order_indices),
        shuffled_parts: Some(shuffled_texts),
        quiz_type: "verse_puzzle".to_string(),
        shuffled_keys: Some(shuffled_keys),
        correct_order_keys: Some(correct_keys),
    })
}

fn parse_key(key: &str) -> Option<(u32, u32)> {
    let parts: Vec<&str> = key.split(':').collect();
    if parts.len() != 2 {
        return None;
    }
    let chapter: u32 = parts[0].parse().ok()?;
    let verse: u32 = parts[1].parse().ok()?;
    Some((chapter, verse))
}
