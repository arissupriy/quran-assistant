// src/data-loader/quiz_models.rs

use serde::{Deserialize, Serialize};
use bincode::{Decode, Encode};

/// Merepresentasikan satu opsi jawaban dalam kuis pilihan ganda.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, PartialEq, Eq)]
pub struct QuizOption {
    /// Teks yang akan ditampilkan kepada pengguna untuk opsi ini.
    pub text: String,
    /// Menandakan apakah ini adalah opsi jawaban yang benar.
    pub is_correct: bool,
}

/// Struktur utama yang merepresentasikan satu pertanyaan kuis.
/// Dirancang untuk mendukung berbagai jenis kuis secara fleksibel.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct QuizQuestion {
    // --- Identitas Soal ---
    /// Kunci ayat (`chapter:verse`) yang menjadi sumber utama soal ini.
    pub verse_key: String,

    // --- Konten Pertanyaan (Untuk Kuis Melengkapi) ---
    /// Bagian pertama dari teks pertanyaan (misalnya, teks ayat sebelum bagian yang dihilangkan).
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub question_text_part1: String,
    
    /// Bagian kedua dari teks pertanyaan (misalnya, teks setelah bagian yang dihilangkan).
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub question_text_part2: String,
    
    /// Teks dari jawaban yang benar (misalnya, potongan kata/ayat yang dihilangkan).
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub missing_part_text: String,

    // --- Opsi Jawaban (Digunakan untuk SEMUA tipe kuis) ---
    /// Daftar opsi yang akan ditampilkan.
    /// - Untuk Pilihan Ganda: Berisi teks jawaban (1 benar, sisanya pengecoh).
    /// - Untuk Puzzle: Berisi teks dari item yang diacak (kata atau ayat).
    pub options: Vec<QuizOption>,

    // --- Kunci Jawaban (Pilih salah satu sesuai tipe kuis) ---
    /// **Untuk Pilihan Ganda:** Indeks dari `options` yang merupakan jawaban benar.
    pub correct_answer_index: u32,

    /// **Untuk Puzzle/Urutan:** Menyimpan urutan indeks yang benar dari `options`.
    /// `None` jika bukan kuis tipe urutan.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub correct_order_indices: Option<Vec<u32>>,

    // --- Metadata Kuis ---
    /// String yang mengidentifikasi tipe kuis.
    /// Contoh: "verse_completion", "fragment_completion", "word_puzzle", "verse_puzzle".
    pub quiz_type: String,
}

/// Struct pembungkus jika Anda ingin mengembalikan satu set pertanyaan kuis sekaligus.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct QuizQuestions {
    pub questions: Vec<QuizQuestion>,
}

// --- Definisi untuk Filter dan Cakupan Kuis ---

/// Enum untuk mendefinisikan cakupan (scope) pembuatan soal kuis.
/// Ini memberikan cara yang bersih dan aman untuk menentukan sumber ayat.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub enum QuizScope {
    /// Menggunakan semua ayat di Al-Qur'an.
    All,
    /// Berdasarkan daftar nomor Juz.
    /// - `juz_numbers: vec![1]` -> Hanya Juz 1.
    /// - `juz_numbers: vec![1, 5]` -> Rentang Juz dari 1 sampai 5.
    ByJuz { juz_numbers: Vec<u32> },
    /// Berdasarkan satu ID Surah.
    BySurah { surah_id: u32 },
}

/// Struct utama untuk parameter filter kuis yang dikirim dari Flutter.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct QuizFilter {
    /// Cakupan ayat yang akan digunakan untuk membuat soal.
    pub scope: QuizScope,

    /// Jumlah soal yang ingin dihasilkan.
    #[serde(default = "default_question_count")]
    pub question_count: u32,

    // Contoh tambahan nanti:
    // pub difficulty: u32,
    // pub excluded_verse_keys: Vec<String>,
}

fn default_question_count() -> u32 {
    5 // fallback jika tidak diisi dari Flutter
}

/// Mendefinisikan jenis-jenis error yang bisa terjadi saat membuat kuis.
/// Ini akan dikirim ke Flutter untuk menampilkan pesan yang sesuai.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, PartialEq, Eq)]
pub enum QuizGenerationError {
    /// Terjadi ketika filter yang diberikan (mis. Juz/Surah) tidak menghasilkan satu pun ayat.
    NoVersesInScope,
    /// Terjadi ketika tidak ada ayat yang memenuhi kriteria soal (mis. unik atau cukup panjang)
    /// setelah beberapa kali percobaan.
    NoValidQuestionFound,
    /// Error internal lainnya yang tidak terduga.
    InternalError(String),
}

/// Struct yang akan selalu dikembalikan oleh fungsi generator kuis.
/// Berisi salah satu dari `question` (jika sukses) atau `error` (jika gagal).
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone)]
pub struct QuizGenerationResult {
    /// Berisi pertanyaan kuis jika berhasil dibuat. `None` jika gagal.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub question: Option<QuizQuestion>,
    /// Berisi detail error jika gagal dibuat. `None` jika berhasil.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error: Option<QuizGenerationError>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use anyhow::Result;

