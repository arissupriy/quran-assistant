import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart'; // Untuk lastReadInfoProvider
// import 'package:quran_assistant/src/rust/api/quran/chapter.dart';
// import 'package:quran_assistant/src/rust/api/quran/metadata.dart';
import 'package:quran_assistant/src/rust/data_loader/chapters.dart';
// import 'package:quran_assistant/src/rust/api/quran/chapter.dart'; // Untuk Chapter model

// Derived provider untuk menggabungkan data sesi terakhir dan nama Surah
// final lastReadDisplayDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
//   debugPrint('DEBUG_PROVIDER_CARD: lastReadDisplayDataProvider: Memulai proses.');
//   final lastReadSession = await ref.watch(lastReadInfoProvider.future);

//   debugPrint('DEBUG_PROVIDER_CARD: Last Read Session (dari lastReadInfoProvider): ${lastReadSession?.toString()}');
//   if (lastReadSession == null) {
//     debugPrint('DEBUG_PROVIDER_CARD: lastReadDisplayDataProvider: lastReadSession adalah null, mengembalikan isAvailable: false.');
//     return {'isAvailable': false};
//   }

//   final chapter = await getChapterByPageNumber(pageNumber: lastReadSession.page);
//   // debugPrint('DEBUG_PROVIDER_CARD: Detail Chapter untuk Surah ID ${pageInfo.chapterIds.first}: ${chapter?.nameSimple ?? 'Tidak ditemukan'}');


//   // debugPrint('DEBUG_PROVIDER_CARD: Nama Surah yang ditentukan: $surahName');

//   debugPrint('Chapter untuk halaman ${lastReadSession.page}: ${chapter?.nameSimple ?? 'Tidak ditemukan'}');

//   return {
//     'isAvailable': true,
//     'session': lastReadSession,
//     'surahName': chapter?.nameSimple ?? 'Unknown Surah', // Gunakan nama kompleks untuk lebih informatif
//     'chapter': chapter, // BARU: Sertakan objek Chapter lengkap
//   };
// });


class LastReadCard extends ConsumerWidget {
  // completionPercentage sekarang bisa dihapus karena akan dihitung di dalam widget
  // final double completionPercentage; // Properti untuk persentase kelengkapan
  final bool isHomePage; // Untuk membedakan gaya di home_page vs quran_page

