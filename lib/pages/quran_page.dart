import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/pages/mushaf_page.dart';
import 'package:quran_assistant/providers/quran_provider.dart';
import 'package:quran_assistant/pages/quran_detail_page.dart'; // <-- IMPOR HALAMAN DETAIL

class QuranPage extends ConsumerWidget {
  const QuranPage({super.key});

  // Fungsi untuk memperkirakan halaman awal Juz
  int _getStartPageForJuz(int juzNumber) {
    // Ini adalah pemetaan perkiraan. Anda mungkin perlu data yang lebih akurat.
    const juzStartPages = [
      1,
      22,
      42,
      62,
      82,
      102,
      121,
      142,
      162,
      182,
      201,
      222,
      242,
      262,
      282,
      302,
      322,
      342,
      362,
      382,
      402,
      422,
      442,
      462,
      482,
      502,
      522,
      542,
      562,
      582,
    ];
    if (juzNumber > 0 && juzNumber <= juzStartPages.length) {
      return juzStartPages[juzNumber - 1];
    }
    return 1; // Default ke halaman 1
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzListAsync = ref.watch(juzListProvider);

    return Scaffold(
      body: juzListAsync.when(
        data: (juzList) {
          return ListView.builder(
            itemCount: juzList.length,
            itemBuilder: (context, index) {
              final juz = juzList[index];
              final firstSurah = juz.verseMapping.mapping.keys.first;
              final verseRange = juz.verseMapping.mapping.values.first;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withOpacity(0.1),
                    child: Text(
                      juz.juzNumber.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                  title: Text(
                    'Juz ${juz.juzNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Dimulai dari Surah $firstSurah ayat $verseRange\nTotal: ${juz.versesCount} ayat',
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  // -- FUNGSI ONTAP UNTUK NAVIGASI --
                  onTap: () {
                    final startPage = _getStartPageForJuz(juz.juzNumber);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MushafDownloadPage(), // Ganti dengan halaman yang sesuai
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Gagal memuat data: $error')),
      ),
    );
  }
}
