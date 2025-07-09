// lib/core/api/rust_engine_service.dart
import 'dart:convert'; // For jsonEncode, jsonDecode, utf8
import 'dart:ffi'; // For Pointer, allocate/free
import 'dart:typed_data'; // For Uint8List

import 'package:ffi/ffi.dart'; // For .toNativeUtf8, .toDartString, calloc, free

import 'package:quran_assistant/core/api/ffi.dart'
    as rust_ffi; // Mengimpor binding FFI
import 'package:quran_assistant/core/models/chapter_model.dart'; // Untuk Chapter, Verse, Word, AyahText
import 'package:quran_assistant/core/models/juz_model.dart'; // Untuk Juz
import 'package:quran_assistant/core/models/mushaf_model.dart'; // Untuk PageLayout, MushafWordData, Line
import 'package:quran_assistant/core/models/quiz_model.dart'; // Untuk QuizFilter, QuizGenerationResult, QuizScope, QuizQuestion, QuizOption, QuizGenerationErrorType
import 'package:quran_assistant/core/models/search_model.dart'; // Untuk AyahTextSearchResult, SimilarAyahItem, VerseHighlightMap, TranslationMetadata, SearchType

class RustEngineService {
  static final RustEngineService _instance = RustEngineService._internal();

  factory RustEngineService() {
    return _instance;
  }

  RustEngineService._internal();

  /// Menginisialisasi engine Rust. Harus dipanggil sekali saat aplikasi dimulai.
  void initEngine() {
    rust_ffi.initEngine();
    print('Rust Engine initialized.');
  }

  /// Helper untuk memanggil fungsi FFI yang mengembalikan JSON string (single object).
  /// Parameter `fromJson` menerima Map<String, dynamic> karena jsonDecode akan mengembalikan Map.
  T? _callJsonFunction<T>(
    Pointer<Utf8> Function() ffiCall,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final ptr = ffiCall();
    if (ptr == nullptr) {
      print('DEBUG_PAGELAYOUT_DETAIL: FFI call returned nullptr.');
      return null;
    }
    try {
      final jsonString = ptr.toDartString();
      // LOGGING SANGAT DETAIL UNTUK PAGELAYOUT
      print('DEBUG_PAGELAYOUT_DETAIL: Pointer address: ${ptr.address}');
      print(
        'DEBUG_PAGELAYOUT_DETAIL: JSON string length: ${jsonString.length}',
      );
      // Cetak raw JSON string dengan tanda kutip untuk melihat spasi/null byte tersembunyi
      print(
        'DEBUG_PAGELAYOUT_DETAIL: Raw JSON string (quoted): "${jsonString}"',
      );
      // Cetak panjang substring untuk memastikan tidak ada truncation tersembunyi
      print(
        'DEBUG_PAGELAYOUT_DETAIL: First 100 chars: "${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}"',
      );
      print(
        'DEBUG_PAGELAYOUT_DETAIL: Last 100 chars: "${jsonString.substring(jsonString.length > 100 ? jsonString.length - 100 : 0)}"',
      );

      if (jsonString == 'null') {
        print('DEBUG_PAGELAYOUT_DETAIL: Raw JSON string is "null".');
        return null;
      }
      final decodedJson = jsonDecode(jsonString);
      // LOGGING SANGAT DETAIL UNTUK PAGELAYOUT
      print('DEBUG_PAGELAYOUT_DETAIL: Decoded JSON: $decodedJson');
      print(
        'DEBUG_PAGELAYOUT_DETAIL: Decoded JSON runtimeType: ${decodedJson.runtimeType}',
      );

      if (decodedJson is Map<String, dynamic>) {
        print(
          'DEBUG_PAGELAYOUT_DETAIL: Decoded JSON is a Map. Parsing with fromJson.',
        );
        return fromJson(decodedJson);
      } else {
        // Inilah yang seharusnya menangkap error Anda
        print(
          'DEBUG_PAGELAYOUT_DETAIL: ERROR: Expected JSON object (Map), but received: $decodedJson (Type: ${decodedJson.runtimeType})',
        );
        return null;
      }
    } catch (e) {
      print('DEBUG_PAGELAYOUT_DETAIL: ERROR during JSON decoding: $e');
      print(
        'DEBUG_PAGELAYOUT_DETAIL: Raw JSON string during error (quoted): "${ptr.toDartString()}"',
      );
      return null;
    } finally {
      rust_ffi.freeString(ptr);
    }
  }

