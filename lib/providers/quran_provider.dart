import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/api/quran/metadata.dart';
import 'package:quran_assistant/src/rust/data_loader/juzs.dart';
// import 'package:quran_assistant/core/api/rust_engine_service.dart';
// import 'package:quran_assistant/core/models/juz_model.dart';

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