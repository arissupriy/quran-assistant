use flutter_rust_bridge::frb;
use crate::data_loader::quiz_models::{
    QuizFilter, QuizGenerationError, QuizGenerationResult, QuizOption, QuizQuestion, QuizQuestions
};
use crate::quiz_utils;
use rand::seq::SliceRandom;
use rand::thread_rng;
use log::{debug, error, info, warn};

#[frb]
pub fn generate_verse_completion_quiz(filter: QuizFilter) -> QuizGenerationResult {
    let send_error = |error_type: QuizGenerationError| -> QuizGenerationResult {
        QuizGenerationResult {
            question: None,
            error: Some(error_type),
        }
    };

    info!("QuizGen: Mencari kunci ayat dalam scope.");
    let verse_keys_in_scope = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(keys) if !keys.is_empty() => keys,
        Err(e) => {
            error!("QuizGen: Scope error: {}", e);
            return send_error(QuizGenerationError::InternalError(format!("Scope error: {}", e)));
        }
        _ => return send_error(QuizGenerationError::NoVersesInScope),
    };

    info!("QuizGen: Mencari ayat soal.");
    let Some(question_verse) = quiz_utils::find_valid_question_verse(verse_keys_in_scope) else {
        warn!("QuizGen: Tidak ditemukan ayat valid untuk soal.");
        return send_error(QuizGenerationError::NoValidQuestionFound);
    };

    info!("QuizGen: Mendapatkan ayat setelahnya sebagai jawaban.");
    let Some(next_verse_key) = quiz_utils::get_next_verse_key(&question_verse.verse_key) else {
        return send_error(QuizGenerationError::InternalError(format!(
            "No next verse for {}",
            question_verse.verse_key
        )));
    };

    let Some(answer_verse_text) = quiz_utils::get_text_for_key(&next_verse_key) else {
        return send_error(QuizGenerationError::InternalError(format!(
            "Missing answer text for {}",
            next_verse_key
        )));
    };

    info!("QuizGen: Mengambil pengecoh.");
    let decoys = quiz_utils::get_decoy_verses(4, &next_verse_key);

    let mut options = vec![QuizOption {
        text: answer_verse_text.to_string(),
        is_correct: true,
    }];
    options.extend(decoys.iter().map(|d| QuizOption {
        text: d.text_uthmani.clone(),
        is_correct: false,
    }));

    options.shuffle(&mut thread_rng());

    let correct_index = options.iter().position(|o| o.is_correct).unwrap_or(0) as u32;

    info!("QuizGen: Membangun struktur QuizQuestion.");
    let quiz = QuizQuestion {
        verse_key: question_verse.verse_key.clone(),
        question_text_part1: question_verse.text_uthmani.clone(),
        question_text_part2: String::new(),
        missing_part_text: answer_verse_text.to_string(),
        options,
        correct_answer_index: correct_index,
        correct_order_indices: None,
        quiz_type: "verse_completion".to_string(),
    };

    QuizGenerationResult {
        question: Some(quiz),
        error: None,
    }
}



#[frb]
pub fn generate_verse_completion_quiz_batch(filter: QuizFilter) -> QuizQuestions {
    let mut questions = vec![];
    let mut attempts = 0;
    let max_attempts = filter.question_count * 3;

    info!(
        "QuizGen: Memulai generate {} soal untuk tipe 'verse_completion'",
        filter.question_count
    );

    let verse_keys_in_scope = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(keys) if !keys.is_empty() => keys,
        Err(e) => {
            error!("QuizGen: Scope error: {}", e);
            return QuizQuestions { questions: vec![] };
        }
        _ => {
            warn!("QuizGen: Tidak ada ayat dalam scope {:?}", filter.scope);
            return QuizQuestions { questions: vec![] };
        }
    };

    while (questions.len() as u32) < filter.question_count && attempts < max_attempts {
        attempts += 1;

        let Some(question_verse) = quiz_utils::find_valid_question_verse(verse_keys_in_scope.clone()) else {
            continue;
        };

        let Some(next_verse_key) = quiz_utils::get_next_verse_key(&question_verse.verse_key) else {
            continue;
        };

        let Some(answer_verse_text) = quiz_utils::get_text_for_key(&next_verse_key) else {
            continue;
        };

        let decoys = quiz_utils::get_decoy_verses(4, &next_verse_key);
        let mut options = vec![QuizOption {
            text: answer_verse_text.to_string(),
            is_correct: true,
        }];
        options.extend(decoys.iter().map(|d| QuizOption {
            text: d.text_uthmani.clone(),
            is_correct: false,
        }));
        options.shuffle(&mut thread_rng());

        let correct_index = options.iter().position(|o| o.is_correct).unwrap_or(0) as u32;

        let quiz = QuizQuestion {
            verse_key: question_verse.verse_key.clone(),
            question_text_part1: question_verse.text_uthmani.clone(),
            question_text_part2: String::new(),
            missing_part_text: answer_verse_text.to_string(),
            options,
            correct_answer_index: correct_index,
            correct_order_indices: None,
            quiz_type: "verse_completion".to_string(),
        };

        questions.push(quiz);
    }

    info!(
        "QuizGen: Selesai. Dihasilkan {} soal dari {} percobaan",
        questions.len(),
        attempts
    );

    QuizQuestions { questions }
}
