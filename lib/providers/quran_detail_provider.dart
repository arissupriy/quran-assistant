import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/api/rust_engine_service.dart';
import 'package:quran_assistant/core/models/mushaf_model.dart';

/// Provider untuk mengambil data PageLayout berdasarkan nomor halaman.
///
/// Menggunakan .family untuk membuat provider dinamis yang menerima parameter.
/// Hasilnya akan di-cache secara otomatis oleh Riverpod, sehingga halaman yang
/// sama tidak akan di-fetch berulang kali.
final pageLayoutProvider = FutureProvider.family<PageLayout?, int>((ref, pageNumber) async {
  final rustService = RustEngineService();
  return rustService.getPageLayoutByPageNumber(pageNumber);
});

// Enum untuk merepresentasikan pilihan font yang tersedia.
enum QuranFont {
  uthmaniHafs,
  uthmaniHafsV22, // <-- BARU
  meQuran,
  quranCommon,    // <-- BARU
  surahNameV4,    // <-- BARU (Asumsi)
  uthmanTahaNaskh, // <-- BARU (Asumsi)
  indopak,        // <-- BARU (Asumsi)
}

/// Notifier untuk mengelola state font yang sedang aktif.
class FontSettingsNotifier extends StateNotifier<QuranFont> {
  // Atur font default saat pertama kali dibuat.
  FontSettingsNotifier() : super(QuranFont.uthmaniHafs);

  // Method untuk memperbarui font.
  void updateFont(QuranFont newFont) {
    state = newFont;
  }
}

/// Provider global untuk mengakses dan mengubah state font.
final fontSettingsProvider = StateNotifierProvider<FontSettingsNotifier, QuranFont>((ref) {
  return FontSettingsNotifier();
});