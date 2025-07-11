// lib/providers/fts_search_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart'; // <-- Gunakan flutter_riverpod
import 'package:quran_assistant/core/api/rust_engine_service.dart'; // Import service Rust
import 'package:quran_assistant/core/models/fts_search_model.dart'; // Import model pencarian

// Definisikan State (immutable) yang akan dikelola oleh StateNotifier
class FtsSearchState {
  final String query;
  final List<FtsSearchResult> searchResults;
  final bool isLoading;
  final String? errorMessage;
  final bool showTranslation; // <-- TAMBAHKAN INI
  


  FtsSearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.errorMessage,
    this.query = '',
    this.showTranslation = false, // Default ke true
  });

  // Metode copyWith untuk membuat state baru (immutable)
  FtsSearchState copyWith({
    String? query,
    List<FtsSearchResult>? searchResults,
    bool? isLoading,
    String? errorMessage,
    bool? showTranslation, // <-- TAMBAHKAN INI
  }) {
    return FtsSearchState(
      query: query ?? this.query,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Note: error messages should be cleared explicitly or passed null
      showTranslation: showTranslation ?? this.showTranslation,
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
    state = FtsSearchState(showTranslation: state.showTranslation); // Kembali ke state default kosong
  }

   // Method untuk mengubah status tampilkan terjemahan
  void toggleShowTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }
}

// Provider global untuk FtsSearchNotifier
final ftsSearchProvider = StateNotifierProvider<FtsSearchNotifier, FtsSearchState>((ref) {
  return FtsSearchNotifier();
});