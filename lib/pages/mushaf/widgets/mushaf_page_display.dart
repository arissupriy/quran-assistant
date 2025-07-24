// lib/pages/mushaf/widgets/mushaf_page_display.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/mushaf/utils/session_manager.dart';
import 'package:quran_assistant/pages/mushaf/widgets/show_ayah_menu.dart';
import 'package:quran_assistant/pages/mushaf_detail_page.dart';
import 'package:quran_assistant/providers/mushaf_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/mushaf_page_info.dart';
import 'package:quran_assistant/src/rust/models.dart';
import 'package:quran_assistant/widgets/ayah_context_menu.dart';

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
                      showAyahMenu(
                        context: context,
                        sura: info.sura,
                        ayah: info.ayah,
                      ).then((_) {
                        // Clear highlighted ayah after menu is dismissed
                        ref.read(highlightedAyahProvider(pageNumber).notifier).state = null;
                      });
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

class _MushafPageContent extends ConsumerWidget {
  final Uint8List imageBytes;
  final List<GlyphPosition> glyphs;
  final ({int sura, int ayah})? highlighted;
  final MushafPageInfo pageInfo;
  final double topOffset;
  final void Function(AyahTapInfo info) onTap;

  const _MushafPageContent({
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
            (g) => g.sura == highlighted?.sura && g.ayah == highlighted?.ayah,
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
