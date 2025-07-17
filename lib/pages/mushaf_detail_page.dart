import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';
import 'package:quran_assistant/src/rust/models.dart';
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:quran_assistant/widgets/ayah_context_menu.dart';

// Optimized Session Manager
class _SessionManager {
  static const Duration _sessionDebounceDelay = Duration(milliseconds: 700);
  static const Duration _sessionTransitionDelay = Duration(milliseconds: 100);
  
  Timer? _sessionDebounceTimer;
  Timer? _sessionTransitionTimer;
  Completer<void>? _activeSessionTransition;
  int? _currentSessionPage;
  bool _isTransitioning = false;

  Future<void> handlePageChange({
    required WidgetRef ref,
    required int newPage,
    required int? previousPage,
  }) async {
    // Cancel any pending session operations
    _sessionDebounceTimer?.cancel();
    _sessionTransitionTimer?.cancel();

    // Wait for any active transition to complete
    if (_activeSessionTransition != null && !_activeSessionTransition!.isCompleted) {
      await _activeSessionTransition!.future;
    }

    // Debounce rapid page changes
    _sessionDebounceTimer = Timer(_sessionDebounceDelay, () {
      _executeSessionTransition(ref, newPage, previousPage);
    });
  }

  Future<void> _executeSessionTransition(
    WidgetRef ref,
    int newPage,
    int? previousPage,
  ) async {
    if (_isTransitioning) return;

    _isTransitioning = true;
    _activeSessionTransition = Completer<void>();

    try {
      // End current session if exists
      if (_currentSessionPage != null) {
        await _endSession(ref);
      }

      // Small delay to ensure clean transition
      await Future.delayed(_sessionTransitionDelay);

      // Start new session
      await _startSession(ref, newPage, previousPage);
      _currentSessionPage = newPage;

      debugPrint('📖 Session transition completed: $previousPage → $newPage');
    } catch (e) {
      debugPrint('❌ Session transition error: $e');
    } finally {
      _isTransitioning = false;
      _activeSessionTransition?.complete();
      _activeSessionTransition = null;
    }
  }

  Future<void> _startSession(WidgetRef ref, int page, int? previousPage) async {
    try {
      await ref
          .read(readingSessionRecorderProvider.notifier)
          .startSession(page: page, previousPage: previousPage);
    } catch (e) {
      debugPrint('❌ Failed to start session: $e');
    }
  }

  Future<void> _endSession(WidgetRef ref) async {
    try {
      await ref.read(readingSessionRecorderProvider.notifier).endSession();
    } catch (e) {
      debugPrint('❌ Failed to end session: $e');
    }
  }

  Future<void> forceEndSession(WidgetRef ref) async {
    _sessionDebounceTimer?.cancel();
    _sessionTransitionTimer?.cancel();
    
    if (_currentSessionPage != null) {
      await _endSession(ref);
      _currentSessionPage = null;
    }
  }

