// src/ffi/quiz_generator/verse_completion.rs

use std::collections::HashSet;

use crate::data_loader::quiz_models::{
    QuizFilter, QuizGenerationError, QuizGenerationResult, QuizOption, QuizQuestion, QuizQuestions,
};
use crate::quiz_utils;
use log::{debug, error, info, warn};
use rand::seq::SliceRandom;
use rand::thread_rng;

#[flutter_rust_bridge::frb(sync)]
pub fn generate_verse_completion_quiz(filter: QuizFilter) -> QuizGenerationResult {
    info!("QuizGen: generate_verse_completion_quiz: Fungsi dimulai.");
    let result = inner_generate_verse_completion_quiz(filter);
    match &result.error {
        Some(e) => error!(
            "QuizGen: generate_verse_completion_quiz selesai dengan error: {:?}",
            e
        ),
        None => info!("QuizGen: generate_verse_completion_quiz selesai dengan sukses."),
    }
    result
}

pub fn generate_batch_verse_completion_quizzes(filter: QuizFilter) -> QuizQuestions {
    info!(
        "QuizGen: generate_batch_verse_completion_quizzes: Jumlah kuis diminta: {}",
        filter.quiz_count
    );
    let mut generated_questions = Vec::with_capacity(filter.quiz_count as usize);
    for i in 0..filter.quiz_count {
        info!("QuizGen: Menghasilkan kuis ke-{}", i + 1);
        let result = inner_generate_verse_completion_quiz(filter.clone());
        if let Some(q) = result.question {
            generated_questions.push(q);
        } else {
            warn!("QuizGen: Gagal kuis ke-{}: {:?}", i + 1, result.error);
        }
    }
    QuizQuestions {
        questions: generated_questions,
    }
}

pub fn inner_generate_verse_completion_quiz(filter: QuizFilter) -> QuizGenerationResult {
    let send_error = |err| QuizGenerationResult {
        question: None,
        error: Some(err),
    };

    let verse_keys_in_scope = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(keys) if !keys.is_empty() => keys,
        Ok(_) => return send_error(QuizGenerationError::NoVersesInScope),
        Err(e) => {
            return send_error(QuizGenerationError::InternalError(format!(
                "Error getting scope: {}",
                e
            )))
        }
    };

    let Some(question_verse) = quiz_utils::find_valid_question_verse(verse_keys_in_scope.clone())
    else {
        return send_error(QuizGenerationError::NoValidQuestionFound);
    };

    let Some(next_verse_key) = quiz_utils::get_next_verse_key(&question_verse.verse_key) else {
        return send_error(QuizGenerationError::InternalError(format!(
            "Tidak ada ayat selanjutnya untuk {}",
            question_verse.verse_key
        )));
    };

    let Some(answer_text) = quiz_utils::get_text_for_key(&next_verse_key) else {
        return send_error(QuizGenerationError::InternalError(format!(
            "Teks tidak ditemukan untuk {}",
            next_verse_key
        )));
    };

    let mut rng = thread_rng();
    let mut options = Vec::new();
    let mut unique_texts = HashSet::new();

    let correct_text = quiz_utils::get_words_from_fragment_string(&answer_text).join(" ");
    unique_texts.insert(correct_text.clone());
    options.push(QuizOption {
        text: correct_text.clone(),
        is_correct: true,
    });

    for decoy in quiz_utils::get_decoy_verses(4, &next_verse_key, &verse_keys_in_scope) {
        if let Some(text) = quiz_utils::get_text_for_key(&decoy.verse_key) {
            let norm_text = quiz_utils::get_words_from_fragment_string(&text).join(" ");
            if unique_texts.insert(norm_text.clone()) {
                options.push(QuizOption {
                    text: norm_text,
                    is_correct: false,
                });
            }
        }
    }

    while options.len() < 5 {
        if let Some(extra) = quiz_utils::get_decoy_verses(1, &next_verse_key, &verse_keys_in_scope)
            .into_iter()
            .next()
        {
            if let Some(text) = quiz_utils::get_text_for_key(&extra.verse_key) {
                let norm = quiz_utils::get_words_from_fragment_string(&text).join(" ");
                if unique_texts.insert(norm.clone()) {
                    options.push(QuizOption {
                        text: norm,
                        is_correct: false,
                    });
                } else {
                    break;
                }
            } else {
                break;
            }
        } else {
            break;
        }
    }

    options.shuffle(&mut rng);

    let correct_index = options.iter().position(|o| o.is_correct).unwrap_or(0) as u32;

    let question_text = match quiz_utils::get_text_for_key(&question_verse.verse_key) {
        Some(text) => text.to_string(),
        None => {
            error!(
                "QuizGen: Tidak bisa menemukan teks untuk verse_key {}",
                question_verse.verse_key
            );
            return send_error(QuizGenerationError::InternalError(format!(
                "Teks tidak ditemukan untuk ayat soal: {}",
                question_verse.verse_key
            )));
        }
    };

    let quiz = QuizQuestion {
        verse_key: question_verse.verse_key.clone(),
        question_text_part1: question_text,
        question_text_part2: String::new(),
        missing_part_text: correct_text,
        options,
        correct_answer_index: correct_index,
        correct_order_indices: None,
        shuffled_parts: None, // ✅
        quiz_type: "verse_completion".to_string(),
        // 🔽 Properti tambahan untuk konsistensi format baru
        shuffled_keys: None,
        correct_order_keys: None,
    };

    QuizGenerationResult {
        question: Some(quiz),
        error: None,
    }
}