    #[test]
    fn test_quiz_question_serialization_deserialization() -> Result<()> {
        // 1. Contoh Kuis Pilihan Ganda (Verse Completion)
        let verse_completion_quiz = QuizQuestion {
            verse_key: "2:254".to_string(),
            question_text_part1: "Ini adalah teks ayat 2:254".to_string(),
            question_text_part2: "".to_string(),
            missing_part_text: "Ini adalah teks ayat 2:255".to_string(),
            options: vec![
                QuizOption { text: "Pengecoh 1".to_string(), is_correct: false },
                QuizOption { text: "Ini adalah teks ayat 2:255".to_string(), is_correct: true },
                QuizOption { text: "Pengecoh 2".to_string(), is_correct: false },
            ],
            correct_answer_index: 1,
            correct_order_indices: None,
            quiz_type: "verse_completion".to_string(),
        };

        // Serialisasi
        let encoded = bincode::encode_to_vec(&verse_completion_quiz, bincode::config::standard())?;
        // Deserialisasi
        let (decoded, _): (QuizQuestion, usize) = bincode::decode_from_slice(&encoded, bincode::config::standard())?;

        assert_eq!(decoded.verse_key, "2:254");
        assert_eq!(decoded.correct_answer_index, 1);
        assert!(decoded.correct_order_indices.is_none());
        assert_eq!(decoded.quiz_type, "verse_completion");
        println!("✅ Serialisasi/deserialisasi kuis pilihan ganda berhasil.");

        // 2. Contoh Kuis Puzzle (Word Puzzle)
        let word_puzzle_quiz = QuizQuestion {
            verse_key: "1:1".to_string(),
            question_text_part1: "Susunlah kata berikut:".to_string(),
            question_text_part2: "".to_string(),
            missing_part_text: "".to_string(),
            options: vec![
                QuizOption { text: "ٱلرَّحِيمِ".to_string(), is_correct: false }, // Posisi asli 3
                QuizOption { text: "بِسْمِ".to_string(), is_correct: false },   // Posisi asli 0
                QuizOption { text: "ٱلرَّحْمَـٰنِ".to_string(), is_correct: false },// Posisi asli 2
                QuizOption { text: "ٱللَّهِ".to_string(), is_correct: false },   // Posisi asli 1
            ],
            correct_answer_index: 0, // Tidak relevan untuk puzzle
            correct_order_indices: Some(vec![1, 3, 2, 0]), // Urutan indeks yang benar
            quiz_type: "word_puzzle".to_string(),
        };

        let encoded_puzzle = bincode::encode_to_vec(&word_puzzle_quiz, bincode::config::standard())?;
        let (decoded_puzzle, _): (QuizQuestion, usize) = bincode::decode_from_slice(&encoded_puzzle, bincode::config::standard())?;

        assert_eq!(decoded_puzzle.verse_key, "1:1");
        assert!(decoded_puzzle.correct_order_indices.is_some());
        assert_eq!(decoded_puzzle.correct_order_indices.unwrap(), vec![1, 3, 2, 0]);
        assert_eq!(decoded_puzzle.quiz_type, "word_puzzle");
        println!("✅ Serialisasi/deserialisasi kuis puzzle berhasil.");
        
        Ok(())
    }
}

// --- Tambahan & Modifikasi untuk History ---

// QuizSession yang akan disimpan di database dan dikirim ke Flutter
#[derive(Debug, Serialize, Deserialize, Clone)] // Hapus Encode/Decode bincode jika hanya untuk database/JSON/serialisasi
pub struct QuizSession {
    pub session_id: String,
    pub user_id: Option<String>, // Gunakan Option untuk nilai NULL di DB
    pub quiz_type: String,
    pub scope_type: String, // String dari QuizScope (e.g., "All", "ByJuz")
    pub scope_details: serde_json::Map<String, serde_json::Value>, // <- Dulu serde_json::Value
    pub requested_question_count: u32,
    pub actual_question_count: u32,
    pub start_time_unix: i64, // Unix timestamp dalam detik
    pub end_time_unix: i64,
    pub total_duration_seconds: u32,
    pub correct_answers_count: u32,
    pub incorrect_answers_count: u32,
}

// QuizAttempt yang akan disimpan di database dan dikirim ke Flutter
#[derive(Debug, Serialize, Deserialize, Clone)] // Hapus Encode/Decode bincode
pub struct QuizAttempt {
    pub attempt_id: String,
    pub session_id: String,
    pub question_index: u32,
    pub verse_key: String,
    pub question_text_part1: String,
    pub missing_part_text: String,
    pub options: Vec<QuizOption>, // Akan di-serialize ke JSON
    pub user_answer_index: Option<u32>, // Gunakan Option
    pub correct_answer_index: u32,
    pub is_correct: bool,
    pub time_spent_seconds: u32,
    pub timestamp_unix: i64, // Unix timestamp dalam detik
}