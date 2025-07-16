import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_detail_page.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
// import 'package:quran_assistant/pages/quiz/quiz_history_page.dart'; // Tidak perlu lagi diimpor jika hanya placeholder
import 'package:quran_assistant/providers/quran_provider.dart'; // Import quran_provider.dart untuk chaptersProvider dan juzListProvider
import 'package:quran_assistant/src/rust/data_loader/chapters.dart';
import 'package:quran_assistant/src/rust/data_loader/juzs.dart'; // Untuk JuzWithPage, Juz
import 'package:quran_assistant/src/rust/api/quran/chapter.dart'; // Untuk model Chapter
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:quran_assistant/core/themes/app_theme.dart'; // Import AppTheme

class QuranPage extends ConsumerStatefulWidget {
  const QuranPage({super.key});

  @override
  ConsumerState<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends ConsumerState<QuranPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true; // State untuk menunjukkan sedang memeriksa data
  bool _hasMushafData = false; // State untuk menunjukkan apakah data mushaf ada
  late TabController _tabController; // Controller untuk TabBar

  @override
  void initState() {
    super.initState();
    // Mengubah panjang TabController menjadi 3 (Juz, Surah, History)
    _tabController = TabController(length: 3, vsync: this);

    // Memastikan context tersedia sebelum melakukan pengecekan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMushafData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose(); // Buang controller saat widget dibuang
    super.dispose();
  }

  Future<void> _checkMushafData() async {
    final file = await getMushafDownloadedFile('data.mushafpack');
    if (file == null || !await file.exists()) {
      // Data tidak ditemukan, navigasi ke halaman download
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MushafDownloadPage(),
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
      return Container( // Menggunakan Container sebagai pengganti Scaffold karena Scaffold sudah ada di MainScreen
        color: AppTheme.backgroundColor, // Gunakan warna latar belakang dari tema
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor), // Gunakan warna primer dari tema
        ),
      );
    }

    if (!_hasMushafData) {
      return Container( // Menggunakan Container sebagai pengganti Scaffold
        color: AppTheme.backgroundColor,
        child: Center(
          child: Text(
            'Data Mushaf tidak tersedia. Silakan unduh.',
            style: TextStyle(color: AppTheme.textColor), // Gunakan warna teks dari tema
          ),
        ),
      );
    }

    // Jika data mushaf sudah ada, tampilkan konten utama QuranPage
    // Menggunakan Riverpod untuk mengawasi chaptersProvider dan juzListProvider
    final chaptersAsync = ref.watch(chaptersProvider);
    final juzListAsync = ref.watch(juzListProvider);

    return Column(
      children: [
        // Bagian "Last Read"
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            color: AppTheme.primaryColor, // Warna kartu sesuai tema
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16), // Sudut membulat
            ),
            elevation: 8, // Bayangan
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last Read',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8), // Warna teks sedikit transparan
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Al-Fatihah', // Contoh data
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Ayah No: 1', // Contoh data
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 
                  Image.network(
                    'https://placehold.co/100x100/00796B/FFFFFF?text=Quran', // Placeholder image
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.menu_book_rounded, size: 80, color: Colors.white.withOpacity(0.7)); // Fallback icon
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        // TabBar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor, // Latar belakang tab bar
              borderRadius: BorderRadius.circular(12), // Sudut membulat
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12), // Sudut membulat pada indikator
                color: AppTheme.primaryColor, // Menggunakan primaryColor untuk indikator aktif
              ),
              indicatorSize: TabBarIndicatorSize.tab, // Membuat indikator mengisi seluruh tab
              labelColor: Colors.white, // Warna teks tab yang dipilih
              unselectedLabelColor: AppTheme.secondaryTextColor, // Warna teks tab yang tidak dipilih
              // Mengubah tab menjadi Juz, Surah, dan History
              tabs: const [
                Tab(text: 'Juz'),
                Tab(text: 'Surah'),
                Tab(text: 'History'), // Tab History
              ],
            ),
          ),
        ),
        // Konten TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            // Mengubah urutan dan menambahkan tab baru
            children: [
              _buildJuzList(juzListAsync), // Tab Juz
              _buildSurahList(chaptersAsync), // Tab Surah
              // Placeholder untuk tab History
              Center(
                child: Text(
                  'Belum ada riwayat baca.',
                  style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget untuk membangun daftar Surah
  Widget _buildSurahList(AsyncValue<List<Chapter>> chaptersAsync) {
    return chaptersAsync.when(
      data: (chapters) {
        if (chapters.isEmpty) {
          return Center(child: Text('Tidak ada data Surah.', style: TextStyle(color: AppTheme.secondaryTextColor)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: chapters.length,
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1), // Latar belakang avatar
                  child: Text(
                    '${chapter.id}', // Nomor Surah
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  chapter.nameSimple, // Nama Surah sederhana
                  style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${chapter.revelationPlace} - ${chapter.versesCount} verses', // Tempat wahyu dan jumlah ayat
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                trailing: Text(
                  chapter.nameArabic, // Nama Surah Arab
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs', // Font Arab
                    fontSize: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
                onTap: () {
                  // Navigasi ke MushafDetailPage dengan nomor halaman pertama dari daftar chapter.pages
                  if (chapter.pages.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MushafDetailPage(pageNumber: chapter.pages[0]),
                      ),
                    );
                  } else {
                    // Opsional: Tampilkan pesan jika pages kosong
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nomor halaman untuk Surah ini tidak tersedia.')),
                    );
                  }
                },
              ),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      error: (error, stack) => Center(
        child: Text(
          'Gagal memuat data Surah: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  // Widget untuk membangun daftar Juz (Para)
  Widget _buildJuzList(AsyncValue<List<JuzWithPage>> juzListAsync) {
    return juzListAsync.when(
      data: (juzList) {
        if (juzList.isEmpty) {
          return Center(child: Text('Tidak ada data Juz.', style: TextStyle(color: AppTheme.secondaryTextColor)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: juzList.length,
          itemBuilder: (context, index) {
            final JuzWithPage item = juzList[index];
            final Juz juz = item.juz;
            final startPage = item.pageNumber;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () => _handleJuzTap(context, startPage),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                  child: Text(
                    juz.juzNumber.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                ),
                title: Text(
                  'Juz ${juz.juzNumber}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor),
                ),
                subtitle: Text(
                  'Total: ${juz.versesCount} ayat', // Hanya menampilkan total ayat
                  style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
                ),
                trailing: Icon(Icons.chevron_right, color: AppTheme.secondaryTextColor),
              ),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      error: (error, _) => Center(
        child: Text(
          'Gagal memuat data Juz: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  // Widget placeholder untuk Tab Page (tidak digunakan lagi di TabBarView)
  Widget _buildPageList() {
    return Center(
      child: Text(
        'Halaman akan ditampilkan di sini.',
        style: TextStyle(color: AppTheme.secondaryTextColor),
      ),
    );
  }

  // Widget placeholder untuk Tab Hijb (tidak digunakan lagi di TabBarView)
  Widget _buildHijbList() {
    return Center(
      child: Text(
        'Hijb akan ditampilkan di sini.',
        style: TextStyle(color: AppTheme.secondaryTextColor),
      ),
    );
  }
}
