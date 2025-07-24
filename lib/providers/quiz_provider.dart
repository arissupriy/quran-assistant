import 'dart:convert'; // Untuk jsonEncode/decode
import 'dart:io'; // Mungkin diperlukan oleh logging atau lainnya

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Impor Hive
import 'package:quran_assistant/core/models/quiz_history.dart'; // Model history Anda
import 'package:quran_assistant/src/rust/data_loader/quiz_models.dart'
    as RustModels; // Alias untuk menghindari konflik nama
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart'; // Untuk logging (pastikan terinstal)
import 'package:collection/collection.dart';

// Inisialisasi logger. Ini adalah best practice untuk logging terstruktur.
// Anda perlu mengkonfigurasi logger ini di main.dart agar pesan-pesannya terlihat.
// Contoh konfigurasi di main.dart:
// void main() {
//   Logger.root.level = Level.ALL; // Atur level logging sesuai kebutuhan
//   Logger.root.onRecord.listen((record) {
//     debugPrint('${record.level.name}: ${record.time}: ${record.message}');
//   });
//   // ... rest of main ...
// }
final _log = Logger('QuizProviders');

// --- Provider untuk State Kuis Aktif ---

/// **currentQuizQuestionsProvider**: Menyimpan daftar soal aktif untuk sesi kuis saat ini.
/// Ini adalah sumber data utama untuk tampilan kuis.
final currentQuizQuestionsProvider =
    StateProvider<List<RustModels.QuizQuestion>>((ref) => []);

/// **currentQuestionIndexProvider**: Melacak indeks soal yang sedang ditampilkan kepada pengguna (0-indexed).
/// Digunakan untuk navigasi antar soal.
final currentQuestionIndexProvider = StateProvider<int>((ref) => 0);

/// **currentQuizQuestionProvider**: Menyediakan objek soal kuis yang sedang aktif.
/// Ini adalah *derived state* dari `currentQuizQuestionsProvider` dan `currentQuestionIndexProvider`.
/// Akan otomatis diperbarui jika daftar soal atau indeks berubah.
final currentQuizQuestionProvider = Provider<RustModels.QuizQuestion?>((ref) {
  final list = ref.watch(currentQuizQuestionsProvider);
  final index = ref.watch(currentQuestionIndexProvider);
  if (index < 0 || index >= list.length) {
    _log.warning(
      'Mencoba mengakses soal saat ini di luar batas. Indeks: $index, Panjang daftar: ${list.length}',
    );
    return null; // Mengembalikan null jika indeks tidak valid
  }
  return list[index];
});

/// **selectedOptionIndexProvider**: Melacak indeks opsi jawaban yang dipilih pengguna untuk soal saat ini.
/// Null jika belum ada pilihan.
final selectedOptionIndexProvider = StateProvider<int?>((ref) => null);

/// **answerCheckedProvider**: Menunjukkan apakah pengguna telah menekan tombol "Cek Jawaban" untuk soal saat ini.
/// Mengontrol tampilan feedback visual (benar/salah) pada UI.
final answerCheckedProvider = StateProvider<bool>((ref) => false);

// --- Provider untuk Data Sesi Kuis (History) ---

/// **currentSessionIdProvider**: ID unik (UUID) untuk sesi kuis yang sedang aktif.
/// Digunakan sebagai kunci utama untuk menyimpan dan mengambil data sesi di Hive.
final currentSessionIdProvider = StateProvider<String>(
  (ref) => const Uuid().v4(),
);

/// **sessionStartTimeProvider**: Waktu (DateTime) ketika sesi kuis dimulai.
/// Digunakan untuk menghitung total durasi sesi.
final sessionStartTimeProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

/// **currentQuestionStartTimeProvider**: Waktu (DateTime) ketika soal kuis saat ini dimulai.
/// Digunakan untuk menghitung durasi waktu yang dihabiskan per soal.
final currentQuestionStartTimeProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

/// **lastQuizCorrectCountProvider**: Menyimpan jumlah jawaban benar dari sesi kuis yang baru saja selesai.
/// Digunakan untuk menampilkan rangkuman di `QuizSummaryPage`.
final lastQuizCorrectCountProvider = StateProvider<int>((ref) => 0);

