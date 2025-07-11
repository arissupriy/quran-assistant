import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/utils/glyph_cache_utils.dart';

class QuranPerPage extends StatelessWidget {
  final String resolution;
  final int? initialPage;

  const QuranPerPage({super.key, required this.resolution, this.initialPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Per Page',
      theme: ThemeData(fontFamily: 'Roboto'),
      home: QuranPageViewer(resolution: resolution, initialPage: initialPage),
    );
  }
}

class QuranPageViewer extends StatefulWidget {
  final String resolution;
  final int? initialPage;

  const QuranPageViewer({
    super.key,
    required this.resolution,
    this.initialPage,
  });

  @override
  State<QuranPageViewer> createState() => _QuranPageViewerState();
}

class _QuranPageViewerState extends State<QuranPageViewer> {
  late final PageController _controller;
  int _lastPageIndex = 0;
  final Map<int, Future<void>> _preloadTasks = {};

  @override
  void initState() {
    super.initState();
    int calculatedInitialIndex =
        (widget.initialPage != null &&
            widget.initialPage! >= 1 &&
            widget.initialPage! <= 604)
        ? widget.initialPage! - 1
        : 0;

    _lastPageIndex = calculatedInitialIndex;
    _controller = PageController(initialPage: calculatedInitialIndex);

    _preloadSurroundingPages(_lastPageIndex);

    _controller.addListener(() {
      final currentPageIndex = _controller.page?.round();
      if (currentPageIndex != null && currentPageIndex != _lastPageIndex) {
        final oldPage = _lastPageIndex + 1;
        final newPage = currentPageIndex + 1;

        debugPrint('--- PAGE SWIPE DEBUG ---');
        debugPrint('Quran Page: $oldPage → $newPage');
        debugPrint('------------------------');

        _preloadSurroundingPages(currentPageIndex);
        _lastPageIndex = currentPageIndex;
      }
    });
  }

  void _preloadSurroundingPages(int index) async {
    final dir = await getApplicationDocumentsDirectory();

    for (int i = index - 5; i <= index + 5; i++) {
      if (i < 0 || i >= 604 || _preloadTasks.containsKey(i)) continue;

      final pageStr = (i + 1).toString().padLeft(3, '0');
      final imagePath = '${dir.path}/${widget.resolution}/page$pageStr.png';

      _preloadTasks[i] = File(imagePath)
          .exists()
          .then((exists) {
            if (!exists) {
              debugPrint('[Preload] Gambar page $pageStr tidak ditemukan');
            }
          })
          .whenComplete(() {
            _preloadTasks.remove(i);
          });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran Per Page'), centerTitle: true),
      body: PageView.builder(
        key: const PageStorageKey<String>('QuranPageView'),
        controller: _controller,
        reverse: true,
        itemCount: 604,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          return _SingleQuranPageDisplay(
            key: ValueKey(pageNumber),
            pageNumber: pageNumber,
            resolution: widget.resolution,
          );
        },
      ),
    );
  }
}

class _SingleQuranPageDisplay extends StatefulWidget {
  final int pageNumber;
  final String resolution;

  const _SingleQuranPageDisplay({
    super.key,
    required this.pageNumber,
    required this.resolution,
  });

  @override
  State<_SingleQuranPageDisplay> createState() =>
      _SingleQuranPageDisplayState();
}

class _SingleQuranPageDisplayState extends State<_SingleQuranPageDisplay> {
  List<dynamic> glyphs = [];
  Set<String> highlightedWords = {};
  Set<String> highlightedAyah = {};
  bool isLoading = false;
  String? imagePath;
  TapDownDetails? _tapDetails;
  bool _longPressTriggered = false;

  @override
  void initState() {
    super.initState();
    _loadImageAndUseCachedGlyph();
  }

