use crate::data_loader::quiz_models::{
    QuizFilter, QuizGenerationError, QuizGenerationResult, QuizOption, QuizQuestion, QuizQuestions,
};
use crate::{quiz_utils, GLOBAL_DATA};
use flutter_rust_bridge::frb;
use log::{error, info, warn};
use rand::seq::SliceRandom;
use std::collections::HashSet;

/// Membuat batch kuis tebak ayat sebelumnya.
#[frb]
pub fn generate_batch_verse_previous_quizzes(filter: QuizFilter) -> QuizQuestions {
    let mut questions = Vec::with_capacity(filter.quiz_count as usize);
    let mut attempts = 0;

    while questions.len() < filter.quiz_count as usize && attempts < filter.quiz_count as usize * 3
    {
        let result = generate_previous_verse_quiz(filter.clone());
        if let Some(q) = result.question {
            questions.push(q);
        }
        attempts += 1;
    }

    QuizQuestions { questions }
}

/// Membuat kuis "Tebak Ayat Sebelumnya"
#[frb]
pub fn generate_previous_verse_quiz(filter: QuizFilter) -> QuizGenerationResult {
    info!("QuizGen: Mulai generate_previous_verse_quiz");

    let send_error = |e: QuizGenerationError| -> QuizGenerationResult {
        QuizGenerationResult {
            question: None,
            error: Some(e),
        }
    };

    let keys_in_scope = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(keys) if !keys.is_empty() => keys,
        Err(e) => {
            error!("QuizGen: Gagal ambil verse_keys_in_scope: {}", e);
            return send_error(QuizGenerationError::InternalError(e.to_string()));
        }
        _ => return send_error(QuizGenerationError::NoVersesInScope),
    };

    let Some(question_verse) = quiz_utils::find_valid_question_verse(keys_in_scope.clone()) else {
        return send_error(QuizGenerationError::NoValidQuestionFound);
    };

    let Some(prev_key) = quiz_utils::get_prev_verse_key(&question_verse.verse_key) else {
        warn!("QuizGen: Ayat tidak punya ayat sebelumnya.");
        return send_error(QuizGenerationError::NoValidQuestionFound);
    };

    let Some(correct_text) = quiz_utils::get_text_for_key(&prev_key) else {
        return send_error(QuizGenerationError::MissingAyahText);
    };

    let mut options = vec![QuizOption {
        text: quiz_utils::normalize_text(&correct_text),
        is_correct: true,
    }];

    let mut unique_texts = HashSet::new();
    unique_texts.insert(options[0].text.clone());

    for decoy in quiz_utils::get_decoy_verses(4, &prev_key, &keys_in_scope) {
        let decoy_text =
            quiz_utils::get_text_for_key(&decoy.verse_key).map(|t| quiz_utils::normalize_text(&t));

        if let Some(text) = decoy_text {
            if unique_texts.insert(text.clone()) {
                options.push(QuizOption {
                    text,
                    is_correct: false,
                });
            }
        }
    }

    while options.len() < 5 {
        if let Some(extra) = quiz_utils::get_decoy_verses(1, &prev_key, &keys_in_scope)
            .into_iter()
            .next()
        {
            if let Some(extra_text) = quiz_utils::get_text_for_key(&extra.verse_key) {
                let normalized = quiz_utils::normalize_text(&extra_text);
                if unique_texts.insert(normalized.clone()) {
                    options.push(QuizOption {
                        text: normalized,
                        is_correct: false,
                    });
                }
            }
        } else {
            break;
        }
    }

    options.shuffle(&mut rand::thread_rng());

    let correct_index = options.iter().position(|o| o.is_correct).unwrap_or(0) as u32;

    let quiz = QuizQuestion {
        verse_key: question_verse.verse_key.clone(),
        question_text_part1: quiz_utils::get_text_for_key(&question_verse.verse_key)
            .unwrap_or_default(),
        question_text_part2: String::new(),
        missing_part_text: correct_text,
        options,
        correct_answer_index: correct_index,
        correct_order_indices: None,
        shuffled_parts: None, // ✅ tambahkan ini
        quiz_type: "previous_verse".to_string(),
        // 🔽 Properti tambahan untuk konsistensi format baru
        shuffled_keys: None,
        correct_order_keys: None,
    };

    QuizGenerationResult {
        question: Some(quiz),
        error: None,
    }
}
