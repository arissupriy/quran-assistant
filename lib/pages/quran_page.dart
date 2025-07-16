import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_detail_page.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/quran_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/juzs.dart';
import 'package:quran_assistant/utils/quran_utils.dart';

class QuranPage extends ConsumerStatefulWidget {
  const QuranPage({super.key});

  @override
  ConsumerState<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends ConsumerState<QuranPage> {
  bool _isLoading = true; // State untuk menunjukkan sedang memeriksa data
  bool _hasMushafData = false; // State untuk menunjukkan apakah data mushaf ada

  @override
  void initState() {
    super.initState();
    // Memastikan context tersedia sebelum melakukan pengecekan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMushafData();
    });
  }

  Future<void> _checkMushafData() async {
    final file = await getMushafDownloadedFile('data.mushafpack');
    if (file == null || !await file.exists()) {
      // Data tidak ditemukan, navigasi ke halaman download
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MushafDownloadPage(), // Tidak perlu initialPage di sini
          ),
        );
      }
    } else {
      // Data ditemukan, perbarui state untuk menampilkan konten halaman
      if (mounted) {
        setState(() {
          _hasMushafData = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJuzTap(BuildContext context, int startPage) async {
    // Metode ini hanya akan dipanggil jika _hasMushafData sudah true,
    // jadi bisa langsung menavigasi ke MushafDetailPage.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafDetailPage(pageNumber: startPage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Tampilkan indikator loading saat pemeriksaan data
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Jika _hasMushafData false, ini seharusnya tidak tercapai karena pushReplacement,
    // tapi sebagai fallback atau untuk kejelasan:
    if (!_hasMushafData) {
      return const Scaffold(
        body: Center(
          child: Text('Data Mushaf tidak tersedia. Silakan unduh.'),
        ),
      );
    }

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