/// **lastQuizIncorrectCountProvider**: Menyimpan jumlah jawaban salah dari sesi kuis yang baru saja selesai.
/// Digunakan untuk menampilkan rangkuman di `QuizSummaryPage`.
final lastQuizIncorrectCountProvider = StateProvider<int>((ref) => 0);

/// **lastQuizTotalCountProvider**: Menyimpan total jumlah soal dari sesi kuis yang baru saja selesai.
/// Digunakan untuk menampilkan rangkuman di `QuizSummaryPage`.
final lastQuizTotalCountProvider = StateProvider<int>((ref) => 0);

/// **quizSessionControllerProvider**: Controller utama yang bertanggung jawab atas seluruh siklus hidup sesi kuis.
/// Termasuk inisialisasi sesi, perekaman jawaban, navigasi antar soal, dan penyimpanan data ke Hive.
final quizSessionControllerProvider = Provider<QuizSessionController>((ref) {
  return QuizSessionController(ref);
});

/// Menyimpan urutan indeks opsi pilihan pengguna untuk soal puzzle (verse_order).
final userOrderProvider = StateProvider<List<int>?>((ref) => null);
// --- Implementasi Controller Kuis ---

class QuizSessionController {
  final Ref _ref;
  QuizSessionController(this._ref);

  String? _quizType;
  String? get quizType => _quizType;

  // Data sesi sementara yang disimpan di controller untuk pelacakan dan update
  // Ini adalah instance dari model Hive QuizSession yang akan dimutasi.
  QuizSession? _currentSessionData;
  int _correctAnswersCount = 0;
  int _incorrectAnswersCount = 0;

  /// Memulai sesi kuis baru.
  /// Menginisialisasi semua state Riverpod yang relevan dan menyimpan data sesi awal ke Hive.
  void startNewQuizSession({
    required List<RustModels.QuizQuestion> questions,
    required String quizType,
    required RustModels.QuizScope scope,
    required int requestedQuestionCount,
    required int actualQuestionCount,
  }) async {
    _quizType = quizType; // ✅ Simpan ke field

    final sessionBox = Hive.box<QuizSession>('quizSessions');
    final sessionId = const Uuid().v4();
    final startTime = DateTime.now();

    // Reset dan inisialisasi state Riverpod untuk sesi baru
    _ref.read(currentSessionIdProvider.notifier).state = sessionId;
    _ref.read(sessionStartTimeProvider.notifier).state = startTime;
    _ref.read(currentQuizQuestionsProvider.notifier).state = questions;
    _ref.read(currentQuestionIndexProvider.notifier).state = 0;
    _ref.read(selectedOptionIndexProvider.notifier).state = null;
    _ref.read(answerCheckedProvider.notifier).state = false;
    _ref.read(currentQuestionStartTimeProvider.notifier).state =
        DateTime.now(); // Mulai timer untuk soal pertama

    // Reset statistik hitungan benar/salah untuk sesi baru
    _correctAnswersCount = 0;
    _incorrectAnswersCount = 0;

    _log.info(
      'Memulai sesi kuis baru: $sessionId (Type: $quizType, Scope: ${_getScopeTypeName(scope)}, Soal: $actualQuestionCount)',
    );

    // Buat objek QuizSession baru untuk disimpan di Hive
    _currentSessionData = QuizSession(
      sessionId: sessionId,
      userId:
          'default_user', // TODO: Sesuaikan dengan ID pengguna sebenarnya jika ada sistem otentikasi
      quizType: quizType,
      scopeType: _getScopeTypeName(scope),
      scopeDetailsJson: jsonEncode(
        _convertScopeToMap(scope),
      ), // Konversi Map<dynamic,dynamic> ke string JSON
      requestedQuestionCount: requestedQuestionCount,
      actualQuestionCount: actualQuestionCount,
      startTime: startTime,
      endTime: DateTime.fromMillisecondsSinceEpoch(
        0,
      ), // Placeholder: akan diupdate di akhir sesi
      totalDurationSeconds: 0, // Placeholder: akan diupdate di akhir sesi
      correctAnswersCount: 0, // Akan diupdate per attempt
      incorrectAnswersCount: 0, // Akan diupdate per attempt
    );

    // Simpan sesi awal ke Hive. Menggunakan `sessionId` sebagai kunci box Hive.
    await sessionBox.put(sessionId, _currentSessionData!);
    _log.info('Sesi awal disisipkan ke Hive DB dengan ID: $sessionId.');
  }

