import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:quran_assistant/pages/mushaf_detail_page%20copy%202.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
import 'package:quran_assistant/src/rust/api/quran/verse.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';
import 'package:quran_assistant/src/rust/models.dart';
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:quran_assistant/widgets/ayah_context_menu.dart';
import 'package:quran_assistant/widgets/verse_detail_bottom_sheet.dart';
import 'package:super_context_menu/super_context_menu.dart';

// extension StringExtension on String {
//   String toCapitalized() =>
//       length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
//   String toTitleCase() => replaceAll(
//     RegExp(' +'),
//     ' ',
//   ).split(' ').map((str) => str.toCapitalized()).join(' ');
// }

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

  Timer? _hideAppBarTimer;
  int _currentPageNumber = 0;

  @override
  void deactivate() {
    // ref.invalidate(highlightedAyahProvider);
    super.deactivate();
  }

  @override
  void initState() {
    super.initState();
    _currentPageNumber = widget.pageNumber;
    _pageController = PageController(initialPage: widget.pageNumber - 1);
    _mushafPathFuture = getMushafFilePathIfExists();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appBarVisibilityProvider.notifier).state = true;
      }
    });
    _startHideAppBarTimer();
    _loadInitialPageInfo();
  }

  void _loadInitialPageInfo() {
    ref.read(mushafPageInfoProvider(_currentPageNumber).future).then((
      pageInfo,
    ) {
      if (mounted) {
        ref.read(currentPageInfoProvider.notifier).state = pageInfo;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideAppBarTimer?.cancel();

    // Jadwalkan invalidate di frame berikutnya (tidak crash meski dispose)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // ref.invalidate(highlightedAyahProvider);
      }
    });

    super.dispose();
  }

  void _startHideAppBarTimer() {
    _hideAppBarTimer?.cancel();
    _hideAppBarTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        ref.read(appBarVisibilityProvider.notifier).state = false;
      }
    });
  }

  void _toggleAppBarVisibility() {
    final current = ref.read(appBarVisibilityProvider);
    final newValue = !current;

    debugPrint("🔺 Toggling app bar visibility: $current → $newValue");
    ref.read(appBarVisibilityProvider.notifier).state = newValue;

    if (newValue) {
      _startHideAppBarTimer();
    } else {
      _hideAppBarTimer?.cancel();
    }
  }

  void _onPageChanged(int index) {
    final nextPage = index + 1;
    _currentPageNumber = nextPage;

    if (!mounted) return;

    ref.invalidate(highlightedAyahProvider);

    ref.read(mushafPageInfoProvider(nextPage).future).then((pageInfo) {
      if (mounted) {
        ref.read(currentPageInfoProvider.notifier).state = pageInfo;
      }
    });

    if (ref.read(appBarVisibilityProvider)) {
      _startHideAppBarTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAppBarVisible = ref.watch(appBarVisibilityProvider);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double appBarHeight = kToolbarHeight;
    final double totalTopOffset = statusBarHeight + appBarHeight;

    final currentPageInfo = ref.watch(currentPageInfoProvider);

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
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint('🟢 TAP DETECTED!');
                  _toggleAppBarVisibility();
                },
                child: SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          children: [
                            if (currentPageInfo != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      currentPageInfo.surahNameArabic,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Juz ${currentPageInfo.juzNumber}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: PageView.builder(
                                controller: _pageController,
                                reverse: true,
                                itemCount: 604,
                                onPageChanged: _onPageChanged,
                                itemBuilder: (context, index) {
                                  final currentPage = index + 1;
                                  return MushafPageDisplay(
                                    pageNumber: currentPage,
                                    topOffset: totalTopOffset,
                                  );
                                },
                              ),
                            ),
                            if (currentPageInfo != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      currentPageInfo.nextPageRouteText,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      // decoration: BoxDecoration(
                                      //   color: Theme.of(context).primaryColor,
                                      //   borderRadius: BorderRadius.circular(20),
                                      // ),
                                      child: Text(
                                        '${currentPageInfo.pageNumber}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: isAppBarVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: AppBar(
                            title: const Text('Quran Assistant'),
                            centerTitle: true,
                            backgroundColor:
                                Theme.of(context).appBarTheme.backgroundColor ??
                                Theme.of(context).primaryColor,
                            foregroundColor:
                                Theme.of(context).appBarTheme.foregroundColor ??
                                Colors.white,
                            actions: [
                              Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Center(
                                  child: Text(
                                    '$_currentPageNumber / 604',
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
                ),
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
  // final bool isAppBarVisible;
  final double topOffset;

  const MushafPageDisplay({
    super.key,
    required this.pageNumber,
    // required this.isAppBarVisible,
    required this.topOffset,
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
            if (glyphs == null || glyphs.isEmpty)
              return _error('Glyph tidak ditemukan.');

            return pageInfoAsync.when(
              loading: _loading,
              error: (e, _) => _error('Gagal memuat info halaman: $e'),
              data: (pageInfo) {
                return _MushafPageContent(
                  imageBytes: imageBytes,
                  glyphs: glyphs,
                  highlighted: highlighted,
                  // isAppBarVisible: isAppBarVisible,
                  pageInfo: pageInfo,
                  topOffset: topOffset,
                  onTap: (info) {
                    final notifier = ref.read(
                      highlightedAyahProvider(pageNumber).notifier,
                    );

                    final tapped = (sura: info.sura, ayah: info.ayah);
                    final isSame = notifier.state == tapped;

                    notifier.state = isSame ? null : tapped;

                    if (!isSame) {
                      showAyahContextMenuOverlay(
                        context: context,
                        position: info.globalPosition,
                        sura: info.sura,
                        ayah: info.ayah,
                        onDismiss: () {
                          ref
                                  .read(
                                    highlightedAyahProvider(
                                      pageNumber,
                                    ).notifier,
                                  )
                                  .state =
                              null;
                        },
                      );
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Offset calculateGlyphGlobalPosition({
    required BuildContext context,
    required GlyphPosition glyph,
    required double scale,
    required double offsetX,
    required double offsetY,
  }) {
    final left = glyph.minX * scale + offsetX;
    final top = glyph.minY * scale + offsetY;

    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset(left, top));
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());

  Widget _error(String msg) => Center(child: Text(msg));
}

class AyahTapInfo {
  final int sura;
  final int ayah;
  final Offset globalPosition;

  AyahTapInfo({
    required this.sura,
    required this.ayah,
    required this.globalPosition,
  });
}

class _MushafPageContent extends ConsumerWidget {
  final Uint8List imageBytes;
  final List<GlyphPosition> glyphs;
  final ({int sura, int ayah})? highlighted;
  final MushafPageInfo pageInfo;
  final double topOffset;
  final void Function(AyahTapInfo info) onTap;

  const _MushafPageContent({
    super.key,
    required this.imageBytes,
    required this.glyphs,
    required this.highlighted,
    required this.pageInfo,
    required this.topOffset,
    required this.onTap,
  });

  static const double FILE_IMG_WIDTH = 1080.0;
  static const double FILE_IMG_HEIGHT = 1747.0;
  static const double GLYPH_SOURCE_WIDTH = 1920.0;
  static const double GLYPH_SOURCE_HEIGHT = 3106.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAppBarVisible = ref.watch(appBarVisibilityProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        final double aspectRatioFileImg = FILE_IMG_WIDTH / FILE_IMG_HEIGHT;
        final double aspectRatioScreen = screenWidth / screenHeight;

        double renderedImageWidth;
        double renderedImageHeight;
        double imageOffsetX = 0;
        double imageOffsetY = 0;

        if (aspectRatioScreen > aspectRatioFileImg) {
          renderedImageHeight = screenHeight;
          renderedImageWidth = renderedImageHeight * aspectRatioFileImg;
          imageOffsetX = (screenWidth - renderedImageWidth) / 2;
        } else {
          renderedImageWidth = screenWidth;
          renderedImageHeight = renderedImageWidth / aspectRatioFileImg;
          imageOffsetY = (screenHeight - renderedImageHeight) / 2;
        }

        final double adjustedTopOffset = 2.0;
        final double totalContentOffsetY = imageOffsetY + adjustedTopOffset;
        final double uniformScale = renderedImageWidth / GLYPH_SOURCE_WIDTH;

        final List<Widget> highlightWidgets = [];

        if (highlighted != null) {
          final matchedGlyphs = glyphs.where(
            (g) => g.sura == highlighted!.sura && g.ayah == highlighted!.ayah,
          );
          for (final glyph in matchedGlyphs) {
            final left = glyph.minX * uniformScale + imageOffsetX;
            final top = glyph.minY * uniformScale + totalContentOffsetY;
            final width = (glyph.maxX - glyph.minX) * uniformScale;
            final height = (glyph.maxY - glyph.minY) * uniformScale;

            highlightWidgets.add(
              Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
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

        // final List<Widget> contextMenuGlyphWidgets = [];

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final notifier = ref.read(appBarVisibilityProvider.notifier);
            final current = ref.read(appBarVisibilityProvider);

            if (current) {
              debugPrint("🔻 AppBar is visible, hiding it.");
              notifier.state = false;
            } else {
              debugPrint("🔺 AppBar is hidden, showing it and starting timer.");
              notifier.state = true;

              Future.microtask(() {
                Timer(const Duration(milliseconds: 1500), () {
                  if (context.mounted) {
                    final stillVisible = ref.read(appBarVisibilityProvider);
                    if (stillVisible) {
                      ref.read(appBarVisibilityProvider.notifier).state = false;
                      debugPrint("⏱️ Auto-hiding AppBar after delay.");
                    }
                  }
                });
              });
            }
          },
          onLongPressStart: (details) {
            final localPos = details.localPosition;
            final dx = localPos.dx;
            final dy = localPos.dy;
            // debugPrint("📍 Tap at: x=$dx, y=$dy");

            for (final g in glyphs) {
              final left = g.minX * uniformScale + imageOffsetX;
              final right = g.maxX * uniformScale + imageOffsetX;
              final top = g.minY * uniformScale + totalContentOffsetY;
              final bottom = g.maxY * uniformScale + totalContentOffsetY;

              if (dx >= left && dx <= right && dy >= top && dy <= bottom) {
                // debugPrint(
                //   "🌟 MATCH: ${g.sura}:${g.ayah} (line ${g.lineNumber})",
                // );
                onTap(
                  AyahTapInfo(
                    sura: g.sura,
                    ayah: g.ayah,
                    globalPosition: details.globalPosition,
                  ),
                );
                break;
              }
            }
          },
          child: Stack(
            children: [
              Image.memory(
                imageBytes,
                width: screenWidth,
                height: screenHeight,
                fit: BoxFit.contain,
              ),
              ...highlightWidgets,
              // AyahContextMenuOverlay(
              //   glyphs: glyphs,
              //   scale: uniformScale,
              //   offsetX: imageOffsetX,
              //   offsetY: totalContentOffsetY,
              //   pageNumber: pageInfo.pageNumber,
              //   onHighlight: (sura, ayah) {
              //     ref
              //         .read(
              //           highlightedAyahProvider(pageInfo.pageNumber).notifier,
              //         )
              //         .state = (
              //       sura: sura,
              //       ayah: ayah,
              //     );
              //   },
              // ),
            ],
          ),
        );
      },
    );
  }
}





// --- END BAGIAN MushafDetailPage --- 
