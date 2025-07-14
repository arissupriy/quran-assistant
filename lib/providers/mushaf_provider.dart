import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/api/mushaf.dart';
import 'package:quran_assistant/src/rust/api/quran/verse.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';
import 'package:quran_assistant/src/rust/models.dart'; // ⬅️ langsung dari hasil FRB

/// Provider untuk membuka mushaf.pack
final mushafLoadProvider = FutureProvider.family<bool, String>((ref, path) async {
  return await openMushafPack(path: path);
});

/// Gambar PNG dari halaman ke-n
final mushafImageProvider = FutureProvider.family<Uint8List?, int>((ref, page) async {
  return await getPageImage(page: page);
});

/// Metadata glyph untuk halaman
final mushafGlyphProvider = FutureProvider.family<List<GlyphPosition>?, int>((ref, page) async {
  return await getPageMetadata(page: page);
});

final highlightedAyahProvider = StateProvider.family<({int sura, int ayah})?, int>(
  (ref, pageNumber) => null,
);

final verseProvider = FutureProvider.family
    .autoDispose<Verse?, (int sura, int ayah)>((ref, tuple) async {
  final (sura, ayah) = tuple;
  return await getVerseByChapterAndVerseNumber(
    chapterNumber: sura,
    verseNumber: ayah,
  );
});
