// lib/pages/quran_detail_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

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

  @override
  void initState() {
    super.initState();
    int calculatedInitialIndex;

    // Dengan reverse: false, index 0 = halaman 1
    // Jadi, index = (halaman - 1)
    if (widget.initialPage != null &&
        widget.initialPage! >= 1 &&
        widget.initialPage! <= 604) {
      calculatedInitialIndex = widget.initialPage! - 1;
    } else {
      calculatedInitialIndex = 0; // Default ke halaman 1
    }

    _lastPageIndex = calculatedInitialIndex;
    _controller = PageController(initialPage: calculatedInitialIndex);

    _controller.addListener(() {
      final currentPageIndex = _controller.page?.round();
      if (currentPageIndex != null && currentPageIndex != _lastPageIndex) {
        final int oldQuranPage = _lastPageIndex + 1;
        final int newQuranPage = currentPageIndex + 1;

        String swipeDirection = '';
        String pageMovement = '';

        if (currentPageIndex > _lastPageIndex) {
          // Indeks naik → user swipe ke kiri → Halaman +1
          swipeDirection = 'Geser ke Kiri (finger moved right-to-left)';
          pageMovement = 'Halaman Selanjutnya (+1)';
        } else if (currentPageIndex < _lastPageIndex) {
          // Indeks turun → user swipe ke kanan → Halaman -1
          swipeDirection = 'Geser ke Kanan (finger moved left-to-right)';
          pageMovement = 'Halaman Sebelumnya (-1)';
        }

        debugPrint('--- PAGE SWIPE DEBUG ---');
        debugPrint('Detected $swipeDirection');
        debugPrint('Internal Index: $_lastPageIndex -> $currentPageIndex');
        debugPrint(
          'Quran Page Number: Halaman $oldQuranPage -> Halaman $newQuranPage ($pageMovement)',
        );
        debugPrint('------------------------');

        _lastPageIndex = currentPageIndex;
      }
    });
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
        reverse:
            true, // sekarang false, agar finger left→right berarti halaman +1
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
  bool isLoading = true;
  String? imagePath;

  @override
  void initState() {
    super.initState();
    _loadGlyphsAndImage();
  }

  @override
  void didUpdateWidget(_SingleQuranPageDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageNumber != oldWidget.pageNumber ||
        widget.resolution != oldWidget.resolution) {
      _loadGlyphsAndImage();
    }
  }

  Future<void> _loadGlyphsAndImage() async {
    setState(() => isLoading = true);
    debugPrint('Loading page ${widget.pageNumber} (${widget.resolution})...');
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/glyphs_json/page_${widget.pageNumber.toString().padLeft(3, '0')}.json',
      );
      final parsed = await compute(_parseJson, jsonStr);

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/${widget.resolution}/page${widget.pageNumber.toString().padLeft(3, '0')}.png';

      final imageFile = File(path);
      if (await imageFile.exists()) {
        setState(() {
          glyphs = parsed;
          highlightedWords.clear();
          highlightedAyah.clear();
          imagePath = path;
          isLoading = false;
        });
        debugPrint('Page ${widget.pageNumber} loaded successfully from $path');
      } else {
        debugPrint(
          'Error: Gambar halaman ${widget.pageNumber} (${widget.resolution}) tidak ditemukan di $path',
        );
        setState(() {
          glyphs = [];
          imagePath = null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error memuat data untuk halaman ${widget.pageNumber}: $e');
      setState(() {
        glyphs = [];
        imagePath = null;
        isLoading = false;
      });
    }
  }

  static List<dynamic> _parseJson(String jsonStr) {
    return json.decode(jsonStr);
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
                  'Gambar halaman ${widget.pageNumber} tidak tersedia. Mohon unduh data Mushaf.',
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
                width: imageWidth,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    'Image.file error for page ${widget.pageNumber}: $error',
                  );
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                          size: 50,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Gagal memuat gambar halaman ${widget.pageNumber}.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

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
                  onTap: () {
                    setState(() {
                      highlightedWords.clear();
                      highlightedAyah.clear();
                      highlightedWords.add(key);
                    });
                  },
                  onLongPress: () {
                    setState(() {
                      highlightedWords.clear();
                      highlightedAyah.clear();
                      highlightedAyah.add(ayahKey);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isAyahHighlighted
                          ? Colors.green.withOpacity(0.3)
                          : isWordHighlighted
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.transparent,
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
}
