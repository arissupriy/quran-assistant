// lib/core/models/fullsearch_model.dart

import 'package:flutter/foundation.dart';
import 'package:quran_assistant/core/models/search_model.dart'; // Impor SearchResultItem

// Enum untuk menentukan jenis pencarian
enum FullSearchType {
  general, // Pencarian umum di semua bidang relevan
  lemma,   // Pencarian berdasarkan lema
  root,    // Pencarian berdasarkan akar kata
  stem,    // Pencarian berdasarkan batang kata
}

// State untuk halaman pencarian
@immutable
class FullSearchState {
  final String query;
  final bool isLoading;
  final List<SearchResultItem> results;
  final String? errorMessage;
  final FullSearchType currentSearchType;

  const FullSearchState({
    this.query = '',
    this.isLoading = false,
    this.results = const [],
    this.errorMessage,
    this.currentSearchType = FullSearchType.general,
  });

  // Metode copyWith untuk mengupdate state dengan immutable pattern
  FullSearchState copyWith({
    String? query,
    bool? isLoading,
    List<SearchResultItem>? results,
    String? errorMessage,
    FullSearchType? currentSearchType,
  }) {
    return FullSearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      results: results ?? this.results,
      errorMessage: errorMessage ?? this.errorMessage,
      currentSearchType: currentSearchType ?? this.currentSearchType,
    );
  }
}