  /// Helper untuk mendapatkan nama enum QuizScope sebagai String (misal: "All", "ByJuz").
  String _getScopeTypeName(RustModels.QuizScope scope) {
    return scope.map(
      all: (_) => 'All',
      byJuz: (value) => 'ByJuz',
      bySurah: (value) => 'BySurah',
    );
  }

  /// Helper untuk mengkonversi objek RustModels.QuizScope ke Map<String, dynamic> untuk penyimpanan JSON.
  Map<String, dynamic> _convertScopeToMap(RustModels.QuizScope scope) {
    return scope.map(
      all: (_) => {'type': 'all'}, // Contoh struktur jika tipe "All"
      byJuz: (value) => {
        'type': 'juz',
        'juzNumbers': value.juzNumbers.toList(),
      },
      bySurah: (value) => {'type': 'surah', 'surahId': value.surahId},
    );
  }

  /// Merekam percobaan jawaban pengguna untuk soal saat ini.
  /// Menyimpan data attempt ke Hive dan memperbarui statistik sesi yang sedang berjalan.
  void recordQuizAttempt() async {
    final attemptBox = Hive.box<QuizAttempt>('quizAttempts');
    final question = _ref.read(currentQuizQuestionProvider);
    final selectedOptionIndex = _ref.read(selectedOptionIndexProvider);
    final userOrder = _ref.read(
      userOrderProvider,
    ); // Tambahan untuk verse_order
    final sessionId = _ref.read(currentSessionIdProvider);
    final questionStartTime = _ref.read(currentQuestionStartTimeProvider);

    if (question == null) {
      _log.warning('Tidak ada soal aktif saat merekam attempt.');
      return;
    }

    final isPuzzle = question.quizType == 'verse_order';

    bool isCorrect;

    if (isPuzzle) {
      final correctOrder = question.correctOrderIndices ?? [];
      isCorrect =
          userOrder != null &&
          userOrder.length == correctOrder.length &&
          ListEquality().equals(userOrder, correctOrder);
    } else {
      if (selectedOptionIndex == null) {
        _log.warning('Pengguna belum memilih opsi.');
        return;
      }
      isCorrect = selectedOptionIndex == question.correctAnswerIndex;
    }

    final timeSpent = DateTime.now().difference(questionStartTime).inSeconds;
    final attemptId = const Uuid().v4();

    final newAttempt = QuizAttempt(
      attemptId: attemptId,
      sessionId: sessionId,
      questionIndex: _ref.read(currentQuestionIndexProvider),
      verseKey: question.verseKey,
      questionTextPart1: question.questionTextPart1,
      questionTextPart2: question.questionTextPart2,
      missingPartText: question.missingPartText,
      optionsJson: jsonEncode(
        question.options
            .map((opt) => HiveQuizOption.fromRustModel(opt).toMap())
            .toList(),
      ),
      userAnswerIndex: isPuzzle ? null : selectedOptionIndex,
      correctAnswerIndex: isPuzzle ? 0 : question.correctAnswerIndex,
      isCorrect: isCorrect,
      timeSpentSeconds: timeSpent,
      timestamp: DateTime.now(),
      userOrderIndicesJson: isPuzzle ? jsonEncode(userOrder) : null,
    );

    await attemptBox.put(attemptId, newAttempt);
    _log.info('Attempt tersimpan: $attemptId, isCorrect: $isCorrect');

    _ref.read(currentQuestionStartTimeProvider.notifier).state = DateTime.now();

    if (isCorrect) {
      _correctAnswersCount++;
    } else {
      _incorrectAnswersCount++;
    }
  }

