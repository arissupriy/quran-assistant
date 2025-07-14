// C:\PROJECT\QURAN_ASSISTANT\RUST\SRC\api\quran\quiz.rs

use crate::GLOBAL_DATA;
// Mengimpor semua struct model kuis dari data_loader
use crate::data_loader::quiz_models::{QuizFilter, QuizGenerationError, QuizGenerationResult, QuizOption, QuizQuestion, QuizQuestions};
use crate::data_loader::verse_by_chapter::Word; // Diperlukan oleh logika kuis
use crate::quiz_utils; // Impor modul quiz_utils

use flutter_rust_bridge::frb;
use rand::seq::{IteratorRandom, SliceRandom};
use rand::Rng;
use rand::thread_rng;
use log::{info, debug, warn, error}; // Impor untuk logging

// Konstanta untuk kuis fragmen (jika masih digunakan di sini, atau pindahkan ke quiz_utils/models)
const MIN_WORDS_FOR_FRAGMENT_QUIZ: usize = 7;
const ANSWER_WORD_COUNT: usize = 2;

#[frb]
pub fn generate_verse_fragment_quiz(filter: QuizFilter) -> QuizGenerationResult {
    info!("QuizGen: generate_verse_fragment_quiz: Fungsi dimulai.");

    let send_error = |error_type: QuizGenerationError| -> QuizGenerationResult {
        QuizGenerationResult { question: None, error: Some(error_type) }
    };

    debug!("QuizGen: Filter berhasil diterima: {:?}", filter);

    info!("QuizGen: Mencari kunci ayat dalam scope.");
    let verse_keys_in_scope = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(keys) if !keys.is_empty() => keys,
        Err(e) => {
            error!("QuizGen: ERROR: Gagal mendapatkan kunci ayat dalam scope: {}", e);
            return send_error(QuizGenerationError::InternalError(format!("Error getting verses in scope: {}", e)));
        }
        _ => return send_error(QuizGenerationError::NoVersesInScope),
    };
    info!("QuizGen: Ditemukan {} kunci ayat dalam scope.", verse_keys_in_scope.len());


    info!("QuizGen: Mencari ayat yang valid (cukup panjang) untuk soal.");
    let Some(question_verse) = quiz_utils::find_valid_long_verse(&verse_keys_in_scope, MIN_WORDS_FOR_FRAGMENT_QUIZ) else {
        warn!("QuizGen: Tidak ditemukan kandidat soal yang valid (ayat terlalu pendek atau tidak ada).");
        return send_error(QuizGenerationError::NoValidQuestionFound);
    };
    info!("QuizGen: Ayat soal valid ditemukan: {:?}", question_verse.verse_key);

    let words = &question_verse.words;
    
    if words.len() <= ANSWER_WORD_COUNT + 1 {
        warn!("QuizGen: Ayat terlalu pendek untuk membuat fragmen. Kata: {}", words.len());
        return send_error(QuizGenerationError::NoValidQuestionFound);
    }

    let mut rng = thread_rng();
    let max_start_cut_index = words.len().saturating_sub(ANSWER_WORD_COUNT + 1);
    let start_cut_index = if max_start_cut_index > 0 {
        rng.gen_range(1..=max_start_cut_index)
    } else {
        error!("QuizGen: Gagal menentukan start_cut_index yang valid. Kata: {}", words.len());
        return send_error(QuizGenerationError::InternalError(
            "Tidak cukup kata untuk membentuk kuis fragmen yang valid".to_string()
        ));
    };
    
    let end_cut_index = start_cut_index + ANSWER_WORD_COUNT;

    let part1_words = &words[..start_cut_index];
    let answer_words = &words[start_cut_index..end_cut_index];
    let part2_words = &words[end_cut_index..];

    let to_string = |word_slice: &[Word]| -> String {
        word_slice.iter().map(|w| w.text_uthmani.as_str()).collect::<Vec<_>>().join(" ")
    };

    let question_text_part1 = to_string(part1_words);
    let missing_part_text = to_string(answer_words);
    let question_text_part2 = to_string(part2_words);

    info!("QuizGen: Fragmen ditemukan. Part1 len: {}, Missing len: {}, Part2 len: {}",
          part1_words.len(), answer_words.len(), part2_words.len());
    debug!("QuizGen: Part1: '{}'", question_text_part1);
    debug!("QuizGen: Missing: '{}'", missing_part_text);
    debug!("QuizGen: Part2: '{}'", question_text_part2);

    info!("QuizGen: Mengambil ayat pengecoh fragmen.");
    let decoys = quiz_utils::get_decoy_fragments(4, ANSWER_WORD_COUNT, &missing_part_text);
    info!("QuizGen: Ditemukan {} pengecoh fragmen.", decoys.len());

    let mut options = vec![QuizOption { text: missing_part_text.clone(), is_correct: true }];
    options.extend(decoys.into_iter().map(|text| QuizOption { text, is_correct: false }));
    
    info!("QuizGen: Total opsi fragmen: {}.", options.len());

    options.shuffle(&mut rng);

    let correct_index = options.iter().position(|opt| opt.is_correct).unwrap_or(0) as u32;
    debug!("QuizGen: Indeks jawaban benar: {}.", correct_index);

    info!("QuizGen: Membangun objek QuizQuestion.");
    let quiz = QuizQuestion {
        verse_key: question_verse.verse_key.clone(), // <--- UBAH DI SINI: Langsung berikan String tanpa Some()
        question_text_part1,
        question_text_part2,
        missing_part_text,
        options,
        correct_answer_index: correct_index,
        correct_order_indices: None,
        quiz_type: "fragment_completion".to_string(),
    };
    
    QuizGenerationResult {
        question: Some(quiz),
        error: None,
    }
}

