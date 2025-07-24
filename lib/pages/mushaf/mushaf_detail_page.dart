// lib/pages/mushaf/widgets/mushaf_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/pages/mushaf/utils/session_manager.dart';
import 'package:quran_assistant/pages/mushaf/widgets/animated_appbar.dart';
import 'package:quran_assistant/pages/mushaf/widgets/footer_info.dart';
import 'package:quran_assistant/pages/mushaf/widgets/header_info.dart';
import 'package:quran_assistant/pages/mushaf/widgets/mushaf_page_display.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
// import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';
import 'package:quran_assistant/utils/quran_utils.dart';

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
  late final SessionManager _sessionManager;

  Timer? _hideAppBarTimer;
  int _currentPageNumber = 0;
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
    _sessionManager = SessionManager();
    _currentPageNumber = widget.pageNumber;
    _pageController = PageController(initialPage: widget.pageNumber - 1);
    _mushafPathFuture = getMushafFilePathIfExists();
    _previousPageNumber = 0;

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
      ref.read(mushafPageInfoProvider(_currentPageNumber).future).then((pageInfo) {
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
    _sessionManager.dispose();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _sessionManager.forceEndSession(ref);
    // });

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

    _currentPageNumber = nextPage;

    if (!mounted) return;

    _sessionManager.handlePageChange(
      ref: ref,
      newPage: nextPage,
      previousPage: prevPage,
    );

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
                              if (currentPageInfo != null)
                                HeaderInfo(pageInfo: currentPageInfo),

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

                              if (currentPageInfo != null)
                                FooterInfo(pageInfo: currentPageInfo),
                            ],
                          ),
                        ),

                        AnimatedMushafAppBar(
                          currentPageNumber: _currentPageNumber,
                          sessionManager: _sessionManager,
                        ),
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
        body: const Center(
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
