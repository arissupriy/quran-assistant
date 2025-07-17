import 'dart:math';
import 'dart:typed_data';
import 'dart:async'; // Import untuk Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Untuk Clipboard
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart'; // Import halaman download mushaf
import 'package:quran_assistant/providers/mushaf_provider.dart'; // Import providers Mushaf
import 'package:quran_assistant/src/rust/api/quran/verse.dart'; // Untuk getVerseByChapterAndVerseNumber
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';
import 'package:quran_assistant/src/rust/models.dart'; // Untuk Verse, GlyphPosition
import 'package:quran_assistant/utils/quran_utils.dart';
// import 'package:quran_assistant/core/models/mushaf_info.dart'; // Model MushafPageInfo
import 'package:quran_assistant/widgets/verse_detail_bottom_sheet.dart'; // Bottom sheet detail ayat
// import 'package:super_context_menu/super_context_menu.dart'; // Untuk ContextMenuWidget

// Helper extension untuk kapitalisasi string (jika tidak ada di file lain)
extension StringExtension on String {
  String toCapitalized() =>
      length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(
    RegExp(' +'),
    ' ',
  ).split(' ').map((str) => str.toCapitalized()).join(' ');
}

// --- BAGIAN MushafDetailPage ---
class MushafDetailPage extends ConsumerStatefulWidget {
  final int pageNumber;

  const MushafDetailPage({super.key, required this.pageNumber});

  @override
  ConsumerState<MushafDetailPage> createState() => _MushafDetailPageState();
}

class _MushafDetailPageState extends ConsumerState<MushafDetailPage> {
  Future<String?>? _mushafPathFuture;
  bool _navigated =
      false; // Flag untuk mencegah navigasi berulang ke download page
  late final PageController _pageController;

  bool _isAppBarVisible = true; // State visibilitas App Bar
  Timer? _hideAppBarTimer; // Timer untuk auto-hide App Bar
  int _currentPageNumber = 0; // Melacak nomor halaman yang sedang dilihat

  @override
  void initState() {
    super.initState();
    _currentPageNumber = widget.pageNumber;
    _pageController = PageController(initialPage: widget.pageNumber - 1);
    _mushafPathFuture = getMushafFilePathIfExists();

    _startHideAppBarTimer(); // Mulai timer auto-hide saat halaman pertama kali dimuat
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideAppBarTimer
        ?.cancel(); // Pastikan timer dibatalkan untuk mencegah memory leak
    super.dispose();
  }

  /// Memulai atau me-reset timer untuk menyembunyikan App Bar secara otomatis.
  void _startHideAppBarTimer() {
    _hideAppBarTimer?.cancel(); // Batalkan timer yang ada jika ada
    _hideAppBarTimer = Timer(const Duration(milliseconds: 1500), () {
      // Sembunyikan setelah 1.5 detik
      if (mounted) {
        // Pastikan widget masih terpasang sebelum memanggil setState
        setState(() {
          _isAppBarVisible = false;
        });
      }
    });
  }

  /// Mengganti visibilitas App Bar (toggle) dan mengatur ulang timer.
  void _toggleAppBarVisibility() {
    setState(() {
      _isAppBarVisible = !_isAppBarVisible; // Balik nilai _isAppBarVisible
    });
    if (_isAppBarVisible) {
      // Jika App Bar baru saja ditampilkan (atau sudah terlihat)
      _startHideAppBarTimer(); // Mulai ulang timer agar App Bar tetap terlihat selama 1.5 detik
    } else {
      // Jika App Bar baru saja disembunyikan secara manual
      _hideAppBarTimer
          ?.cancel(); // Batalkan timer yang ada (tidak perlu auto-hide lagi)
    }
  }