  void dispose() {
    _sessionDebounceTimer?.cancel();
    _sessionTransitionTimer?.cancel();
  }
}

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
  late final _SessionManager _sessionManager;

  Timer? _hideAppBarTimer;
  int _currentPageNumber = 0;

  // Optimized session tracking
  bool _isInitialPageInfoLoaded = false;
  int? _previousPageNumber;

  @override
  void deactivate() {
    _sessionManager.forceEndSession(ref);
    super.deactivate();
  }

  @override
  void initState() {
    super.initState();

    _sessionManager = _SessionManager();
    _currentPageNumber = widget.pageNumber;
    _pageController = PageController(initialPage: widget.pageNumber - 1);
    _mushafPathFuture = getMushafFilePathIfExists();
    _previousPageNumber = 0;

    // Start initial session with optimized manager
    _sessionManager.handlePageChange(
      ref: ref,
      newPage: widget.pageNumber,
      previousPage: _previousPageNumber,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(appBarVisibilityProvider.notifier).state = true;
      }
    });
    _startHideAppBarTimer();
  }

  void _loadInitialPageInfo() {
    if (!_isInitialPageInfoLoaded) {
      ref.read(mushafPageInfoProvider(_currentPageNumber).future).then((
        pageInfo,
      ) {
        if (mounted) {
          ref.read(currentPageInfoProvider.notifier).state = pageInfo;
          _isInitialPageInfoLoaded = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideAppBarTimer?.cancel();
    
    // Properly dispose session manager
    _sessionManager.dispose();

    // Force end session on dispose
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sessionManager.forceEndSession(ref);
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

    ref.read(appBarVisibilityProvider.notifier).state = newValue;

    if (newValue) {
      _startHideAppBarTimer();
    } else {
      _hideAppBarTimer?.cancel();
    }
  }

  void _onPageChanged(int index) {
    final nextPage = index + 1;
    final prevPage = _currentPageNumber;

    // Update current page immediately
    _currentPageNumber = nextPage;

    if (!mounted) return;

    // Optimized session handling
    _sessionManager.handlePageChange(
      ref: ref,
      newPage: nextPage,
      previousPage: prevPage,
    );

    // Clear highlights
    ref.invalidate(highlightedAyahProvider);

    // Update page info
    ref.read(mushafPageInfoProvider(nextPage).future).then((pageInfo) {
      if (mounted) {
        ref.read(currentPageInfoProvider.notifier).state = pageInfo;
      }
    });

    // Handle app bar timer
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

            _loadInitialPageInfo();

            return RepaintBoundary(
              child: Scaffold(
                backgroundColor: AppTheme.backgroundColor,
                body: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleAppBarVisibility,
                  child: SafeArea(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Column(
                            children: [
                              // Header info
                              if (currentPageInfo != null)
                                _buildHeaderInfo(currentPageInfo),
                              
                              // Main PageView
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  reverse: true,
                                  itemCount: 604,
                                  onPageChanged: _onPageChanged,
                                  itemBuilder: (context, index) {
                                    final currentPage = index + 1;
                                    return RepaintBoundary(
                                      child: MushafPageDisplay(
                                        pageNumber: currentPage,
                                        topOffset: totalTopOffset,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Footer info
                              if (currentPageInfo != null)
                                _buildFooterInfo(currentPageInfo),
                            ],
                          ),
                        ),
                        
                        // Animated AppBar
                        _buildAnimatedAppBar(isAppBarVisible),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderInfo(MushafPageInfo pageInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pageInfo.surahNameArabic,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          Text(
            'Juz ${pageInfo.juzNumber}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterInfo(MushafPageInfo pageInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pageInfo.nextPageRouteText,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textColor,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pageInfo.pageNumber}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAppBar(bool isVisible) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: AppBar(
          title: Text(
            'Quran Assistant',
            style: TextStyle(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.iconColor),
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: AppTheme.iconColor),
                  onPressed: () async {
                    await _sessionManager.forceEndSession(ref);
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                )
              : null,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '$_currentPageNumber / 604',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildLoading() => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: Center(
      child: CircularProgressIndicator(color: AppTheme.primaryColor),
    ),
  );

  Widget _buildError(String message) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    body: Center(
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}

// Keep existing classes unchanged for now
class MushafPageDisplay extends ConsumerWidget {
  final int pageNumber;
  final double topOffset;

  const MushafPageDisplay({
    super.key,
    required this.pageNumber,
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
            if (glyphs == null || glyphs.isEmpty) {
              return _error('Glyph tidak ditemukan.');
            }

            return pageInfoAsync.when(
              loading: _loading,
              error: (e, _) => _error('Gagal memuat info halaman: $e'),
              data: (pageInfo) {
                if (pageInfo == null) {
                  return _error('Info halaman tidak ditemukan.');
                }

                return _MushafPageContent(
                  imageBytes: imageBytes,
                  glyphs: glyphs,
                  highlighted: highlighted,
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
                              .read(highlightedAyahProvider(pageNumber).notifier)
                              .state = null;
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

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final notifier = ref.read(appBarVisibilityProvider.notifier);
            final current = ref.read(appBarVisibilityProvider);
            notifier.state = !current;
          },
          onLongPressStart: (details) {
            final localPos = details.localPosition;
            final dx = localPos.dx;
            final dy = localPos.dy;

            for (final g in glyphs) {
              final left = g.minX * uniformScale + imageOffsetX;
              final right = g.maxX * uniformScale + imageOffsetX;
              final top = g.minY * uniformScale + totalContentOffsetY;
              final bottom = g.maxY * uniformScale + totalContentOffsetY;

              if (dx >= left && dx <= right && dy >= top && dy <= bottom) {
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
          child: RepaintBoundary(
            child: Stack(
              children: [
                Image.memory(
                  imageBytes,
                  width: screenWidth,
                  height: screenHeight,
                  fit: BoxFit.contain,
                ),
                ...highlightWidgets,
              ],
            ),
          ),
        );
      },
    );
  }
}