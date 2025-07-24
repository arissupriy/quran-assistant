import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/providers/verse_provider.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';
import 'package:quran_assistant/src/rust/models.dart';

class MushafDetailAyahPage extends ConsumerStatefulWidget {
  final String verseKey;

  const MushafDetailAyahPage({super.key, required this.verseKey});

  @override
  ConsumerState<MushafDetailAyahPage> createState() =>
      _MushafDetailAyahPageState();
}

class _MushafDetailAyahPageState extends ConsumerState<MushafDetailAyahPage> {
  bool showTajweed = true;

  @override
  Widget build(BuildContext context) {
    final verseDetailAsync = ref.watch(verseDetailProvider(widget.verseKey));

    return Scaffold(
      appBar: AppBar(title: const Text("Detail Ayat")),
      body: verseDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat ayat: $e')),
        data: (detail) {
          final verse = detail!.verse;
          final words = detail.words;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetaInfo(verse, words),
                const SizedBox(height: 20),
                _buildTajweedSwitch(context),
                const SizedBox(height: 28),
                _buildAyahText(context, words),
                const SizedBox(height: 32),
                _buildTranslationSection(context, verse),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetaInfo(Verse verse, List<Word> words) {
    return Text(
      'Surah ke-${words.first.chapterId} • '
      'Juz ${verse.juzNumber} • Halaman ${verse.pageNumber}',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
    );
  }

  Widget _buildTajweedSwitch(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.color_lens, color: AppTheme.secondaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          "Tampilkan Tajweed",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Switch(
          value: showTajweed,
          activeColor: AppTheme.primaryColor,
          onChanged: (val) => setState(() => showTajweed = val),
        ),
      ],
    );
  }

  Widget _buildAyahText(BuildContext context, List<Word> words) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          fontFamily: 'UthmaniHafs',
          color: AppTheme.textColor,
        ),
        children: words.expand<InlineSpan>((word) {
          final spans = <InlineSpan>[];

          if (showTajweed && word.textTajweed.isNotEmpty) {
            final rules = word.textTajweed.map((t) => t.rule).toSet().toList();

            spans.add(
              TextSpan(
                children: word.textTajweed.map((seg) {
                  final isTajweed = seg.rule != "normal";
                  return TextSpan(
                    text: seg.text,
                    style: TextStyle(
                      color: isTajweed
                          ? AppTheme.primaryColor
                          : AppTheme.textColor,
                    ),
                    recognizer: isTajweed
                        ? (TapGestureRecognizer()
                            ..onTap = () =>
                                _showTajweedDialog(context, word, rules))
                        : null,
                  );
                }).toList(),
              ),
            );
          } else {
            spans.add(TextSpan(text: word.textUthmani));
          }

          // Spasi antar kata
          spans.add(const TextSpan(text: ' '));
          return spans;
        }).toList(),
      ),
    );
  }

  Widget _buildTranslationSection(BuildContext context, Verse verse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Terjemahan",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...verse.translations.map(
          (t) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.subtleShadowColor,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              t.text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: AppTheme.textColor,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
        ),
      ],
    );
  }

  void _showTajweedDialog(BuildContext context, Word word, List<String> rules) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tajweed Ayat',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tampilkan teks arab
            Center(
              child: Text(
                word.textUthmani,
                style: const TextStyle(fontSize: 30, fontFamily: 'UthmaniHafs'),
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Aturan Tajweed yang ditemukan:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),

            // Tampilkan daftar aturan (kecuali "normal")
            ...word.textTajweed
                .where((seg) => seg.rule != 'normal')
                .map(
                  (seg) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: seg.text,
                                style: const TextStyle(
                                  fontFamily: 'UthmaniHafs',
                                  fontSize: 18,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: '  '),
                              TextSpan(
                                text: seg.rule,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textColor,
                                ),
                              ),
                            ],
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Tutup',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
