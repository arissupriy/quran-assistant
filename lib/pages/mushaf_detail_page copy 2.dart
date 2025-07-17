import 'dart:typed_data';
import 'dart:async'; // Import untuk Timer
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
import 'package:quran_assistant/src/rust/api/quran/verse.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';
import 'package:quran_assistant/src/rust/models.dart';
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:quran_assistant/widgets/verse_detail_bottom_sheet.dart';
// import 'package:super_context_menu/super_context_menu.dart';

class MushafDetailPage extends ConsumerStatefulWidget {
  final int pageNumber;

  const MushafDetailPage({super.key, required this.pageNumber});

  @override
  ConsumerState<MushafDetailPage> createState() => _MushafDetailPageState();
}

class _MushafDetailPageState extends ConsumerState<MushafDetailPage> {
  Future<String?>? _mushafPathFuture;
  bool _navigated = false;
  late final PageController _pageController;

  bool _isAppBarVisible = true;
  Timer? _hideAppBarTimer;
  int _currentPageNumber = 0;

  @override
  void initState() {
    super.initState();
    _currentPageNumber = widget.pageNumber;
    _pageController = PageController(initialPage: widget.pageNumber - 1);
    _mushafPathFuture = getMushafFilePathIfExists();

    _startHideAppBarTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideAppBarTimer?.cancel();
    super.dispose();
  }

  void _startHideAppBarTimer() {
    _hideAppBarTimer?.cancel();
    _hideAppBarTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isAppBarVisible = false;
        });
      }
    });
  }

  void _toggleAppBarVisibility() {
    setState(() {
      _isAppBarVisible = !_isAppBarVisible;
    });
    if (_isAppBarVisible) {
      _startHideAppBarTimer();
    } else {
      _hideAppBarTimer?.cancel();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPageNumber = index + 1;
    });
    // Jika app bar terlihat, cukup reset timernya.
    // Jika app bar tersembunyi, BIARKAN tetap tersembunyi saat user swipe.
    if (_isAppBarVisible) {
      _startHideAppBarTimer(); 
    }
    // Hapus logika else { _hideAppBarTimer?.cancel(); } karena itu sudah di handle oleh _toggleAppBarVisibility
  }

  @override
  Widget build(BuildContext context) {
    // Hitung tinggi status bar dan tinggi AppBar standar
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = kToolbarHeight;
    final double totalTopOffset = statusBarHeight + appBarHeight; // Total offset vertikal

    return FutureBuilder<String?>(
      future: _mushafPathFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading();
        }

        final path = snapshot.data;

        if (path == null) {
          _navigateToDownloadPageIfNeeded();
          return _buildLoading();
        }

        final loadAsync = ref.watch(mushafLoadProvider(path));

        return loadAsync.when(
          loading: _buildLoading,
          error: (e, _) => _buildError('Gagal membuka mushaf: $e'),
          data: (loaded) {
            if (!loaded) {
              return _buildError('Gagal membuka mushaf.');
            }

            return Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _toggleAppBarVisibility,
                      child: PageView.builder(
                        controller: _pageController,
                        reverse: true,
                        itemCount: 604,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          final currentPage = index + 1;
                          return MushafPageDisplay(
                            pageNumber: currentPage,
                            isAppBarVisible: _isAppBarVisible,
                            topOffset: totalTopOffset, // --- TERUSKAN OFFSET INI ---
                          );
                        },
                      ),
                    ),
                  ),
                  // APP BAR SEBAGAI OVERLAY
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _isAppBarVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: AppBar(
                        title: const Text('Mushaf Madani'),
                        centerTitle: true,
                        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).primaryColor,
                        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
                        actions: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Center(
                              child: Text(
                                'Halaman $_currentPageNumber / 604',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _navigateToDownloadPageIfNeeded() {
    if (_navigated || !mounted) return; 
    _navigated = true;

    Future.microtask(() {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MushafDownloadPage(initialPage: widget.pageNumber),
          ),
        );
      }
    });
  }

  Widget _buildLoading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _buildError(String message) =>
      Scaffold(body: Center(child: Text(message)));
}

class MushafPageDisplay extends ConsumerWidget {
  final int pageNumber;
  final bool isAppBarVisible;
  final double topOffset; // Terima offset