  const LastReadCard({
    super.key,
    // this.completionPercentage = 0.0, // Hapus atau jadikan opsional jika tidak lagi digunakan
    this.isHomePage = false, // Default false, berarti untuk quran_page
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastReadDisplayDataAsync = ref.watch(lastReadDisplayDataProvider);

    // INISIALISASI VARIABEL DENGAN WIDGET LOADING DEFAULT
    Widget lastReadContentWidget = _buildLoadingContent(isHomePage); // Menggunakan helper baru

    // Default completion percentage, akan dihitung ulang jika data tersedia
    double currentCompletionPercentage = 0.0;

    lastReadDisplayDataAsync.when(
      data: (info) {
        if (!info['isAvailable']) {
          lastReadContentWidget = _buildNoReadSessionContent(isHomePage);
        } else {
          final lastReadSession = info['session'] as ReadingSession;
          final surahName = info['surahName'] as String;
          final progressPercentage = info['progressPercentage'];

          currentCompletionPercentage = progressPercentage != null ? (progressPercentage as double)/100 : 0.0;

          // // BARU: Hitung persentase jika ini adalah home_page dan chapter tersedia
          // if (isHomePage && chapter != null && chapter.pages.isNotEmpty) {
          //   final firstPageOfSurah = chapter.pages.first;
          //   final lastPageOfSurah = chapter.pages.last;
          //   final totalSurahPages = (lastPageOfSurah - firstPageOfSurah + 1);
            
          //   // Pastikan pageNumber terakhir yang dibaca berada dalam rentang halaman Surah ini
          //   if (lastReadSession.page >= firstPageOfSurah && lastReadSession.page <= lastPageOfSurah) {
          //       final currentPageWithinSurah = (lastReadSession.page - firstPageOfSurah + 1);
          //       currentCompletionPercentage = totalSurahPages > 0 ? currentPageWithinSurah / totalSurahPages : 0.0;
          //   } else {
          //       // Jika halaman terakhir yang dibaca tidak berada dalam rentang Surah ini,
          //       // mungkin karena Surah tersebut dimulai di halaman yang berbeda dari yang diharapkan
          //       // atau sesi bacaan tidak valid untuk Surah ini.
          //       // Untuk kesederhanaan, kita bisa set ke 0 atau log peringatan.
          //       debugPrint('WARNING: Halaman terakhir (${lastReadSession.page}) tidak dalam rentang Surah ${surahName} (Halaman ${firstPageOfSurah}-${lastPageOfSurah}).');
          //       currentCompletionPercentage = 0.0;
          //   }
          // } else if (isHomePage && chapter == null) {
          //   debugPrint('WARNING: Chapter data is null for last read session on homepage.');
          //   currentCompletionPercentage = 0.0;
          // }

          lastReadContentWidget = _buildDataContent(lastReadSession, surahName, isHomePage);
        }
      },
      loading: () {
        lastReadContentWidget = _buildLoadingContent(isHomePage);
      },
      error: (error, stack) {
        lastReadContentWidget = _buildErrorContent(error, isHomePage);
      },
    );

    return Card(
      color: isHomePage ? Colors.transparent : AppTheme.primaryColor, // Warna kartu sesuai tema
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Sudut membulat
      ),
      elevation: isHomePage ? 0 : 8, // Bayangan
      margin: isHomePage ? EdgeInsets.zero : const EdgeInsets.all(16.0), // Margin
      child: Container(
        decoration: isHomePage ? BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ) : null, // Tidak ada dekorasi jika bukan home_page
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Judul "Terakhir dibaca" atau "Quran Completion"
                    Text(
                      isHomePage ? 'Quran Completion' : 'Terakhir dibaca',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // AnimatedSwitcher for dynamic last read content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: lastReadContentWidget, // Display content based on provider state
                    ),
                    if (isHomePage) ...[ // Tampilkan progress bar hanya di home_page
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: currentCompletionPercentage, // Gunakan persentase yang dihitung
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        borderRadius: BorderRadius.circular(5),
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(currentCompletionPercentage * 100).toInt()}%', // Tampilkan persentase yang dihitung
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.menu_book_rounded, size: 80, color: Colors.white.withOpacity(0.7))
            ],
          ),
        ),
      ),
    );
  }

  // Helper widgets untuk konten yang berbeda
  Widget _buildNoReadSessionContent(bool isHomePage) {
    return Column(
      key: const ValueKey('no_session_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Belum ada bacaan.',
          style: TextStyle(
            color: Colors.white,
            fontSize: isHomePage ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isHomePage) const SizedBox(height: 8),
        Text(
          'Mulai membaca Al-Quran!',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: isHomePage ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent(bool isHomePage) {
    return Column(
      key: const ValueKey('loading_main_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Memuat...',
          style: TextStyle(
            color: Colors.white,
            fontSize: isHomePage ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isHomePage) const SizedBox(height: 8),
        Text(
          'Mohon tunggu.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: isHomePage ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(Object error, bool isHomePage) {
    return Column(
      key: const ValueKey('error_main_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Error memuat data.',
          style: TextStyle(
            color: Colors.redAccent,
            fontSize: isHomePage ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isHomePage) const SizedBox(height: 8),
        Text(
          '${error}',
          style: TextStyle(
            color: Colors.redAccent.withOpacity(0.8),
            fontSize: isHomePage ? 14 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDataContent(ReadingSession session, String surahName, bool isHomePage) {
    return Column(
      key: ValueKey('data_content_${session.page}_$surahName'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isHomePage ? '$surahName (Halaman ${session.page})' : surahName,
          style: TextStyle(
            color: Colors.white,
            fontSize: isHomePage ? 18 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (!isHomePage) // "Halaman No: X" hanya di quran_page
          Text(
            'Halaman No: ${session.page}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
      ],
    );
  }
}
