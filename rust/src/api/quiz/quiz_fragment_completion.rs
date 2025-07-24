// src/ffi/quiz_generator/fragment_completion.rs

use std::collections::HashSet;

use flutter_rust_bridge::frb;
use log::{debug, error, info, warn};

use crate::data_loader::quiz_models::{
    QuizFilter, QuizGenerationError, QuizGenerationResult, QuizOption, QuizQuestion, QuizQuestions,
};
use crate::data_loader::verse_by_chapter::Word;
use crate::{quiz_utils, GLOBAL_DATA};

use rand::seq::SliceRandom;
use rand::thread_rng;
use rand::Rng;

const ANSWER_WORD_COUNT: usize = 2;

#[flutter_rust_bridge::frb(sync)]
pub fn generate_verse_fragment_quiz(filter: QuizFilter) -> QuizGenerationResult {
    info!("QuizGen: generate_verse_fragment_quiz: Fungsi dimulai.");
    let result = inner_generate_verse_fragment_quiz(filter);
    match &result.error {
        Some(e) => error!(
            "QuizGen: generate_verse_fragment_quiz selesai dengan error: {:?}",
            e
        ),
        None => info!("QuizGen: generate_verse_fragment_quiz selesai dengan sukses."),
    }
    result
}

#[frb]
pub fn generate_batch_fragment_quizzes(filter: QuizFilter) -> QuizQuestions {
    info!(
        "QuizGen: generate_batch_fragment_quizzes: Memulai batch dengan {} kuis.",
        filter.quiz_count
    );
    let mut generated_questions = Vec::with_capacity(filter.quiz_count as usize);
    for i in 0..filter.quiz_count {
        info!(
            "QuizGen: Menghasilkan kuis fragmen {} dari {}",
            i + 1,
            filter.quiz_count
        );
        let result = inner_generate_verse_fragment_quiz(filter.clone());
        if let Some(q) = result.question {
            generated_questions.push(q);
        } else {
            warn!(
                "QuizGen: Gagal membuat kuis fragmen {}: {:?}",
                i + 1,
                result.error
            );
        }
    }
    QuizQuestions {
        questions: generated_questions,
    }
}

fn inner_generate_verse_fragment_quiz(filter: QuizFilter) -> QuizGenerationResult {
    let send_error = |err| QuizGenerationResult {
        question: None,
        error: Some(err),
    };

    let keys = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(k) if !k.is_empty() => k,
        Ok(_) => return send_error(QuizGenerationError::NoVersesInScope),
        Err(e) => return send_error(QuizGenerationError::InternalError(format!("Scope error: {e}"))),
    };

    let min_words = ANSWER_WORD_COUNT + 2;
    let Some(verse) = quiz_utils::find_valid_long_verse(&keys, min_words) else {
        return send_error(QuizGenerationError::NoValidQuestionFound);
    };

    let engine_data = &GLOBAL_DATA;
    let words: Vec<Word> = verse
        .word_ids
        .iter()
        .filter_map(|id| engine_data.words.data.get(id).cloned())
        .collect();

    if words.len() < min_words {
        return send_error(QuizGenerationError::NoValidQuestionFound);
    }

    let mut rng = thread_rng();
    let max_start = words.len().saturating_sub(ANSWER_WORD_COUNT);
    let start_cut = if max_start > 0 {
        rng.gen_range(0..=max_start)
    } else {
        0
    };
    let end_cut = start_cut + ANSWER_WORD_COUNT;

    let to_string = |slice: &[Word]| {
        let raw = slice
            .iter()
            .map(|w| w.text_uthmani.as_str())
            .collect::<Vec<_>>()
            .join(" ");
        quiz_utils::normalize_text(&raw)
    };

    let part1 = to_string(&words[..start_cut]);
    let missing = to_string(&words[start_cut..end_cut]);
    let part2 = to_string(&words[end_cut..]);

    // Ambil kata sebelum potongan yang dihilangkan, kalau ada
    let target_prev_word = if start_cut >= 1 {
        Some(words[start_cut - 1].text_uthmani.clone())
    } else {
        None
    };

    // Gunakan decoy berbasis konteks kata sebelumnya
    let mut decoys = quiz_utils::get_contextual_decoys(
        target_prev_word.clone(),
        ANSWER_WORD_COUNT,
        &missing,
        &keys,
    );

    // Fallback jika decoy terlalu sedikit
    if decoys.len() < 3 {
        decoys.extend(quiz_utils::get_decoy_fragments(
            5 - decoys.len(),
            ANSWER_WORD_COUNT,
            &missing,
            &keys,
        ));
    }

    let mut unique_texts = HashSet::new();
    let mut options = vec![];

    unique_texts.insert(missing.clone());
    options.push(QuizOption {
        text: missing.clone(),
        is_correct: true,
    });

    for d in decoys {
        let norm = quiz_utils::normalize_text(&d);
        if unique_texts.insert(norm.clone()) {
            options.push(QuizOption {
                text: norm,
                is_correct: false,
            });
        }

        if options.len() >= 5 {
            break;
        }
    }

    options.shuffle(&mut rng);
    let correct_index = options.iter().position(|o| o.is_correct).unwrap_or(0) as u32;

    QuizGenerationResult {
        question: Some(QuizQuestion {
            verse_key: verse.verse_key.clone(),
            question_text_part1: part1,
            question_text_part2: part2,
            missing_part_text: missing,
            options,
            correct_answer_index: correct_index,
            correct_order_indices: None,
            shuffled_parts: None,
            quiz_type: "fragment_completion".to_string(),
            // 🔽 Properti tambahan untuk konsistensi format baru
            shuffled_keys: None,
            correct_order_keys: None,
        }),
        error: None,
    }
}

