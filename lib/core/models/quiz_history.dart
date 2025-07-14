// lib/models/quiz_history.dart
import 'package:hive/hive.dart';
import 'package:quran_assistant/src/rust/data_loader/quiz_models.dart' as RustModels; // Untuk model Rust QuizOption

part 'quiz_history.g.dart'; // File yang akan digenerate oleh hive_generator

@HiveType(typeId: 0) // typeId harus unik di seluruh aplikasi
class QuizSession extends HiveObject {
  // `id` bisa menjadi `key` box Hive atau field biasa
  @HiveField(0)
  late String sessionId; // Gunakan sessionId sebagai primary key di Hive Box

  @HiveField(1)
  late String userId;
  @HiveField(2)
  late String quizType;
  @HiveField(3)
  late String scopeType;
  @HiveField(4)
  late String scopeDetailsJson; // Simpan JSON string
  @HiveField(5)
  late int requestedQuestionCount;
  @HiveField(6)
  late int actualQuestionCount;
  @HiveField(7)
  late DateTime startTime;
  
  // Bidang-bidang ini TIDAK BOLEH final karena nilainya akan diupdate
  @HiveField(8)
  late DateTime endTime; 
  @HiveField(9)
  late int totalDurationSeconds;
  @HiveField(10)
  late int correctAnswersCount;
  @HiveField(11)
  late int incorrectAnswersCount;

  QuizSession({
    required this.sessionId,
    required this.userId,
    required this.quizType,
    required this.scopeType,
    required this.scopeDetailsJson,
    required this.requestedQuestionCount,
    required this.actualQuestionCount,
    required this.startTime,
    // Pastikan parameter ini juga ada di konstruktor
    required this.endTime, 
    required this.totalDurationSeconds, 
    required this.correctAnswersCount, 
    required this.incorrectAnswersCount,
  });

  // Metode toMap/fromMap tidak lagi diperlukan oleh Hive (generator)
  // Anda juga bisa menambahkan `copyWith` jika diperlukan untuk membuat instance baru
  // misalnya untuk Riverpod StateProvider.
}

@HiveType(typeId: 1) // typeId harus unik
class QuizAttempt extends HiveObject {
  @HiveField(0)
  late String attemptId;
  @HiveField(1)
  late String sessionId; // Foreign key manual ke QuizSession
  @HiveField(2)
  late int questionIndex;
  @HiveField(3)
  late String verseKey;
  @HiveField(4)
  late String questionTextPart1;
  // --- TAMBAH INI ---
  @HiveField(5) // Perhatikan bahwa @HiveField index ini harus unik dan berurutan
  late String questionTextPart2;
  // --- AKHIR TAMBAH INI ---
  @HiveField(6)
  late String missingPartText; // Index HiveField yang ini akan berubah jika ada penambahan di atasnya
  @HiveField(7)
  late String optionsJson;
  @HiveField(8)
  late int? userAnswerIndex;
  @HiveField(9)
  late int correctAnswerIndex;
  @HiveField(10)
  late bool isCorrect;
  @HiveField(11)
  late int timeSpentSeconds;
  @HiveField(12) // Index HiveField yang ini akan berubah
  late DateTime timestamp;

  QuizAttempt({
    required this.attemptId,
    required this.sessionId,
    required this.questionIndex,
    required this.verseKey,
    required this.questionTextPart1,
    // --- TAMBAH INI DI KONSTRUKTOR ---
    required this.questionTextPart2,
    // --- AKHIR TAMBAH INI ---
    required this.missingPartText,
    required this.optionsJson,
    required this.userAnswerIndex,
    required this.correctAnswerIndex,
    required this.isCorrect,
    required this.timeSpentSeconds,
    required this.timestamp,
  });
}

@HiveType(typeId: 2) // typeId harus unik
class HiveQuizOption { 
  @HiveField(0)
  final String text; // Ini bisa tetap final jika Anda tidak pernah mengubah opsi
  @HiveField(1)
  final bool isCorrect; // Ini juga bisa tetap final

  HiveQuizOption({required this.text, required this.isCorrect});

  factory HiveQuizOption.fromRustModel(RustModels.QuizOption rustOption) {
    return HiveQuizOption(text: rustOption.text, isCorrect: rustOption.isCorrect);
  }

  // --- TAMBAHAN KUNCI: Metode toMap() ini ---
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'is_correct': isCorrect,
    };
  }
  // --- AKHIR TAMBAHAN ---
}