  /// Dipanggil saat halaman di PageView diganti (misal: karena swipe).
  void _onPageChanged(int index) {
    setState(() {
      _currentPageNumber = index + 1; // Update nomor halaman saat ini
    });
    // Jika App Bar terlihat, cukup reset timernya agar tetap muncul.
    // Jika App Bar tersembunyi, BIARKAN tetap tersembunyi saat user swipe.
    if (_isAppBarVisible) {
      _startHideAppBarTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hitung tinggi status bar dan tinggi AppBar standar untuk offset konten
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight =
        kToolbarHeight; // Konstanta untuk tinggi App Bar default
    final double totalTopOffset =
        statusBarHeight +
        appBarHeight; // Total offset vertikal dari tepi atas layar

    // Debugging offsets - Hapus atau comment jika tidak diperlukan di produksi
    debugPrint('DEBUG OFFSET: statusBarHeight = $statusBarHeight');
    debugPrint('DEBUG OFFSET: appBarHeight = $appBarHeight');
    debugPrint(
      'DEBUG OFFSET: totalTopOffset (from MushafDetailPage) = $totalTopOffset',
    );

    return FutureBuilder<String?>(
      future: _mushafPathFuture, // Memuat path mushaf.pack
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading(); // Tampilkan loading jika belum selesai
        }

        final path = snapshot.data; // Dapatkan path mushaf

        if (path == null) {
          // Jika path mushaf tidak ditemukan (belum diunduh)
          _navigateToDownloadPageIfNeeded(); // Arahkan ke halaman unduh
          return _buildLoading(); // Tampilkan loading saat navigasi
        }

        // Amati provider yang memuat mushaf dari path yang ditemukan
        final loadAsync = ref.watch(mushafLoadProvider(path));

        return loadAsync.when(
          loading: _buildLoading, // Tampilkan loading saat mushaf sedang dimuat
          error: (e, _) => _buildError(
            'Gagal membuka mushaf: $e',
          ), // Tampilkan error jika gagal
          data: (loaded) {
            if (!loaded) {
              // Jika pemuatan mushaf tidak berhasil
              return _buildError('Gagal membuka mushaf.');
            }

            return Scaffold(
              body: Stack(
                // Gunakan Stack sebagai body utama Scaffold
                children: [
                  // Konten utama halaman Mushaf (PageView) yang mengisi seluruh Stack
                  Positioned.fill(
                    child: GestureDetector(
                      onTap:
                          _toggleAppBarVisibility, // Deteksi tap pada body untuk toggle App Bar
                      child: PageView.builder(
                        controller: _pageController,
                        reverse:
                            true, // Untuk navigasi halaman kanan-ke-kiri (seperti Mushaf)
                        itemCount: 604, // Total halaman Mushaf Madani
                        onPageChanged:
                            _onPageChanged, // Listener saat halaman diganti
                        itemBuilder: (context, index) {
                          final currentPage = index + 1;
                          return MushafPageDisplay(
                            pageNumber: currentPage,
                            isAppBarVisible: _isAppBarVisible,
                            topOffset:
                                totalTopOffset, // Teruskan offset vertikal total ke MushafPageDisplay
                          );
                        },
                      ),
                    ),
                  ),
                  // App Bar sebagai Overlay (Positioned di atas konten)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      // Animasi fade in/out App Bar
                      opacity: _isAppBarVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: AppBar(
                        title: const Text('Mushaf Madani'),
                        centerTitle: true,
                        backgroundColor:
                            Theme.of(context).appBarTheme.backgroundColor ??
                            Theme.of(context).primaryColor,
                        foregroundColor:
                            Theme.of(context).appBarTheme.foregroundColor ??
                            Colors.white,
                        actions: [
                          // Menampilkan nomor halaman saat ini di App Bar
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Center(
                              child: Text(
                                'Halaman $_currentPageNumber / 604',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Menavigasi ke halaman unduh Mushaf jika file belum ada.
  void _navigateToDownloadPageIfNeeded() {
    // Mencegah navigasi berulang jika sudah pernah dinavigasi atau widget tidak terpasang
    if (_navigated || !mounted) return;
    _navigated = true; // Set flag navigated

    Future.microtask(() {
      // Jadwalkan navigasi setelah frame saat ini selesai
      if (mounted) {
        // Periksa lagi mounted sebelum pushReplacement
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MushafDownloadPage(initialPage: widget.pageNumber),
          ),
        );
      }
    });
  }

  /// Widget helper untuk tampilan loading.
  Widget _buildLoading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  /// Widget helper untuk tampilan error.
  Widget _buildError(String message) =>
      Scaffold(body: Center(child: Text(message)));
}

// --- BAGIAN MushafPageDisplay ---
class MushafPageDisplay extends ConsumerWidget {
  final int pageNumber;
  final bool isAppBarVisible;
  final double topOffset; // Terima offset total dari atas layar

  const MushafPageDisplay({
    super.key,
    required this.pageNumber,
    required this.isAppBarVisible,
    required this.topOffset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Amati provider untuk gambar halaman Mushaf
    final imageAsync = ref.watch(mushafImageProvider(pageNumber));
    // Amati provider untuk metadata glyph halaman
    final glyphAsync = ref.watch(mushafGlyphProvider(pageNumber));
    // Amati provider untuk ayat yang sedang di-highlight
    final highlighted = ref.watch(highlightedAyahProvider(pageNumber));
    // Amati provider untuk informasi kontekstual halaman (Surah, Juz, dll.)
    final pageInfoAsync = ref.watch(mushafPageInfoProvider(pageNumber));

    return imageAsync.when(
      loading: _loading,
      error: (e, _) => _error('Gagal memuat gambar: $e'),
      data: (imageBytes) {
        if (imageBytes == null) return _error('Gambar tidak ditemukan.');

        return glyphAsync.when(
          loading: _loading,
          error: (e, _) => _error('Gagal memuat glyph: $e'),
          data: (glyphs) {
            if (glyphs == null || glyphs.isEmpty)
              return _error('Glyph tidak ditemukan.');

            // Debugging pageInfo - hapus atau comment jika tidak diperlukan di produksi
            // debugPrint('✅ Page Info for page $pageNumber:');
            // debugPrint('  Surah Name: ${pageInfo.surahNameArabic}');
            // debugPrint('  Juz Number: ${pageInfo.juzNumber}');
            // debugPrint('  Page Number (from Info): ${pageInfo.pageNumber}');
            // debugPrint('  Next Page Route Text: ${pageInfo.nextPageRouteText}');

            return pageInfoAsync.when(
              loading: () {
                debugPrint('⌛ Loading page info for page $pageNumber...');
                return _loading();
              },
              error: (e, _) {
                debugPrint(
                  '❌ Error loading page info for page $pageNumber: $e',
                );
                return _error('Gagal memuat info halaman: $e');
              },
              data: (pageInfo) {
                return _MushafPageContent(
                  imageBytes: imageBytes,
                  glyphs: glyphs,
                  highlighted: highlighted,
                  isAppBarVisible: isAppBarVisible,
                  pageInfo: pageInfo,
                  topOffset:
                      topOffset, // Teruskan topOffset ke _MushafPageContent
                  onTap: (sura, ayah) {
                    // Logic untuk highlight ayat yang diklik dan menampilkan bottom sheet
                    final notifier = ref.read(
                      highlightedAyahProvider(pageNumber).notifier,
                    );
                    final tapped = (sura: sura, ayah: ayah);
                    notifier.state = notifier.state == tapped ? null : tapped;

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => VerseDetailBottomSheet(
                        verseKey: "${tapped.sura}:${tapped.ayah}",
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Widget helper untuk tampilan loading.
  Widget _loading() => const Center(child: CircularProgressIndicator());

  /// Widget helper untuk tampilan error.
  Widget _error(String msg) => Center(child: Text(msg));
}

class _MushafPageContent extends StatelessWidget {
  final Uint8List imageBytes;
  final List<GlyphPosition> glyphs;
  final ({int sura, int ayah})? highlighted;
  final bool isAppBarVisible;
  final MushafPageInfo pageInfo;
  final double topOffset;
  final void Function(int sura, int ayah) onTap;

  const _MushafPageContent({
    super.key,
    required this.imageBytes,
    required this.glyphs,
    required this.highlighted,
    required this.isAppBarVisible,
    required this.pageInfo,
    required this.topOffset,
    required this.onTap,
  });

  static const double FILE_IMG_WIDTH = 1080.0;
  static const double FILE_IMG_HEIGHT = 1747.0;
  static const double GLYPH_SOURCE_WIDTH = 1920.0;
  static const double GLYPH_SOURCE_HEIGHT = 3106.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final screenHeight = constraints.maxHeight;

      final imageMaxHeight = screenHeight * 0.8;

      final aspectRatioFileImg = FILE_IMG_WIDTH / FILE_IMG_HEIGHT;

      final renderedImageWidth = screenWidth;
      final renderedImageHeight = renderedImageWidth / aspectRatioFileImg;

      final double scale = renderedImageWidth / GLYPH_SOURCE_WIDTH;
      final double offsetY = (imageMaxHeight - renderedImageHeight) / 2;

      final ayahMap = <({int sura, int ayah}), List<GlyphPosition>>{};
      for (final glyph in glyphs) {
        final key = (sura: glyph.sura, ayah: glyph.ayah);
        ayahMap.putIfAbsent(key, () => []).add(glyph);
      }

      const double paddingY = 2.4;
      final highlightLayers = <Widget>[];

      if (highlighted != null && ayahMap.containsKey(highlighted)) {
        final glyphList = ayahMap[highlighted]!;
        final lineGroups = <int, List<GlyphPosition>>{};
        for (final g in glyphList) {
          lineGroups.putIfAbsent(g.lineNumber, () => []).add(g);
        }

        for (var group in lineGroups.entries) {
          final glyphs = group.value;
          final minX = (glyphs.map((g) => g.minX).reduce(min) * scale);
          final maxX = (glyphs.map((g) => g.maxX).reduce(max) * scale);
          final minY = (glyphs.map((g) => g.minY).reduce(min) * scale) + offsetY - paddingY;
          final maxY = (glyphs.map((g) => g.maxY).reduce(max) * scale) + offsetY + paddingY;

          highlightLayers.add(Positioned(
            left: minX,
            top: minY,
            width: maxX - minX,
            height: maxY - minY,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.yellow.withOpacity(0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ));
        }
      }

      return Column(
        children: [
          // INFO ATAS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoText(context, pageInfo.surahNameArabic, true),
                _infoText(context, 'Juz ${pageInfo.juzNumber}', false),
              ],
            ),
          ),

          // GAMBAR & HIGHLIGHT
          SizedBox(
            height: imageMaxHeight,
            child: Center(
              child: GestureDetector(
                onTapDown: (details) {
                  final localPos = details.localPosition;
                  for (var entry in ayahMap.entries) {
                    final glyphs = entry.value;
                    final minX = glyphs.map((g) => g.minX).reduce(min) * scale;
                    final maxX = glyphs.map((g) => g.maxX).reduce(max) * scale;
                    final minY = glyphs.map((g) => g.minY).reduce(min) * scale + offsetY - paddingY;
                    final maxY = glyphs.map((g) => g.maxY).reduce(max) * scale + offsetY + paddingY;

                    if (localPos.dx >= minX &&
                        localPos.dx <= maxX &&
                        localPos.dy >= minY &&
                        localPos.dy <= maxY) {
                      debugPrint("🎯 EXACT MATCH: ${entry.key.sura}:${entry.key.ayah}");
                      break;
                    }
                  }
                },
                child: Stack(
                  children: [
                    Image.memory(
                      imageBytes,
                      width: renderedImageWidth,
                      height: renderedImageHeight,
                      fit: BoxFit.contain,
                    ),
                    ...highlightLayers,
                    ...ayahMap.entries.map((entry) {
                      final glyphs = entry.value;
                      final minX = glyphs.map((g) => g.minX).reduce(min) * scale;
                      final maxX = glyphs.map((g) => g.maxX).reduce(max) * scale;
                      final minY = glyphs.map((g) => g.minY).reduce(min) * scale + offsetY - paddingY;
                      final maxY = glyphs.map((g) => g.maxY).reduce(max) * scale + offsetY + paddingY;

                      return Positioned(
                        left: minX,
                        top: minY,
                        width: maxX - minX,
                        height: maxY - minY,
                        child: GestureDetector(
                          onTap: isAppBarVisible ? () => onTap(entry.key.sura, entry.key.ayah) : null,
                          behavior: HitTestBehavior.translucent,
                          child: Container(color: Colors.transparent),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),

          // INFO BAWAH
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoText(context, pageInfo.nextPageRouteText.isEmpty ? '...' : pageInfo.nextPageRouteText, true),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade700.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    pageInfo.pageNumber.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _infoText(BuildContext context, String text, bool isRtl) {
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontFamily: isRtl ? 'UthmaniHafs' : null,
        ),
      ),
    );
  }
}




// --- END BAGIAN MushafDetailPage --- 