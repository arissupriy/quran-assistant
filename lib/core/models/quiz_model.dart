// lib/core/models/quiz_model.dart

// Merepresentasikan satu opsi jawaban dalam kuis.
class QuizOption {
  final String text;
  final bool isCorrect;

  QuizOption({
    required this.text,
    required this.isCorrect,
  });

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      text: json['text'] ?? '',
      isCorrect: json['is_correct'] ?? false,
    );
  }
}

// Merepresentasikan satu pertanyaan kuis yang lengkap.
class QuizQuestion {
  final String verseKey;
  final String questionTextPart1;
  final String questionTextPart2;
  final String missingPartText;
  final List<QuizOption> options;
  final int correctAnswerIndex; // Corrected typo
  final List<int>? correctOrderIndices; // Bisa null
  final String quizType;

  QuizQuestion({
    required this.verseKey,
    required this.questionTextPart1,
    required this.questionTextPart2,
    required this.missingPartText,
    required this.options,
    required this.correctAnswerIndex, // Corrected typo
    this.correctOrderIndices,
    required this.quizType,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      verseKey: json['verse_key'] ?? '',
      questionTextPart1: json['question_text_part1'] ?? '',
      questionTextPart2: json['question_text_part2'] ?? '',
      missingPartText: json['missing_part_text'] ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((optionJson) => QuizOption.fromJson(optionJson))
              .toList() ??
          [],
      correctAnswerIndex: json['correct_answer_index'] ?? 0, // Corrected typo
      correctOrderIndices: (json['correct_order_indices'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      quizType: json['quiz_type'] ?? '',
    );
  }
}

// Merepresentasikan cakupan dari mana soal kuis akan dibuat.
// Ini akan diubah menjadi JSON untuk dikirim ke Rust.
class QuizScope {
  final List<int>? byJuz;
  final int? bySurah;
  final String? all; // Representing QuizScope::All

  QuizScope.all()
      : byJuz = null,
        bySurah = null,
        all = 'All'; // Rust's `All` is `{"All": null}`

  QuizScope.juz(List<int> juzNumbers)
      : byJuz = juzNumbers,
        bySurah = null,
        all = null;

  QuizScope.surah(int surahId)
      : byJuz = null,
        bySurah = surahId,
        all = null;

  Map<String, dynamic> toJson() {
    if (byJuz != null) {
      return {
        'ByJuz': {'juz_numbers': byJuz}
      };
    }
    if (bySurah != null) {
      return {
        'BySurah': {'surah_id': bySurah}
      };
    }
    // Default to 'All' if neither specific scope is set
    return {'All': null};
  }
}

// Filter utama yang akan dikirim ke Rust.
class QuizFilter {
  final QuizScope scope;

  QuizFilter({required this.scope});

  Map<String, dynamic> toJson() {
    return {
      'scope': scope.toJson(),
    };
  }
}

// Enum untuk jenis error yang mungkin terjadi.
enum QuizGenerationErrorType {
  noVersesInScope,
  noValidQuestionFound,
  internalError,
  unknown
}

// Hasil dari pembuatan kuis, bisa berisi pertanyaan atau error.
class QuizGenerationResult {
  final QuizQuestion? question;
  final QuizGenerationErrorType? error;

  QuizGenerationResult({this.question, this.error});

  factory QuizGenerationResult.fromJson(Map<String, dynamic> json) {
    QuizGenerationErrorType? errorType;
    if (json['error'] != null) {
      // Di Rust, enumnya adalah objek. Misal: {"NoVersesInScope":null} atau {"InternalError":"message"}
      final errorMap = json['error'] as Map<String, dynamic>;
      final errorKey = errorMap.keys.first;
      switch (errorKey) {
        case 'NoVersesInScope':
          errorType = QuizGenerationErrorType.noVersesInScope;
          break;
        case 'NoValidQuestionFound':
          errorType = QuizGenerationErrorType.noValidQuestionFound;
          break;
        case 'InternalError':
          errorType = QuizGenerationErrorType.internalError;
          // Optionally, you can extract the error message: errorMap[errorKey]
          break;
        default:
          errorType = QuizGenerationErrorType.unknown;
      }
    }

    return QuizGenerationResult(
      question:
          json['question'] != null ? QuizQuestion.fromJson(json['question']) : null,
      error: errorType,
    );
  }
}