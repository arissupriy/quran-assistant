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
    // "translation_metadata.bin",
    // "translations_33.bin",
    "valid-matching-ayah.bin",
    "stop_words_arabic.bin",
    "inverted_index.bin",
    "ayah_phrase_map.bin",
    "highlight_index_combined.bin",
    "lemma_index_arab.bin",
    "phrase_highlight_map.bin",
    "semantic_index_arab.bin",
    "stem_index_arab.bin",
    "words.bin",
    "page_first_verse.bin",
    "tajweed_meta.bin",
    "tajweed_index.bin",
    "translation.bin",
    

    for (int i = 1; i <= 114; i++) "verse-by-chapter/verses-chapter-$i.bin",
  ];

  final result = <String, Uint8List>{};
  
  debugPrint('🔄 Loading ${assets.length} Quran engine assets...');
  
  for (int i = 0; i < assets.length; i++) {
    final asset = assets[i];
    try {
      final data = await rootBundle.load('assets/quran_assets/$asset');
      result[asset] = data.buffer.asUint8List();
      
      // Progress indicator
      if (kDebugMode) {
        debugPrint('📄 Loaded ${i + 1}/${assets.length}: $asset (${data.lengthInBytes} bytes)');
      }
    } catch (e) {
      debugPrint('❌ Failed to load asset: $asset');
      debugPrint('   Error: $e');
      
      // Rethrow untuk critical assets
      if (asset == "chapters.bin" || asset == "ayah_texts.bin") {
        throw Exception('Critical asset missing: $asset');
      }
      
      // Untuk non-critical assets, log tapi lanjutkan
      debugPrint('⚠️ Non-critical asset skipped: $asset');
    }
  }
  
  debugPrint('✅ Successfully loaded ${result.length} assets');
  return result;
}

Future<void> initQuranEngine() async {
  try {
    debugPrint('🔄 Initializing Quran Engine...');
    
    // Load asset data
    final mapData = await loadQuranEngineAssetData();
    
    debugPrint('🔄 Loading data into Rust engine...');
    
    // Load ke Rust engine
    await loadEngineDataFromFlutterAssets(map: mapData);
    
    debugPrint('✅ Quran Engine initialized successfully');
    
  } catch (e) {
    debugPrint('❌ Failed to initialize Quran Engine: $e');
    rethrow;
  }
}