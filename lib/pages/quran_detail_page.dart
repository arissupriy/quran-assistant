import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class QuranPerPage extends StatelessWidget {
  final String resolution;
  const QuranPerPage({super.key, required this.resolution});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Per Page',
      theme: ThemeData(fontFamily: 'Roboto'),
      home: QuranPageViewer(resolution: resolution),
    );
  }
}

class QuranPageViewer extends StatefulWidget {
  final String resolution;
  const QuranPageViewer({super.key, required this.resolution});

  @override
  State<QuranPageViewer> createState() => _QuranPageViewerState();
}

class _QuranPageViewerState extends State<QuranPageViewer> {
  final PageController _controller = PageController(initialPage: 603);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran Per Page'), centerTitle: true),
      body: PageView.builder(
        controller: _controller,
        reverse: true,
        itemCount: 604,
        itemBuilder: (context, index) {
          final pageNumber = 604 - index;
          return QuranPage(
            pageNumber: pageNumber,
            resolution: widget.resolution,
          );
        },
      ),
    );
  }
}

class QuranPage extends StatefulWidget {
  final int pageNumber;
  final String resolution;

  const QuranPage({super.key, required this.pageNumber, required this.resolution});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
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

  Future<void> _loadGlyphsAndImage() async {
    setState(() => isLoading = true);
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/glyphs_json/page_${widget.pageNumber.toString().padLeft(3, '0')}.json',
      );
      final parsed = await compute(_parseJson, jsonStr);
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${widget.resolution}/page${widget.pageNumber.toString().padLeft(3, '0')}.png';

      setState(() {
        glyphs = parsed;
        highlightedWords.clear();
        highlightedAyah.clear();
        imagePath = path;
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        glyphs = [];
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

        if (isLoading || imagePath == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            // Layer gesture kosong
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
              ),
            ),

            // Overlay glyphs
            ...glyphs.map((glyph) {
              final double left = glyph['min_x'] * scale;
              final double top = glyph['min_y'] * scale;
              final double width = (glyph['max_x'] - glyph['min_x']) * scale;
              final double height = (glyph['max_y'] - glyph['min_y']) * scale;
              final key = "${glyph['sura']}:${glyph['ayah']}:${glyph['word_position']}";
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
