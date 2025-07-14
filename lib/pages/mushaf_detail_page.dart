import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf_download_page.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
import 'package:quran_assistant/src/rust/api/quran/verse.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';
import 'package:quran_assistant/src/rust/models.dart';
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:quran_assistant/widgets/verse_detail_bottom_sheet.dart';
import 'package:super_context_menu/super_context_menu.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.pageNumber - 1);
    _mushafPathFuture = getMushafFilePathIfExists();
  }

  @override
  Widget build(BuildContext context) {
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
              appBar: AppBar(
                title: const Text('Mushaf Madani'),
                centerTitle: true,
              ),
              body: PageView.builder(
                controller: _pageController,
                reverse: true,
                itemCount: 604,
                itemBuilder: (context, index) {
                  final currentPage = index + 1;
                  return MushafPageDisplay(pageNumber: currentPage);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToDownloadPageIfNeeded() {
    if (_navigated) return;
    _navigated = true;

    Future.microtask(() {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MushafDownloadPage(initialPage: widget.pageNumber),
        ),
      );
    });
  }

  Widget _buildLoading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _buildError(String message) =>
      Scaffold(body: Center(child: Text(message)));
}

class MushafPageDisplay extends ConsumerWidget {
  final int pageNumber;

  const MushafPageDisplay({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(mushafImageProvider(pageNumber));
    final glyphAsync = ref.watch(mushafGlyphProvider(pageNumber));
    final highlighted = ref.watch(highlightedAyahProvider(pageNumber));

    return imageAsync.when(
      loading: _loading,
      error: (e, _) => _error('Gagal memuat gambar: $e'),
      data: (imageBytes) {
        if (imageBytes == null) return _error('Gambar tidak ditemukan.');

        return glyphAsync.when(
          loading: _loading,
          error: (e, _) => _error('Gagal memuat glyph: $e'),
          data: (glyphs) {
            if (glyphs!.isEmpty) return _error('Glyph tidak ditemukan.');

            return _MushafPageContent(
              imageBytes: imageBytes,
              glyphs: glyphs,
              highlighted: highlighted,
              onTap: (sura, ayah) {
                final notifier = ref.read(
                  highlightedAyahProvider(pageNumber).notifier,
                );
                final tapped = (sura: sura, ayah: ayah);
                notifier.state = notifier.state == tapped ? null : tapped;
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

// ... (Your existing imports and class definitions)

class _MushafPageContent extends StatelessWidget {
  final Uint8List imageBytes;
  final List<GlyphPosition> glyphs;
  final ({int sura, int ayah})? highlighted;
  final void Function(int sura, int ayah) onTap;

  const _MushafPageContent({
    required this.imageBytes,
    required this.glyphs,
    required this.highlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // final rustEngineService = RustEngineService();

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 1920.0;

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
            final minX =
                lineGlyphs.map((g) => g.minX).reduce((a, b) => a < b ? a : b) *
                scale;
            final maxX =
                lineGlyphs.map((g) => g.maxX).reduce((a, b) => a > b ? a : b) *
                scale;
            final minY =
                lineGlyphs.map((g) => g.minY).reduce((a, b) => a < b ? a : b) *
                scale;
            final maxY =
                lineGlyphs.map((g) => g.maxY).reduce((a, b) => a > b ? a : b) *
                scale;

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
            Image.memory(
              imageBytes,
              width: constraints.maxWidth,
              fit: BoxFit.contain,
            ),
            ...highlightLayers,
            ...ayahMap.entries.map((entry) {
              final ayahKey = entry.key;
              final glyphsInAyah = entry.value;

              final minX =
                  glyphsInAyah
                      .map((g) => g.minX)
                      .reduce((a, b) => a < b ? a : b) *
                  scale;
              final maxX =
                  glyphsInAyah
                      .map((g) => g.maxX)
                      .reduce((a, b) => a > b ? a : b) *
                  scale;
              final minY =
                  glyphsInAyah
                      .map((g) => g.minY)
                      .reduce((a, b) => a < b ? a : b) *
                  scale;
              final maxY =
                  glyphsInAyah
                      .map((g) => g.maxY)
                      .reduce((a, b) => a > b ? a : b) *
                  scale;

              return Positioned(
                left: minX,
                top: minY,
                width: maxX - minX,
                height: maxY - minY,
                child: GestureDetector(
                  onTap: () => onTap(ayahKey.sura, ayahKey.ayah),
                  behavior: HitTestBehavior.translucent,
                  child: ContextMenuWidget(
                    menuProvider: (_) {
                      return Menu(
                        children: [
                          MenuAction(
                            title: '📖 Lihat Detail Ayah Ini',
                            image: MenuImage.icon(Icons.visibility),
                            callback: () {
                              onTap(ayahKey.sura, ayahKey.ayah);
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => VerseDetailBottomSheet(
                                  verseKey: "${ayahKey.sura}:${ayahKey.ayah}",
                                ),
                              );
                            },
                          ),
                          MenuAction(
                            title: '📋 Salin Ayah Ini',
                            image: MenuImage.icon(Icons.copy),
                            callback: () async {
                              // This already uses await correctly
                              // final verseText = await rustEngineService.getVerseTextUthmani(
                              //   "${ayahKey.sura}:${ayahKey.ayah}",
                              // );

                              final Verse? verse =
                                  await getVerseByChapterAndVerseNumber(
                                    chapterNumber: ayahKey.sura,
                                    verseNumber: ayahKey.ayah,
                                  );
                              if (verse != null &&
                                  verse.words.isNotEmpty) {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: verse.words
                                        .map((word) => word.textUthmani)
                                        .join(' '),
                                  ),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Ayat tersalin: ${verse.words.map((word) => word.textUthmani).join(' ')}",
                                      ),
                                    ),
                                  );
                                }
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Gagal menyalin ayat atau teks kosong.",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      );
                    },
                    child: Container(
                      color:
                          Colors.transparent, // Interactive area is transparent
                    ),
                    deferredPreviewBuilder: (context, child, cancellationToken) {
  final verseFuture = getVerseByChapterAndVerseNumber(
    chapterNumber: ayahKey.sura,
    verseNumber: ayahKey.ayah,
  );

  return DeferredMenuPreview(
    const Size(300, 100),
    verseFuture.then((verse) {
      if (verse == null || verse.words.isEmpty) {
        return const Text(
          'Gagal memuat teks',
          style: TextStyle(color: Colors.red),
        );
      }

      final displayText = verse.words.map((w) => w.textUthmani).join(' ');

      return Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            displayText,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontFamily: 'UthmaniHafs',
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }),
  );
},

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