  /// Helper untuk memanggil fungsi FFI yang menerima string input dan mengembalikan JSON string (single object).
  T? _callJsonFunctionWithStringInput<T>(
    Pointer<Utf8> Function(Pointer<Utf8> input) ffiCall,
    String input,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final inputPtr = input.toNativeUtf8();
    try {
      final ptr = ffiCall(inputPtr);
      if (ptr == nullptr) {
        return null;
      }
      try {
        final jsonString = ptr.toDartString();
        if (jsonString == 'null') {
          return null;
        }
        final decodedJson = jsonDecode(jsonString);
        if (decodedJson is Map<String, dynamic>) {
          return fromJson(decodedJson);
        } else {
          print(
            'Error: _callJsonFunctionWithStringInput expected JSON object, but received: $decodedJson (Type: ${decodedJson.runtimeType})',
          );
          return null;
        }
      } catch (e) {
        print('Error decoding JSON from FFI for string input: $e');
        print('Raw JSON string: ${ptr.toDartString()}');
        return null;
      } finally {
        rust_ffi.freeString(ptr);
      }
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// Helper untuk memanggil fungsi FFI yang menerima string input dan mengembalikan JSON array.
  /// Parameter `fromJson` sekarang menerima `dynamic` karena item list bisa berupa Map atau primitive (String, int).
  List<T> _callJsonArrayFunctionWithStringInput<T>(
    Pointer<Utf8> Function(Pointer<Utf8> input) ffiCall,
    String input,
    T Function(dynamic jsonItem) fromJson,
  ) {
    final inputPtr = input.toNativeUtf8();
    try {
      final ptr = ffiCall(inputPtr);
      if (ptr == nullptr) {
        return [];
      }
      try {
        final jsonString = ptr.toDartString();
        if (jsonString == '[]' || jsonString == 'null') {
          return [];
        }
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        return jsonList.map((item) => fromJson(item)).toList();
      } catch (e) {
        print('Error decoding JSON array from FFI for string input: $e');
        print('Raw JSON string: ${ptr.toDartString()}');
        return [];
      } finally {
        rust_ffi.freeString(ptr);
      }
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// Helper untuk memanggil fungsi FFI yang mengembalikan JSON array.
  /// Parameter `fromJson` sekarang menerima `dynamic` karena item list bisa berupa Map atau primitive (String, int).
  List<T> _callJsonArrayFunction<T>(
    Pointer<Utf8> Function() ffiCall,
    T Function(dynamic jsonItem) fromJson,
  ) {
    final ptr = ffiCall();
    if (ptr == nullptr) {
      return [];
    }
    try {
      final jsonString = ptr.toDartString();
      if (jsonString == '[]' || jsonString == 'null') {
        return [];
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.map((item) => fromJson(item)).toList();
    } catch (e) {
      print('Error decoding JSON array from FFI: $e');
      print('Raw JSON string: ${ptr.toDartString()}');
      return [];
    } finally {
      rust_ffi.freeString(ptr);
    }
  }

  /// Helper untuk memanggil fungsi FFI kuis yang menerima bytes filter dan mengembalikan JSON.
  QuizGenerationResult _callQuizGenerator(
    // Perhatikan bahwa Dart sekarang mengirimkan Pointer<Uint8> dan int (panjang)
    // Ini berarti fungsi Rust juga harus menerima *const u8, usize
    Pointer<Utf8> Function(Pointer<Uint8> filterDataPtr, int filterLen) ffiCall,
    QuizFilter filter,
  ) {
    final filterJson = jsonEncode(filter.toJson());
    final filterBytes = utf8.encode(filterJson);

    final filterDataPtr = calloc<Uint8>(filterBytes.length);
    final filterUint8List = filterDataPtr.asTypedList(filterBytes.length);
    filterUint8List.setAll(0, filterBytes);

    Pointer<Utf8> ptr; // Declare ptr here
    try {
      ptr = ffiCall(filterDataPtr, filterBytes.length);
      if (ptr == nullptr) {
        print(
          'Quiz Generator FFI call returned a nullptr. This indicates a caught panic or unhandled error in Rust.',
        );
        return QuizGenerationResult(
          error: QuizGenerationErrorType.internalError,
        );
      }

      final jsonString = ptr.toDartString();
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return QuizGenerationResult.fromJson(jsonMap);
    } catch (e) {
      print('Error generating quiz from FFI: $e');
      return QuizGenerationResult(error: QuizGenerationErrorType.internalError);
    } finally {
      calloc.free(filterDataPtr);
      // Rust is responsible for freeing the output string ptr
    }
  }

  // --- Implementasi API Publik ---

  /// Mengembalikan jumlah total bab (surah).
  int getChaptersCount() {
    return rust_ffi.getChaptersCount();
  }

  /// Mengembalikan nama sederhana bab.
  String getChapterNameSimple(int chapterId) {
    final resultPtr = rust_ffi.getChapterNameSimple(chapterId);
    final name = resultPtr.toDartString();
    rust_ffi.freeString(resultPtr);
    return name == "Chapter Not Found" ? '' : name;
  }

  /// Mengembalikan detail bab.
  Chapter? getChapterDetails(int chapterId) {
    final chapter = _callJsonFunction(
      () => rust_ffi.getChapterDetails(chapterId),
      (json) => Chapter.fromJson(json),
    );
    // LOGGING TAMBAHAN UNTUK CHAPTER
    print(
      'DEBUG_CHAPTER_SERVICE: Chapter object after parsing: $chapter',
    ); // <-- TAMBAH INI
    print(
      'DEBUG_CHAPTER_SERVICE: Chapter nameSimple after parsing: ${chapter?.nameSimple}',
    ); // <-- TAMBAH INI
    return chapter;
  }

  /// Mengembalikan semua ayat dalam surah.
  List<AyahText> getAyahsBySurah(int chapterId) {
    return _callJsonArrayFunction(
      () => rust_ffi.getAyahsBySurah(chapterId),
      (jsonItem) => AyahText.fromJson(jsonItem as Map<String, dynamic>),
    );
  }

  /// Mengembalikan teks ayat Uthmani.
  String? getVerseTextUthmani(String verseKey) {
    final result = _callJsonFunctionWithStringInput(
      (inputPtr) => rust_ffi.getVerseTextUthmani(inputPtr),
      verseKey,
      (json) => json['text'] as String,
    );
    return result;
  }

  /// Mengembalikan Juz Number untuk Verse Key.
  int? getJuzNumberForVerse(String verseKey) {
    final result = _callJsonFunctionWithStringInput(
      (inputPtr) => rust_ffi.getJuzNumberForVerse(inputPtr),
      verseKey,
      (json) => json['juz_number'] as int,
    );
    return result;
  }

  /// Mengembalikan detail lengkap ayat (Verse).
  Verse? getVerseByChapterAndVerseNumber(int chapterId, int verseNumber) {
    return _callJsonFunction(
      () => rust_ffi.getVerseByChapterAndVerseNumber(chapterId, verseNumber),
      (json) => Verse.fromJson(json),
    );
  }

  /// Mengembalikan teks terjemahan untuk ayat tertentu.
  String? getTranslationText(String verseKey, int resourceId) {
    final inputPtr = verseKey.toNativeUtf8();
    try {
      final resultPtr = rust_ffi.getTranslationText(inputPtr, resourceId);
      final jsonString = resultPtr.toDartString();
      rust_ffi.freeString(resultPtr);

      if (jsonString == 'null' || jsonString == '{}') {
        return null;
      }
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonMap['translation'] as String?;
    } finally {
      calloc.free(inputPtr);
    }
  }

  /// Mengembalikan detail kata (Word).
  Word? getWordDetails(int chapterId, int verseNumber, int wordPosition) {
    return _callJsonFunction(
      () => rust_ffi.getWordDetails(chapterId, verseNumber, wordPosition),
      (json) => Word.fromJson(json),
    );
  }

  /// Mengembalikan PageLayout untuk nomor halaman.
  // NOTE: This function's `_callJsonFunction` usage with `(json) => PageLayout.fromJson(json)`
  // implies Rust returns a JSON object. If it returned a JSON array like `[{...}]`
  // or `PageLayout` itself was a list of objects, it would need `_callJsonArrayFunction`.
  // The log indicated `{"page":1,"lines":[...]}` which is an object.
  // The Dart error `type 'String' is not a subtype of type 'Map<String, dynamic>?'` for this call
  // is still puzzling if the JSON is truly valid. This helper specifically checks `decodedJson is Map<String, dynamic>`.
  PageLayout? getPageLayoutByPageNumber(int pageNumber) {
    return _callJsonFunction(
      () => rust_ffi.getPageLayoutByPageNumber(pageNumber),
      (json) => PageLayout.fromJson(json),
    );
  }

  /// Mengembalikan daftar WordData untuk baris tertentu.
  List<MushafWordData> getLineWords(int pageNumber, int lineIndex) {
    return _callJsonArrayFunction(
      () => rust_ffi.getLineWords(pageNumber, lineIndex),
      (jsonItem) => MushafWordData.fromJson(jsonItem as Map<String, dynamic>),
    );
  }

  /// Mengembalikan detail Juz.
  Juz? getJuzDetails(int juzNumber) {
    return _callJsonFunction(
      () => rust_ffi.getJuzDetails(juzNumber),
      (json) => Juz.fromJson(json),
    );
  }

  /// Mengembalikan nama metadata terjemahan.
  /// Fungsi Rust mengembalikan string literal JSON (misal: "\"Nama\"") atau "null".
  String? getTranslationMetadataById(int resourceId) {
    final ptr = rust_ffi.getTranslationMetadataById(resourceId);
    if (ptr == nullptr) {
      return null;
    }
    try {
      final jsonStringLiteral = ptr.toDartString();
      if (jsonStringLiteral == 'null') {
        return null;
      }
      return jsonDecode(jsonStringLiteral) as String;
    } catch (e) {
      print('Error decoding translation metadata JSON literal: $e');
      print('Raw JSON string literal: ${ptr.toDartString()}');
      return null;
    } finally {
      rust_ffi.freeString(ptr);
    }
  }

  /// Mengembalikan semua kunci ayat untuk lemma.
  List<String> getAllVerseKeysForLemma(String lemma) {
    return _callJsonArrayFunctionWithStringInput(
      (inputPtr) => rust_ffi.getAllVerseKeysForLemma(inputPtr),
      lemma,
      (jsonItem) => jsonItem as String,
    );
  }

  /// Mencari ayat berdasarkan bentuk kata dan tipe pencarian.
  List<AyahTextSearchResult> searchAyahsByWordForm(
    String query,
    SearchType searchType,
  ) {
    final queryPtr = query.toNativeUtf8();
    try {
      final resultPtr = rust_ffi.searchAyahsByWordForm(
        queryPtr,
        searchType.index,
      );
      final jsonString = resultPtr.toDartString();
      rust_ffi.freeString(resultPtr);

      print(
        'DEBUG_SEARCH: Raw JSON for searchAyahsByWordForm: $jsonString',
      ); // <-- TAMBAHKAN INI

      if (jsonString == '[]' || jsonString == 'null') {
        return [];
      }
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map(
            (item) =>
                AyahTextSearchResult.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } finally {
      calloc.free(queryPtr);
    }
  }

  /// Mengembalikan semua kunci ayat dalam daftar.
  List<String> getAllVerseKeysList() {
    return _callJsonArrayFunction(
      () => rust_ffi.getAllVerseKeysList(),
      (jsonItem) => jsonItem as String,
    );
  }

  /// Mencari frasa.
  List<String> searchPhrase(int phraseId) {
    return _callJsonArrayFunction(
      () => rust_ffi.searchPhrase(phraseId),
      (jsonItem) => jsonItem as String,
    );
  }

  /// Mencari terjemahan.
  List<String> searchTranslation(String query) {
    return _callJsonArrayFunctionWithStringInput(
      (inputPtr) => rust_ffi.searchTranslation(inputPtr),
      query,
      (jsonItem) => jsonItem as String,
    );
  }

  /// Mengembalikan ayat-ayat serupa.
  List<SimilarAyahItem> getSimilarAyahs(String verseKey) {
    return _callJsonArrayFunctionWithStringInput(
      (inputPtr) => rust_ffi.getSimilarAyahs(inputPtr),
      verseKey,
      (jsonItem) => SimilarAyahItem.fromJson(jsonItem as Map<String, dynamic>),
    );
  }

  /// Mengembalikan ID frasa per ayat.
  List<int> getPhrasesByAyah(String verseKey) {
    final result = _callJsonArrayFunctionWithStringInput(
      (inputPtr) => rust_ffi.getPhrasesByAyah(inputPtr),
      verseKey,
      (jsonItem) => jsonItem as int,
    );
    return result;
  }

  /// Mengembalikan sorotan frasa.
  VerseHighlightMap? getPhraseHighlight(int phraseId) {
    return _callJsonFunction(
      () => rust_ffi.getPhraseHighlight(phraseId),
      (json) => VerseHighlightMap.fromJson(json),
    );
  }

  /// Menghasilkan kuis Verse Completion.
  QuizGenerationResult generateVerseCompletionQuiz(QuizFilter filter) {
    return _callQuizGenerator(rust_ffi.generateVerseCompletionQuiz, filter);
  }

  /// Menghasilkan kuis Fragment Completion.
  QuizGenerationResult generateVerseFragmentQuiz(QuizFilter filter) {
    return _callQuizGenerator(rust_ffi.generateVerseFragmentQuiz, filter);
  }

  /// Menghasilkan kuis Verse Puzzle.
  QuizGenerationResult generateVersePuzzleQuiz(QuizFilter filter) {
    return _callQuizGenerator(rust_ffi.generateVersePuzzleQuiz, filter);
  }

  /// Menghasilkan kuis Word Puzzle.
  QuizGenerationResult generateWordPuzzleQuiz(QuizFilter filter) {
    return _callQuizGenerator(rust_ffi.generateWordPuzzleQuiz, filter);
  }
}
