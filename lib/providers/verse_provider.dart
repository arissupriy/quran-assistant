import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/api/quran/verse.dart';
import 'package:quran_assistant/src/rust/data_loader/verse_by_chapter.dart';

final verseDetailProvider = FutureProvider.family<VerseDetailWithWords?, String>((ref, verseKey) async {
  debugPrint("Fetching verse details for: $verseKey");
  return await getVerseDetails(verseKey: verseKey);
});