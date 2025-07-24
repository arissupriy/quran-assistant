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

    /// Hanya untuk tipe puzzle: bagian yang diacak (teks)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub shuffled_parts: Option<Vec<String>>,

    /// Hanya untuk puzzle ayat: urutan `verseKey` dari `shuffled_parts`
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub shuffled_keys: Option<Vec<String>>,

    /// Hanya untuk puzzle ayat: urutan benar `verseKey` yang harus dicapai
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub correct_order_keys: Option<Vec<String>>,
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
    // Anda bisa menambahkan field lain di sini nanti, misalnya:
    // pub difficulty: u32,
    // pub excluded_verse_keys: Vec<String>,
    #[serde(default = "default_quiz_count")] // Set nilai default saat deserialisasi
    pub quiz_count: u32,
}

/// Mendefinisikan jenis-jenis error yang bisa terjadi saat membuat kuis.
/// Ini akan dikirim ke Flutter untuk menampilkan pesan yang sesuai.
#[derive(Debug, Serialize, Deserialize, Encode, Decode, Clone, PartialEq, Eq)]
pub enum QuizGenerationError {
    /// Error internal lainnya yang tidak terduga.
    InternalError(String),
    /// Terjadi ketika filter yang diberikan (mis. Juz/Surah) tidak menghasilkan satu pun ayat.
    NoVersesInScope,
    /// Terjadi ketika tidak ada ayat yang memenuhi kriteria soal (mis. unik atau cukup panjang)
    /// setelah beberapa kali percobaan.
    NoValidQuestionFound,
    /// Terjadi ketika teks ayat yang diperlukan untuk soal tidak ditemukan.
    MissingAyahText, // Teks ayat tidak ditemukan
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

fn default_quiz_count() -> u32 {
    5
}