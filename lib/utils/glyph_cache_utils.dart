import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlyphCache {
  static final GlyphCache _instance = GlyphCache._internal();
  factory GlyphCache() => _instance;
  GlyphCache._internal();

  final Map<int, List<dynamic>> _cache = {};
  bool isReady = false;

  static const _cacheKey = 'glyph_cache_ready';

  /// Mengecek apakah glyph sudah dicache sebelumnya (lintas sesi)
  Future<bool> isFullyCached() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cacheKey) ?? false;
  }

  /// Preload semua glyph JSON dari assets ke memori dan tandai sebagai siap
  Future<void> preloadAllGlyphs() async {
    if (isReady) return;

    for (int i = 1; i <= 604; i++) {
      final pageStr = i.toString().padLeft(3, '0');
      try {
        final jsonStr = await rootBundle.loadString('assets/glyphs_json/page_$pageStr.json');
        final parsed = json.decode(jsonStr);
        _cache[i] = parsed;
      } catch (e) {
        // Menangani jika ada file glyph yang tidak ditemukan atau corrupt
        debugPrint('❌ Gagal memuat glyph untuk halaman $i: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheKey, true); // Simpan status siap ke SharedPreferences
    isReady = true;
  }

  /// Mengambil glyph dari cache berdasarkan nomor halaman (1-based)
  List<dynamic> getGlyph(int pageNumber) => _cache[pageNumber] ?? [];

  /// Membersihkan cache dari memori
  void clear() {
    _cache.clear();
    isReady = false;
  }

  /// Menghapus flag SharedPreferences agar preload glyph dilakukan ulang di sesi berikutnya
  Future<void> invalidatePersistentCacheFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
