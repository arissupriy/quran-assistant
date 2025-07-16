import 'package:flutter/material.dart'; // Tetap diperlukan untuk debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/api/quran/metadata.dart'; // Untuk getChapters()
import 'package:quran_assistant/src/rust/data_loader/chapters.dart';
import 'package:quran_assistant/src/rust/data_loader/juzs.dart'; // Untuk getAllJuzsWithPage()
import 'package:quran_assistant/src/rust/api/quran/chapter.dart'; // Untuk getChapters() dan model Chapter

/// Provider untuk mengambil daftar detail dari semua 30 Juz.
///
/// Menggunakan FutureProvider untuk efisiensi. Data akan diambil sekali
/// dan di-cache.
final juzListProvider = FutureProvider<List<JuzWithPage>>((ref) async {
  final list = await getAllJuzsWithPage();

  // Debug: cek duplikat
  final seen = <int>{};
  for (final item in list) {
    if (!seen.add(item.juz.juzNumber)) {
      debugPrint('⚠️ Duplikat ditemukan: Juz ${item.juz.juzNumber}');
    }
  }

  return list;
});

/// Provider untuk mengambil daftar semua Chapter (Surah).
///
/// Menggunakan FutureProvider untuk efisiensi. Data akan diambil sekali
/// dan di-cache.
final chaptersProvider = FutureProvider<List<Chapter>>((ref) async {
  final list = await getAllChapters();

  // Anda bisa menambahkan debug/validasi jika diperlukan di sini
  // Misalnya, memeriksa apakah semua chapter ada atau tidak ada duplikat.

  return list;
});
