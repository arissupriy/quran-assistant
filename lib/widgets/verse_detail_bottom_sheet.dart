import 'package:flutter/material.dart';
import 'package:quran_assistant/src/rust/api/quran/similarity.dart';
// import 'package:quran_assistant/core/models/chapter_model.dart';
// import 'package:quran_assistant/core/models/search_model.dart';
import 'package:quran_assistant/src/rust/api/quran/verse.dart';
import 'package:quran_assistant/src/rust/data_loader/valid_matching_ayah.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';

class VerseDetailBottomSheet extends StatelessWidget {
  final String verseKey;

  const VerseDetailBottomSheet({super.key, required this.verseKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadVerseDetails(),
      builder: (context, AsyncSnapshot<_VerseDetailData> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Text("Gagal memuat ayat."),
          );
        }

        final data = snapshot.data!;

        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.3,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.verse.verseKey,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      data.verse.words.map((w) => w.textUthmani).join(' '),
                      style: const TextStyle(fontSize: 26, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...data.verse.translations.map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          t.text,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )),
                  const Divider(height: 32),
                  const Text(
                    'Similar Ayahs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (data.similarAyahs.isEmpty)
                    const Text("Tidak ada ayat serupa ditemukan.")
                  else
                    ...data.similarAyahs.map((item) {
                      return ListTile(
                        title: Text(
                          item.matchedAyahKey,
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => VerseDetailBottomSheet(
                              verseKey: item.matchedAyahKey,
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<_VerseDetailData> _loadVerseDetails() async {
    final parts = verseKey.split(':');
    final chapter = int.tryParse(parts[0]) ?? 0;
    final verseNum = int.tryParse(parts[1]) ?? 0;

    final verse = await getVerseByChapterAndVerseNumber(
      chapterNumber: chapter,
      verseNumber: verseNum,
    );

    final similar = await getSimilarAyahsInverted(verseKey: verseKey);

    return _VerseDetailData(verse: verse!, similarAyahs: similar);
  }
}

class _VerseDetailData {
  final Verse verse;
  final List<MatchedAyah> similarAyahs;

  _VerseDetailData({
    required this.verse,
    required this.similarAyahs,
  });
}
