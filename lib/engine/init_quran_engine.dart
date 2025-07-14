import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_assistant/src/rust/api/engine_loader.dart';

Future<Map<String, Uint8List>> loadQuranEngineAssetData() async {
  final assets = [
    "chapters.bin",
    "all_verse_keys.bin",
    "ayah_texts.bin",
    "juzs.bin",
    "phrase_index.bin",
    "translation_metadata.bin",
    "translations_33.bin",
    "valid-matching-ayah.bin",
    "stop_words_arabic.bin",
    "inverted_index.bin",
    for (int i = 1; i <= 114; i++) "verse-by-chapter/chapter-$i.bin",
  ];

  final result = <String, Uint8List>{};

  for (final asset in assets) {
    final data = await rootBundle.load('assets/quran_assets/$asset');
    result[asset] = data.buffer.asUint8List();
  }

  return result;
}

Future<void> initQuranEngine() async {
  final mapData = await loadQuranEngineAssetData();

  await loadEngineDataFromFlutterAssets(map: mapData);
}