  const MushafPageDisplay({
    super.key,
    required this.pageNumber,
    required this.isAppBarVisible,
    required this.topOffset, // Pastikan ini di required
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(mushafImageProvider(pageNumber));
    final glyphAsync = ref.watch(mushafGlyphProvider(pageNumber));
    final highlighted = ref.watch(highlightedAyahProvider(pageNumber));
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
            if (glyphs == null || glyphs.isEmpty) return _error('Glyph tidak ditemukan.');

            return pageInfoAsync.when(
              loading: () {
                debugPrint('⌛ Loading page info for page $pageNumber...');
                return _loading();
              },
              error: (e, _) {
                debugPrint('❌ Error loading page info for page $pageNumber: $e');
                return _error('Gagal memuat info halaman: $e');
              },
              data: (pageInfo) {
                // Debug Print sudah ada di kode Anda yang sebelumnya
                // debugPrint('✅ Page Info for page $pageNumber:');
                // debugPrint('  Surah Name: ${pageInfo.surahNameArabic}');
                // debugPrint('  Juz Number: ${pageInfo.juzNumber}');
                // debugPrint('  Page Number (from Info): ${pageInfo.pageNumber}');
                // debugPrint('  Next Page Route Text: ${pageInfo.nextPageRouteText}');

                return _MushafPageContent(
                  imageBytes: imageBytes,
                  glyphs: glyphs,
                  highlighted: highlighted,
                  isAppBarVisible: isAppBarVisible,
                  pageInfo: pageInfo,
                  topOffset: topOffset, // --- TERUSKAN OFFSET INI ---
                  onTap: (sura, ayah) {
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

  Widget _loading() => const Center(child: CircularProgressIndicator());
  Widget _error(String msg) => Center(child: Text(msg));
}

// _MushafPageContent tetap seperti sebelumnya, karena bagian DeferredMenuPreview
// sudah menerapkan Directionality dengan textDirection: TextDirection.rtl dan textAlign: TextAlign.right.
// Pastikan VerseDetailBottomSheet juga menerapkan ini pada teks Arab di dalamnya.
extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  // toTitleCase sudah ada di file lain, tidak perlu didefinisikan ulang di sini
}


class _MushafPageContent extends StatelessWidget {
  final Uint8List imageBytes;
  final List<GlyphPosition> glyphs;
  final ({int sura, int ayah})? highlighted;
  final bool isAppBarVisible;
  final MushafPageInfo pageInfo;
  final double topOffset; // Offset dari atas (statusBarHeight + appBarHeight)
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 1920.0; // Asumsi lebar gambar Mushaf asli adalah 1920px

        final ayahMap = <({int sura, int ayah}), List<GlyphPosition>>{};
        for (final glyph in glyphs) {
          final key = (sura: glyph.sura, ayah: glyph.ayah);
          ayahMap.putIfAbsent(key, () => []).add(glyph);
        }

        List<Widget> highlightLayers = [];
        if (highlighted != null && ayahMap.containsKey(highlighted)) {
          final ayahGlyphs = ayahMap[highlighted]!;

          final lineGroups = <int, List<GlyphPosition>>{};
          for (var glyph in ayahGlyphs) {
            lineGroups.putIfAbsent(glyph.lineNumber, () => []).add(glyph);
          }

          for (var entry in lineGroups.entries) {
            final lineGlyphs = entry.value;
            final minX = lineGlyphs.map((g) => g.minX).reduce((a, b) => a < b ? a : b) * scale;
            final maxX = lineGlyphs.map((g) => g.maxX).reduce((a, b) => a > b ? a : b) * scale;
            final minY = (lineGlyphs.map((g) => g.minY).reduce((a, b) => a < b ? a : b) * scale) + topOffset * 1.1; 
            final maxY = (lineGlyphs.map((g) => g.maxY).reduce((a, b) => a > b ? a : b) * scale) + topOffset * 1.1; 

            highlightLayers.add(
              Positioned(
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
              ),
            );
          }
        }

        return Stack(
          children: [
            // Gambar Mushaf Utama
            Image.memory(
              imageBytes,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              fit: BoxFit.contain,
            ),
            // Lapisan Highlight Ayah
            ...highlightLayers,
            // Detektor Tap Ayah (untuk menu konteks)
            ...ayahMap.entries.map((entry) {
              final ayahKey = entry.key;
              final minX = entry.value.map((g) => g.minX).reduce((a, b) => a < b ? a : b) * scale;
              final maxX = entry.value.map((g) => g.maxX).reduce((a, b) => a > b ? a : b) * scale;
              final minY = (entry.value.map((g) => g.minY).reduce((a, b) => a < b ? a : b) * scale) + topOffset;
              final maxY = (entry.value.map((g) => g.maxY).reduce((a, b) => a > b ? a : b) * scale) + topOffset;

              return Positioned(
                left: minX,
                top: minY,
                width: maxX - minX,
                height: maxY - minY,
                child: GestureDetector(
                  onTap: isAppBarVisible ? () => onTap(ayahKey.sura, ayahKey.ayah) : null,
                  behavior: HitTestBehavior.translucent,
                  // child: ContextMenuWidget(
                  //   menuProvider: (_) { /* ... */ },
                  //   deferredPreviewBuilder: (context, child, cancellationToken) { /* ... */ },
                  //   child: Container(
                  //     color: Colors.transparent,
                  //   ),
                  // ),
                ),
              );
            }).toList(),

            // --- INFORMASI KONTEKSTUAL: PENEMPATAN ULANG ---

            // Nama Surah (Oren): Pojok Kiri Atas
            Positioned(
              top: scale + topOffset * 0.5, // <-- NAIK LEBIH ATAS (dari 30)
              left: 120 * scale , // <-- Lebih dekat ke kiri (dari 40)
              child: _buildInfoText(
                context,
                text: pageInfo.surahNameArabic.isEmpty ? 'N/A' : pageInfo.surahNameArabic,
                textColor: Colors.black,
                fontSize: 18,
                isRtl: true,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Nomor Juz (Kuning): Pojok Kanan Atas
            Positioned(
              top: scale + topOffset * 0.5, // <-- NAIK LEBIH ATAS (dari 30)
              right: 120 * scale, // <-- Lebih dekat ke kanan (dari 40)
              child: _buildInfoText(
                context,
                text: 'Juz ${pageInfo.juzNumber}',
                textColor: Colors.black,
                fontSize: 16,
                isRtl: false,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Nomor Halaman (Hijau): Tengah Bawah
            Positioned(
              bottom: 30 * scale,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                 
                  child: _buildInfoText(
                    context,
                    text: pageInfo.pageNumber.toString(),
                    textColor: Colors.black,
                    fontSize: 18,
                    isRtl: false,
                    fontWeight: FontWeight.bold,
                    hasBackground: false,
                  ),
                ),
              ),
            ),
            // Kata Awal Halaman Selanjutnya / Penanda Juz (Merah): Pojok Kiri Bawah
            Positioned(
              bottom: 100 * scale, // <-- Pindah ke bottom: 30 (sama dengan nomor halaman)
              left: 120 * scale, // <-- Konsisten dengan padding kiri
              child: _buildInfoText(
                context,
                text: pageInfo.nextPageRouteText.isEmpty ? '...' : pageInfo.nextPageRouteText,
                textColor: Colors.black,
                fontSize: 18,
                isRtl: true,
                fontWeight: FontWeight.bold,
              ),
            ),
            // --- AKHIR INFORMASI KONTEKSTUAL ---
          ],
        );
      },
    );
  }

  // Helper Widget untuk menampilkan teks informasi
  Widget _buildInfoText(BuildContext context, {
    required String text,
    required Color textColor,
    required double fontSize,
    required bool isRtl,
    FontWeight fontWeight = FontWeight.w500, // Default fontWeight ke w500
    bool hasBackground = false, 
    Color? backgroundColor, 
    double horizontalPadding = 0, 
    double verticalPadding = 0,   
    double borderRadius = 0,      
  }) {
    final safeText = text.isNotEmpty ? text : '';

    Widget textWidget = Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Text(
        safeText,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: textColor,
          fontFamily: isRtl ? 'UthmaniHafs' : null,
        ),
        textAlign: isRtl ? TextAlign.right : TextAlign.left,
      ),
    );

    if (hasBackground) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent, 
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: textWidget,
      );
    } else {
      return textWidget;
    }
  }
}