#[frb]
pub fn generate_verse_fragment_quiz_batch(filter: QuizFilter) -> QuizQuestions {
    let mut questions = vec![];
    let mut attempts = 0;
    let max_attempts = filter.question_count * 3; // Batas percobaan untuk menghasilkan soal

    info!("▶️ Mulai generate {} soal (fragment_completion)", filter.question_count);
    info!("📦 Scope: {:?}", filter.scope);

    // Ambil semua kunci ayat dalam cakupan yang ditentukan
    let verse_keys_in_scope = match quiz_utils::get_verse_keys_in_scope(&filter) {
        Ok(keys) if !keys.is_empty() => {
            info!("✅ Total ayat dalam scope: {}", keys.len());
            keys
        },
        Err(e) => {
            error!("❌ Error saat mendapatkan ayat dalam scope: {}", e);
            return QuizQuestions { questions: vec![] };
        }
        _ => {
            warn!("⚠️ Tidak ada ayat dalam scope {:?}", filter.scope);
            return QuizQuestions { questions: vec![] };
        }
    };

    // Loop untuk menghasilkan sejumlah soal yang diminta atau sampai batas percobaan
    while (questions.len() as u32) < filter.question_count && attempts < max_attempts {
        attempts += 1; // Tingkatkan hitungan percobaan di setiap iterasi

        // Cari ayat panjang yang valid untuk dijadikan dasar soal
        let Some(question_verse) =
            quiz_utils::find_valid_long_verse(&verse_keys_in_scope, MIN_WORDS_FOR_FRAGMENT_QUIZ)
        else {
            warn!("Tidak dapat menemukan ayat panjang yang valid setelah {} percobaan.", attempts);
            continue; // Lewati iterasi ini jika tidak ada ayat yang cocok
        };

        let words = &question_verse.words;
        // Pastikan ayat cukup panjang untuk dipotong
        if words.len() <= ANSWER_WORD_COUNT + 1 {
            // Ayat terlalu pendek untuk membuat fragmen dan sisa teks
            continue;
        }

        let mut rng = thread_rng();
        // Hitung indeks maksimum di mana pemotongan bisa dimulai
        // `saturating_sub` menghindari overflow jika hasilnya negatif
        let max_start_cut_index = words.len().saturating_sub(ANSWER_WORD_COUNT + 1);
        
        if max_start_cut_index == 0 {
            // Ini berarti ayat terlalu pendek untuk menghasilkan potongan yang valid
            continue;
        }

        // Pilih indeks awal pemotongan secara acak
        // `gen_range(1..=max_start_cut_index)`: pastikan tidak memotong kata pertama (index 0)
        let start_cut_index = rng.gen_range(1..=max_start_cut_index);
        let end_cut_index = start_cut_index + ANSWER_WORD_COUNT;

        // Pemeriksaan batas, meskipun harusnya sudah ditangani oleh `max_start_cut_index`
        if end_cut_index > words.len() {
            error!(
                "❌ Terjadi kesalahan perhitungan indeks: end_cut_index {} > len(words) {}",
                end_cut_index,
                words.len()
            );
            continue;
        }

        // Pisahkan ayat menjadi tiga bagian
        let part1_words = &words[..start_cut_index];
        let answer_words = &words[start_cut_index..end_cut_index];
        let part2_words = &words[end_cut_index..];

        // Fungsi helper untuk mengubah slice kata menjadi string
        let to_string = |word_slice: &[crate::data_loader::verse_by_chapter::Word]| -> String {
            word_slice
                .iter()
                .map(|w| w.text_uthmani.as_str())
                .collect::<Vec<_>>()
                .join(" ")
        };

        let question_text_part1 = to_string(part1_words);
        let missing_part_text = to_string(answer_words);
        let question_text_part2 = to_string(part2_words);

        // Dapatkan pengecoh. Kita minta 4, tapi `get_decoy_fragments` mungkin mengembalikan kurang.
        let decoys = quiz_utils::get_decoy_fragments(4, ANSWER_WORD_COUNT, &missing_part_text);

        // Buat daftar opsi, dimulai dengan jawaban benar
        let mut options = vec![QuizOption {
            text: missing_part_text.clone(),
            is_correct: true,
        }];
        // Tambahkan pengecoh yang berhasil didapat
        options.extend(decoys.into_iter().map(|text| QuizOption {
            text,
            is_correct: false,
        }));

        // === PENTING: Pemeriksaan jumlah opsi yang lebih robust ===
        // Ganti assert! dengan if. Jika tidak ada 5 opsi, lewati soal ini.
        if options.len() != 5 {
            warn!(
                "⚠️ Gagal menghasilkan 5 opsi untuk soal ini (ditemukan: {}). Melewatkan soal.",
                options.len()
            );
            continue; // Lanjut ke iterasi berikutnya untuk mencoba soal lain
        }
        // Jika kode sampai sini, kita yakin `options.len()` adalah 5.
        // `assert!` lama bisa dihapus atau tetap sebagai sanity check tambahan.

        options.shuffle(&mut rng); // Acak urutan opsi

        // Temukan indeks jawaban yang benar setelah diacak
        let correct_index = options
            .iter()
            .position(|opt| opt.is_correct)
            .unwrap_or(0) as u32; // Gunakan unwrap_or(0) sebagai fallback, seharusnya selalu ada

        // Buat objek QuizQuestion
        let quiz = QuizQuestion {
            verse_key: question_verse.verse_key.clone(),
            question_text_part1,
            question_text_part2,
            missing_part_text,
            options,
            correct_answer_index: correct_index,
            correct_order_indices: None,
            quiz_type: "fragment_completion".to_string(),
        };

        questions.push(quiz); // Tambahkan soal yang berhasil dibuat
    }

    // Logging hasil akhir
    info!(
        "✅ Berhasil hasilkan {} soal dari {} percobaan",
        questions.len(),
        attempts
    );

    // Debug struktur akhir (opsional, untuk pengembangan)
    for (i, q) in questions.iter().enumerate() {
        info!(
            "🔢 Soal {}: verse={}, options.len={}, correct={}",
            i + 1,
            q.verse_key,
            q.options.len(),
            q.correct_answer_index
        );
    }

    QuizQuestions { questions } // Kembalikan semua soal yang berhasil dibuat
}
