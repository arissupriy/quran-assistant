// // lib/providers/search_provider.dart
// import 'dart:async'; // Untuk Timer

// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:quran_assistant/core/api/rust_engine_service.dart_';
// import 'package:quran_assistant/core/models/search_model.dart'; // Import SearchType dan AyahTextSearchResult
// import 'package:quran_assistant/core/models/chapter_model.dart_'; // Import Chapter model untuk chapter details

// // 1. Definisikan State/Notifier untuk manajemen state pencarian
// class SearchState {
//   final String query;
//   final List<AyahTextSearchResult> results;
//   final bool isLoading;
//   final String? errorMessage;

//   SearchState({
//     this.query = '',
//     this.results = const [],
//     this.isLoading = false,
//     this.errorMessage,
//   });

//   // Metode copyWith untuk membuat state baru (immutable)
//   SearchState copyWith({
//     String? query,
//     List<AyahTextSearchResult>? results,
//     bool? isLoading,
//     String? errorMessage,
//   }) {
//     return SearchState(
//       query: query ?? this.query,
//       results: results ?? this.results,
//       isLoading: isLoading ?? this.isLoading,
//       errorMessage: errorMessage ?? this.errorMessage,
//     );
//   }
// }

// // 2. Definisikan Notifier untuk mengelola state pencarian
// class SearchNotifier extends StateNotifier<SearchState> {
//   SearchNotifier() : super(SearchState());

//   final RustEngineService _rustService = RustEngineService();

//   // performSearch sekarang akan selalu memproses semua SearchType
//   Future<void> performSearch(String newQuery) async {
//     if (newQuery.trim().isEmpty) {
//       state = state.copyWith(query: newQuery, results: [], errorMessage: null);
//       return;
//     }

//     state = state.copyWith(
//       query: newQuery,
//       isLoading: true,
//       errorMessage: null,
//     );

//     try {
//       final List<AyahTextSearchResult> combinedResults = [];
//       final Set<String> seenVerseKeys = {}; // Untuk melacak duplikat

//       // Iterasi langsung semua SearchType yang tersedia
//       for (final searchType in SearchType.values) {
//         final currentTypeResults = _rustService.searchAyahsByWordForm(
//           newQuery,
//           searchType,
//         );
//         for (final ayah in currentTypeResults) {
//           if (!seenVerseKeys.contains(ayah.verseKey)) {
//             combinedResults.add(ayah);
//             seenVerseKeys.add(ayah.verseKey);
//           }
//         }
//       }

//       // Pengurutan eksplisit di Dart (berdasarkan Surah dan Nomor Ayat)
//       combinedResults.sort((a, b) {
//         final aParts = a.verseKey.split(':');
//         final bParts = b.verseKey.split(':');

//         final aChapterId = int.tryParse(aParts[0]) ?? 0;
//         final bChapterId = int.tryParse(bParts[0]) ?? 0;

//         final aVerseNumber = int.tryParse(aParts[1]) ?? 0;
//         final bVerseNumber = int.tryParse(bParts[1]) ?? 0;

//         int chapterComparison = aChapterId.compareTo(bChapterId);
//         if (chapterComparison != 0) {
//           return chapterComparison;
//         }
//         return aVerseNumber.compareTo(bVerseNumber);
//       });

//       state = state.copyWith(results: combinedResults, isLoading: false);
//     } catch (e) {
//       state = state.copyWith(
//         isLoading: false,
//         errorMessage: 'Terjadi kesalahan saat pencarian: $e',
//       );
//     }
//   }
// }

// // 3. Definisikan Provider utama untuk pencarian
// final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
//   ref,
// ) {
//   return SearchNotifier();
// });

// // chapterDetailsProvider tetap di sini karena ia terkait dengan chapterDetailsProvider yang digunakan di SearchPage
// final chapterDetailsProvider = FutureProvider.family<Chapter?, int>((
//   ref,
//   chapterId,
// ) async {
//   final RustEngineService rustService = RustEngineService();
//   return rustService.getChapterDetails(chapterId);
// });