  /// Memajukan ke soal kuis berikutnya atau menandakan kuis selesai.
  void nextQuestion() {
    final totalQuestions = _ref.read(currentQuizQuestionsProvider).length;
    final currentIndex = _ref.read(currentQuestionIndexProvider);

    if (currentIndex + 1 < totalQuestions) {
      // Pindah ke soal berikutnya
      _ref.read(currentQuestionIndexProvider.notifier).state++;
      // Reset state pilihan dan cek jawaban untuk soal baru
      _ref.read(selectedOptionIndexProvider.notifier).state = null;
      _ref.read(answerCheckedProvider.notifier).state = false;
      _ref.read(userOrderProvider.notifier).state = null;

      // Timer untuk soal berikutnya sudah di-reset di recordQuizAttempt jika soal dijawab.
      // Jika soal dilewati, timer akan dimulai saat nextQuestion dipanggil.
      _log.info(
        'Pindah ke soal berikutnya: ${currentIndex + 2}/${totalQuestions}',
      );
    } else {
      // Semua soal sudah dijawab
      _log.info('Semua soal sudah dijawab, sesi kuis akan berakhir.');
      // Pemanggilan `endQuizSession` akan dilakukan di halaman `QuizPlay` setelah navigasi `pop`.
    }
  }

  /// Mengakhiri sesi kuis.
  /// Memperbarui statistik akhir sesi di Hive.
  /// TIDAK MERESET STATE QUIZ INTI DI SINI.
  Future<void> endQuizSession() async {
    final sessionBox = Hive.box<QuizSession>('quizSessions');
    final sessionId = _ref.read(currentSessionIdProvider);

    final sessionToUpdate = sessionBox.get(sessionId);

    if (sessionToUpdate != null) {
      // Perbarui properti sesi dengan statistik akhir
      sessionToUpdate.endTime = DateTime.now();
      sessionToUpdate.totalDurationSeconds = sessionToUpdate.endTime
          .difference(sessionToUpdate.startTime)
          .inSeconds;
      sessionToUpdate.correctAnswersCount = _correctAnswersCount;
      sessionToUpdate.incorrectAnswersCount = _incorrectAnswersCount;

      // Simpan perubahan pada objek HiveObject. Ini akan update record di Box.
      await sessionToUpdate.save();
      _log.info(
        'Sesi kuis ${sessionId} berhasil diupdate di Hive DB (Benar: $_correctAnswersCount, Salah: $_incorrectAnswersCount).',
      );

      // Update provider hasil kuis agar QuizSummaryPage bisa membacanya
      _ref.read(lastQuizCorrectCountProvider.notifier).state =
          _correctAnswersCount;
      _ref.read(lastQuizIncorrectCountProvider.notifier).state =
          _incorrectAnswersCount;
      _ref.read(lastQuizTotalCountProvider.notifier).state =
          sessionToUpdate.actualQuestionCount;
    } else {
      _log.warning(
        'Tidak ada data sesi kuis aktif dengan ID: $sessionId ditemukan untuk diakhiri.',
      );
    }

    // Hanya reset data internal controller
    _currentSessionData = null;
    _correctAnswersCount = 0;
    _incorrectAnswersCount = 0;
    // PENTING: JANGAN RESET PROVIDER currentQuizQuestionsProvider, dll. DI SINI!
    // Reset ini akan dilakukan di QuizConfigPage.initState() saat kuis baru dimulai.
  }

  /// Mereset semua state kuis inti di Riverpod.
  /// Dipanggil saat memulai kuis baru atau kembali ke halaman konfigurasi.
  void resetAllQuizState() {
    _log.info('Mereset semua state kuis inti di Riverpod.');
    _ref.read(currentQuizQuestionsProvider.notifier).state = [];
    _ref.read(currentQuestionIndexProvider.notifier).state = 0;
    _ref.read(selectedOptionIndexProvider.notifier).state = null;
    _ref.read(answerCheckedProvider.notifier).state = false;
    _ref.read(currentSessionIdProvider.notifier).state = const Uuid()
        .v4(); // Generate ID sesi baru
    // lastQuiz...CountProvider tidak direset di sini karena mereka untuk rangkuman terakhir
  }
}
