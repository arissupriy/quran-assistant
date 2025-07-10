// lib/providers/fts_search_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- Gunakan flutter_riverpod
import 'package:flutter/foundation.dart'; // Untuk @required jika masih dipakai, atau debug
import 'package:quran_assistant/core/api/rust_engine_service.dart'; // Import service Rust
import 'package:quran_assistant/core/models/fts_search_model.dart'; // Import model pencarian

// Definisikan State (immutable) yang akan dikelola oleh StateNotifier
class FtsSearchState {
  final List<FtsSearchResult> searchResults;
  final bool isLoading;
  final String? errorMessage;

  FtsSearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  // Metode copyWith untuk membuat state baru (immutable)
  FtsSearchState copyWith({
    List<FtsSearchResult>? searchResults,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FtsSearchState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Note: error messages should be cleared explicitly or passed null
    );
  }
}

// StateNotifier untuk mengelola state pencarian
class FtsSearchNotifier extends StateNotifier<FtsSearchState> {
  // Inisialisasi dengan state default
  FtsSearchNotifier() : super(FtsSearchState());

  final RustEngineService _rustEngineService = RustEngineService();

  /// Melakukan pencarian full-text dengan kueri yang diberikan.
  Future<void> search(String query) async {
    state = state.copyWith(isLoading: true, errorMessage: null); // Reset error, mulai loading

    try {
      final results = await _rustEngineService.searchFullText(query);
      state = state.copyWith(searchResults: results, isLoading: false);
      print('FtsSearchProvider: Ditemukan ${results.length} hasil untuk "$query"');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal melakukan pencarian: $e');
      print('FtsSearchProvider ERROR: ${state.errorMessage}');
    }
  }

  /// Membersihkan hasil pencarian.
  void clearSearchResults() {
    state = FtsSearchState(); // Kembali ke state default kosong
  }
}

// Provider global untuk FtsSearchNotifier
final ftsSearchProvider = StateNotifierProvider<FtsSearchNotifier, FtsSearchState>((ref) {
  return FtsSearchNotifier();
});