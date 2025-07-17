import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_detail_page.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/quran_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/chapters.dart';
import 'package:quran_assistant/src/rust/data_loader/juzs.dart';
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/widgets/last_read_card.dart'; // BARU: Import widget baru

class QuranPage extends ConsumerStatefulWidget {
  const QuranPage({super.key});

  @override
  ConsumerState<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends ConsumerState<QuranPage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasMushafData = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMushafData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkMushafData() async {
    final file = await getMushafDownloadedFile('data.mushafpack');
    if (file == null || !await file.exists()) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MushafDownloadPage(),
          ),
        );
      }
    } else {
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
      return Container(
        color: AppTheme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (!_hasMushafData) {
      return Container(
        color: AppTheme.backgroundColor,
        child: Center(
          child: Text(
            'Data Mushaf tidak tersedia. Silakan unduh.',
            style: TextStyle(color: AppTheme.textColor),
          ),
        ),
      );
    }

    final chaptersAsync = ref.watch(chaptersProvider);
    final juzListAsync = ref.watch(juzListProvider);

    return Column(
      children: [
        // Card "Last Read" (sekarang menggunakan LastReadCard)
        const LastReadCard(isHomePage: false), // Beri tahu widget bahwa ini bukan home_page
        // TabBar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.primaryColor,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.secondaryTextColor,
              tabs: const [
                Tab(text: 'Juz'),
                Tab(text: 'Surah'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
        // Konten TabBarView
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildJuzList(juzListAsync),
              _buildSurahList(chaptersAsync),
              _buildHistoryList(),
            ],
          ),
        ),
      ],
    );
  }

  // Helper widgets _buildNoReadSessionWidget, _buildLoadingLastReadWidget,
  // _buildErrorLastReadWidget, _buildLastReadContent,
  // _buildLoadingLastReadContent, _buildErrorLastReadContent
  // telah dipindahkan ke last_read_card.dart

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
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    '${chapter.id}',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  chapter.nameSimple,
                  style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${chapter.revelationPlace} - ${chapter.versesCount} verses',
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                trailing: Text(
                  chapter.nameArabic,
                  style: TextStyle(
                    fontFamily: 'UthmanicHafs',
                    fontSize: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
                onTap: () {
                  if (chapter.pages.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MushafDetailPage(pageNumber: chapter.pages[0]),
                      ),
                    );
                  } else {
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
                  'Total: ${juz.versesCount} ayat',
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

  Widget _buildHistoryList() {
    final readingSessionsAsync = ref.watch(allReadingSessionsStreamProvider);

    return readingSessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Center(
            child: Text(
              'Belum ada riwayat baca.',
              style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
            ),
          );
        }

        final last10Sessions = sessions.take(10).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: last10Sessions.length,
          itemBuilder: (context, index) {
            final session = last10Sessions[index];
            final formattedDate = DateFormat('dd MMM yyyy HH:mm').format(session.openedAt);
            final durationText = '${session.duration.inMinutes} min ${session.duration.inSeconds % 60} sec';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    '${session.page}',
                    style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  'Page ${session.page}',
                  style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Read on: $formattedDate\nDuration: $durationText',
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MushafDetailPage(pageNumber: session.page),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      error: (error, stack) => Center(
        child: Text(
          'Gagal memuat riwayat baca: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
