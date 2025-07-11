import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/api/rust_engine_service.dart';
import 'package:quran_assistant/core/models/juz_model.dart';

/// Provider untuk mengambil daftar detail dari semua 30 Juz.
///
/// Menggunakan FutureProvider untuk efisiensi. Data akan diambil sekali
/// dan di-cache.
final juzListProvider = FutureProvider<List<Juz>>((ref) async {
  final rustService = RustEngineService();
  final List<Juz> juzList = [];

  // Looping untuk mengambil detail dari Juz 1 sampai 30
  for (int i = 1; i <= 30; i++) {
    final juzDetails = await rustService.getJuzDetails(i);
    if (juzDetails != null) {
      juzList.add(juzDetails);
    }
  }

  return juzList;
});