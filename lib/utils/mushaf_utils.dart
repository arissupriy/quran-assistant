// lib/utils/mushaf_utils.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Class untuk menampung hasil pengecekan data mushaf.
class MushafStatus {
  final bool isDownloaded;
  final String variant; // cth: 'width_1080'
  final String downloadUrl;
  final String archivePath; // Path untuk menyimpan file .tar.zst
  final String outputPath;  // Path untuk folder hasil dekompresi

  MushafStatus({
    required this.isDownloaded,
    required this.variant,
    required this.downloadUrl,
    required this.archivePath,
    required this.outputPath,
  });
}

class MushafUtils {
  /// Fungsi utama untuk mengecek status data mushaf berdasarkan lebar layar.
  /// Mengembalikan object [MushafStatus] yang berisi semua info yang dibutuhkan.
  static Future<MushafStatus> checkMushafStatus(double screenWidth) async {
    // 1. Tentukan varian resolusi
    final String variant = _getMushafVariant(screenWidth);

    // 2. Tentukan semua path yang relevan
    final docDir = await getApplicationDocumentsDirectory();
    final String outputPath = '${docDir.path}/$variant';
    final String archivePath = '${docDir.path}/$variant.tar.zst';
    const String baseUrl = 'https://quran.tsaqafah.id';
    final String downloadUrl = '$baseUrl/$variant.tar.zst';

    // 3. Cek apakah file sudah ada
    final bool isDownloaded = await _isMushafDownloaded(outputPath);

    debugPrint("Mushaf variant: $variant, Downloaded: $isDownloaded");

    // 4. Kembalikan semua informasi dalam satu objek
    return MushafStatus(
      isDownloaded: isDownloaded,
      variant: variant,
      downloadUrl: downloadUrl,
      archivePath: archivePath,
      outputPath: outputPath,
    );
  }

  /// Menentukan varian resolusi mushaf berdasarkan lebar layar.
  static String _getMushafVariant(double screenWidth) {
    if (screenWidth >= 1440) {
      return 'width_1440';
    } else if (screenWidth >= 1080) {
      return 'width_1080';
    } else {
      return 'width_720';
    }
  }

  /// Mengecek apakah mushaf pada direktori tertentu sudah diunduh.
  /// Cukup dengan memeriksa file pertama saja ('page001.png').
  static Future<bool> _isMushafDownloaded(String outputPath) async {
    final sentinelFile = File('$outputPath/page001.png');
    return await sentinelFile.exists();
  }
}