  @override
  void didUpdateWidget(covariant _SingleQuranPageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber ||
        widget.resolution != oldWidget.resolution) {
      _loadImageAndUseCachedGlyph();
    }
  }

  Future<void> _loadImageAndUseCachedGlyph() async {
    final pageStr = widget.pageNumber.toString().padLeft(3, '0');
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/${widget.resolution}/page$pageStr.png';
    final imageFile = File(path);

    if (!await imageFile.exists()) {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        imagePath = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      imagePath = path;
      isLoading = false;
      glyphs = GlyphCache().getGlyph(widget.pageNumber);
      highlightedWords.clear();
      highlightedAyah.clear();
    });
  }

  void showGlyphPopupMenu({
    required BuildContext context,
    required Offset globalPosition,
    required bool isWord, // 🆕
    VoidCallback? onDismiss,
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final screenSize = renderBox?.size ?? MediaQuery.of(context).size;

        const popupWidth = 200.0;
        const popupHeight = 120.0;
        const margin = 12.0;

        double left = globalPosition.dx;
        double top = globalPosition.dy;

        if (left + popupWidth + margin > screenSize.width) {
          left = screenSize.width - popupWidth - margin;
        }
        if (top + popupHeight + margin > screenSize.height) {
          top = screenSize.height - popupHeight - margin;
        }

        return GestureDetector(
          onTap: () {
            overlayEntry.remove();
            onDismiss?.call();
          },
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.transparent)),
              Positioned(
                left: left,
                top: top,
                width: popupWidth,
                height: popupHeight,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              isWord ? 'Kata Quran' : 'Ayat Quran',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            TextButton.icon(
                              icon: Icon(
                                isWord
                                    ? Icons.info_outline
                                    : Icons.menu_book_rounded,
                                color: Colors.white,
                              ),
                              label: Text(
                                isWord
                                    ? 'Lihat Detail Kata'
                                    : 'Lihat Detail Ayat',
                                style: const TextStyle(color: Colors.white),
                              ),
                              onPressed: () {
                                overlayEntry.remove(); // Tutup popup

                                Future.delayed(Duration.zero, () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    builder: (_) => Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 160,
                                      ), // ✅ Min height
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Center(
                                            child: Container(
                                              width: 40,
                                              height: 4,
                                              margin: const EdgeInsets.only(
                                                bottom: 16,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            isWord
                                                ? 'Detail Kata'
                                                : 'Detail Ayat',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            isWord
                                                ? 'Detail kata Quran akan ditampilkan di sini.'
                                                : 'Detail ayat Quran akan ditampilkan di sini.',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ).whenComplete(() {
                                    onDismiss?.call();
                                  });
                                });
                                // Tampilkan Bottomm
                                // TODO: Aksi klik
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth;
        final scale = imageWidth / 1920.0;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (imagePath == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                Text(
                  'Gambar halaman ${widget.pageNumber} tidak tersedia.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  highlightedWords.clear();
                  highlightedAyah.clear();
                });
              },
              child: Image.file(
                File(imagePath!),
                gaplessPlayback: true,
                width: imageWidth,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    'Image error for page ${widget.pageNumber}: $error',
                  );
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image_rounded, size: 50),
                        const SizedBox(height: 10),
                        Text(
                          'Gagal memuat gambar halaman ${widget.pageNumber}.',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (highlightedAyah.isNotEmpty) ..._buildAyahOverlay(scale),
            ...glyphs.map((glyph) {
              final double left = glyph['min_x'] * scale;
              final double top = glyph['min_y'] * scale;
              final double width = (glyph['max_x'] - glyph['min_x']) * scale;
              final double height = (glyph['max_y'] - glyph['min_y']) * scale;
              final key =
                  "${glyph['sura']}:${glyph['ayah']}:${glyph['word_position']}";
              final ayahKey = "${glyph['sura']}:${glyph['ayah']}";
              final isWordHighlighted = highlightedWords.contains(key);
              final isAyahHighlighted = highlightedAyah.contains(ayahKey);

              return Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: GestureDetector(
                  onTapDown: (details) {
                    _tapDetails = details;
                  },
                  onTapUp: (_) {
                    if (_tapDetails == null) return;

                    if (_longPressTriggered) {
                      // Sudah long-press, abaikan tap
                      _longPressTriggered = false;
                      return;
                    }

                    if (highlightedWords.isNotEmpty ||
                        highlightedAyah.isNotEmpty) {
                      setState(() {
                        highlightedWords.clear();
                        highlightedAyah.clear();
                      });
                      return;
                    }

                    final tapOffset = _tapDetails!.globalPosition;

                    setState(() {
                      highlightedWords.add(key);
                    });

                    showGlyphPopupMenu(
                      context: context,
                      globalPosition: tapOffset,
                      isWord: true,

                      onDismiss: () {
                        setState(() {
                          highlightedWords.clear();
                          highlightedAyah.clear();
                        });
                      },
                    );
                  },
                  onLongPressStart: (details) {
                    _longPressTriggered = true;

                    if (highlightedWords.isNotEmpty ||
                        highlightedAyah.isNotEmpty) {
                      setState(() {
                        highlightedWords.clear();
                        highlightedAyah.clear();
                      });
                      return;
                    }

                    final pressOffset = details.globalPosition;

                    setState(() {
                      highlightedAyah.add(ayahKey);
                    });

                    Future.microtask(() {
                      showGlyphPopupMenu(
                        context: context,
                        globalPosition: pressOffset,
                        isWord: false,

                        onDismiss: () {
                          setState(() {
                            highlightedWords.clear();
                            highlightedAyah.clear();
                          });
                        },
                      );
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isWordHighlighted
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.transparent, // ⛔ Hapus warna untuk ayat
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  List<Widget> _buildAyahOverlay(double scale) {
    if (highlightedAyah.isEmpty) return [];

    final ayahKey = highlightedAyah.first;
    final ayahGlyphs = glyphs
        .where((g) => "${g['sura']}:${g['ayah']}" == ayahKey)
        .map(
          (g) => {
            'min_x': (g['min_x'] as num).toDouble(),
            'max_x': (g['max_x'] as num).toDouble(),
            'min_y': (g['min_y'] as num).toDouble(),
            'max_y': (g['max_y'] as num).toDouble(),
          },
        )
        .toList();

    // Kelompokkan glyph berdasarkan posisi Y (anggap dalam 30px satu baris)
    const double lineThreshold = 30.0;

    List<List<Map<String, double>>> lines = [];

    for (var glyph in ayahGlyphs) {
      bool added = false;
      for (var line in lines) {
        final avgY =
            line.map((g) => g['min_y']!).reduce((a, b) => a + b) / line.length;
        if ((glyph['min_y']! - avgY).abs() < lineThreshold) {
          line.add(glyph);
          added = true;
          break;
        }
      }
      if (!added) {
        lines.add([glyph]);
      }
    }

    // Buat highlight overlay per baris
    return lines.map((lineGlyphs) {
      final minX = lineGlyphs
          .map((g) => g['min_x']!)
          .reduce((a, b) => a < b ? a : b);
      final maxX = lineGlyphs
          .map((g) => g['max_x']!)
          .reduce((a, b) => a > b ? a : b);
      final minY = lineGlyphs
          .map((g) => g['min_y']!)
          .reduce((a, b) => a < b ? a : b);
      final maxY = lineGlyphs
          .map((g) => g['max_y']!)
          .reduce((a, b) => a > b ? a : b);

      return Positioned(
        left: minX * scale,
        top: minY * scale,
        width: (maxX - minX) * scale,
        height: (maxY - minY) * scale,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.25),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    }).toList();
  }
}
