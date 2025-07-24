import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/api/quran/search.dart';
import 'package:quran_assistant/src/rust/data_loader/search_models.dart'; // model dari Rust
import 'package:quran_assistant/src/rust/frb_generated.dart'; // <- ftsSearch dari FRB

// Immutable state untuk pencarian
class FtsSearchState {
  final String query;
  final List<SearchResult> searchResults;
  final bool isLoading;
  final String? errorMessage;
  final bool showTranslation;

  FtsSearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.errorMessage,
    this.query = '',
    this.showTranslation = false,
  });

  FtsSearchState copyWith({
    String? query,
    List<SearchResult>? searchResults,
    bool? isLoading,
    String? errorMessage,
    bool? showTranslation,
  }) {
    return FtsSearchState(
      query: query ?? this.query,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }
}

class FtsSearchNotifier extends StateNotifier<FtsSearchState> {
  FtsSearchNotifier() : super(FtsSearchState());

  /// Melakukan pencarian full-text dengan kueri dari Rust (FFI).
  Future<void> search(String query) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      query: query,
    );

    try {
      final results = await ftsSearch(query: query); // ← panggil fungsi dari frb_generated.dart

      state = state.copyWith(
        searchResults: results,
        isLoading: false,
      );

      print('FtsSearchProvider: Ditemukan ${results.length} hasil untuk "$query"');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal melakukan pencarian: $e',
      );
      print('FtsSearchProvider ERROR: ${state.errorMessage}');
    }
  }

  /// Membersihkan hasil pencarian.
  void clearSearchResults() {
    state = FtsSearchState(
      showTranslation: state.showTranslation,
    );
  }

  /// Toggle tampilkan terjemahan
  void toggleShowTranslation() {
    state = state.copyWith(showTranslation: !state.showTranslation);
  }
}

// Provider global
final ftsSearchProvider =
    StateNotifierProvider<FtsSearchNotifier, FtsSearchState>((ref) {
  return FtsSearchNotifier();
});
