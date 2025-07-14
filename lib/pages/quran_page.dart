import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_detail_page.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/quran_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/juzs.dart';
import 'package:quran_assistant/utils/quran_utils.dart';

class QuranPage extends ConsumerWidget {
  const QuranPage({super.key});

  Future<void> _handleJuzTap(BuildContext context, int startPage) async {
    final file = await getMushafDownloadedFile('data.mushafpack');

    if (file == null || !await file.exists()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MushafDownloadPage(initialPage: startPage),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MushafDetailPage(pageNumber: startPage),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final juzListAsync = ref.watch(juzListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Juz'),
        backgroundColor: Colors.teal.shade700,
      ),
      body: juzListAsync.when(
        data: (juzList) {
          return ListView.builder(
            itemCount: juzList.length,
            itemBuilder: (context, index) {
              final JuzWithPage item = juzList[index];
              final Juz juz = item.juz;
              final startPage = item.pageNumber;

              final verseRange = juz.verseMapping.entries.first.value;
              final surahKey = juz.verseMapping.entries.first.key;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                child: ListTile(
                  onTap: () => _handleJuzTap(context, startPage),
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
                    'Dimulai dari Surah $surahKey ayat $verseRange\nTotal: ${juz.versesCount} ayat',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat data: $error')),
      ),
    );
  }
}
