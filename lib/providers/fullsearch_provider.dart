// lib/providers/full_search_provider.dart

import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:convert';

import 'package:ffi/ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/models/fullsearch_model.dart';
import 'package:quran_assistant/core/models/search_model.dart';
import 'package:quran_assistant/core/models/chapter_model.dart'; // Make sure Chapter is defined here or imported correctly

// Asumsi ChapterDetailsProvider ada di chapter_model.dart
final chapterDetailsProvider = FutureProvider.family<Chapter?, int>((ref, chapterId) async {
  // Implementasi untuk mendapatkan detail bab
  // Ini mungkin perlu memuat data bab dari Rust atau dari aset lokal
  // Untuk mock, Anda bisa mengembalikan Chapter dummy
  return Chapter(
    id: chapterId,
    revelationPlace: 'makkah',
    revelationOrder: 1,
    bismillahPre: true,
    nameSimple: 'Al-Fatihah',
    // nameComplex: 'Al-Fatihah',
    nameArabic: 'الفاتحة',
    versesCount: 7,
    pages: [1,1],
    translatedName: TranslatedName(languageName: 'indonesian', name: 'Pembukaan'),
  ); // Contoh data dummy
});


// Definisikan tipe fungsi Rust FFI
typedef SearchQuranNative = Pointer<Utf8> Function(Pointer<Utf8> query, Uint32 limit);
typedef SearchQuranDart = Pointer<Utf8> Function(Pointer<Utf8> query, int limit);

typedef SearchAyahsByWordFormNative = Pointer<Utf8> Function(Pointer<Utf8> query, Uint32 limit, Pointer<Utf8> formType);
typedef SearchAyahsByWordFormDart = Pointer<Utf8> Function(Pointer<Utf8> query, int limit, Pointer<Utf8> formType);

typedef FreeRustStringNative = Void Function(Pointer<Utf8>);
typedef FreeRustStringDart = void Function(Pointer<Utf8>);
final DynamicLibrary _rustLib = _loadLibrary();

DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libhafiz_assistant_engine.so');
  } else if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.process();
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('hafiz_assistant_engine.dll'); // Di Windows, nama umumnya tanpa 'lib'
  } else {
    throw UnsupportedError('Platform not supported for Rust FFI');
  }
}

// Lookup fungsi Rust
final SearchQuranDart _searchQuran = _rustLib
    .lookupFunction<SearchQuranNative, SearchQuranDart>('search_quran_index');

final SearchAyahsByWordFormDart _searchAyahsByWordForm = _rustLib
    .lookupFunction<SearchAyahsByWordFormNative, SearchAyahsByWordFormDart>('search_ayahs_by_word_form');

final FreeRustStringDart _freeRustString = _rustLib
    .lookupFunction<FreeRustStringNative, FreeRustStringDart>('free_string');


// StateNotifier untuk mengelola state pencarian
class FullSearchNotifier extends StateNotifier<FullSearchState> {
  FullSearchNotifier() : super(const FullSearchState());

  Future<void> performSearch(String query, {FullSearchType searchType = FullSearchType.general}) async {
    if (query.isEmpty) {
      state = state.copyWith(query: '', results: [], isLoading: false, errorMessage: null, currentSearchType: searchType);
      return;
    }

    state = state.copyWith(isLoading: true, query: query, errorMessage: null, currentSearchType: searchType);

    // --- PERBAIKAN DI SINI ---
    // Deklarasikan queryC di luar blok try agar bisa diakses di finally
    Pointer<Utf8>? queryC;
    Pointer<Utf8>? formTypeC; // Deklarasikan formTypeC juga jika digunakan di finally untuk bebas memori

    try {
      queryC = query.toNativeUtf8(); // Inisialisasi di sini

      Pointer<Utf8> resultC;

      if (searchType == FullSearchType.general) {
        resultC = _searchQuran(queryC, 10);
      } else {
        formTypeC = searchType.name.toNativeUtf8(); // Inisialisasi formTypeC
        resultC = _searchAyahsByWordForm(queryC, 10, formTypeC);
        // Bebaskan formTypeC segera setelah digunakan
        malloc.free(formTypeC);
        formTypeC = nullptr; // Set ke nullptr setelah dibebaskan
      }
      
      final String resultJson = resultC.toDartString();
      _freeRustString(resultC);
      // Set resultC ke nullptr setelah dibebaskan
      resultC = nullptr;

      final List<dynamic> jsonList = json.decode(resultJson) as List<dynamic>;

      if (jsonList.isEmpty && resultJson.contains('"error"')) {
        final Map<String, dynamic> errorMap = json.decode(resultJson);
        throw Exception('Rust Error: ${errorMap['error']}');
      }

      final List<SearchResultItem> newResults = jsonList
          .map((json) => SearchResultItem.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(results: newResults, isLoading: false);

    } catch (e) {
      state = state.copyWith(errorMessage: 'Terjadi kesalahan: $e', isLoading: false, results: []);
      print('Error calling Rust FFI: $e');
    } finally {
      // Pastikan pointer tidak null sebelum membebaskan memori
      if (queryC != null) {
        malloc.free(queryC);
      }
      // formTypeC sudah dibebaskan di dalam if-else, tidak perlu di sini lagi
    }
  }
}

// Provider untuk FullSearchNotifier
final fullSearchProvider = StateNotifierProvider<FullSearchNotifier, FullSearchState>((ref) {
  return FullSearchNotifier();
});