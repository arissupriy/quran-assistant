import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageDataItem {
  const StorageDataItem({
    required this.id,
    required this.title,
    required this.description,
    required this.sizeBytes,
    this.path,
    this.extra,
  });

  final String id;
  final String title;
  final String description;
  final int sizeBytes;
  final String? path;
  final Map<String, String>? extra;
}

class DataStorageService {
  Future<List<StorageDataItem>> collect() async {
    final supportDir = await getApplicationSupportDirectory();
  final cacheDir = await getTemporaryDirectory();
  final documentsDir = await getApplicationDocumentsDirectory();
  final audioDir = Directory(p.join(supportDir.path, 'offline_audios'));

    final mushafFile = File(p.join(supportDir.path, 'data.mushafpack'));
    final mushafSize = await _fileSize(mushafFile);

    final audioCacheSize = await _directorySize(audioDir);

    final hiveSize = await _directorySize(
      documentsDir,
      where: (entity) => entity is File && entity.path.endsWith('.hive'),
    );

    final cacheSize = await _directorySize(cacheDir);
    final prefsEstimate = await _sharedPreferencesEstimate();

    return [
      StorageDataItem(
        id: 'mushaf',
        title: 'Mushaf Offline',
        description: 'Paket mushaf yang diunduh agar bacaan tetap tersedia tanpa internet.',
        sizeBytes: mushafSize,
        path: mushafFile.path,
        extra: {
          'Lokasi': mushafFile.path,
          'Status': mushafSize > 0 ? 'Terpasang' : 'Belum terpasang',
        },
      ),
      StorageDataItem(
        id: 'audio_cache',
        title: 'Audio Kajian Tersimpan',
        description: 'Cache audio artikel yang pernah diunduh oleh pemutar.',
        sizeBytes: audioCacheSize,
        path: audioDir.path,
        extra: {
          'Lokasi': audioDir.path,
          'Catatan': 'File akan diunduh ulang bila dibersihkan.',
        },
      ),
      StorageDataItem(
        id: 'hive',
        title: 'Basis data internal',
        description: 'Data kuis, sesi baca, dan konfigurasi lain yang disimpan lokal.',
        sizeBytes: hiveSize,
        path: documentsDir.path,
        extra: {
          'Direktori': documentsDir.path,
        },
      ),
      StorageDataItem(
        id: 'cache',
        title: 'Cache aplikasi',
        description: 'File sementara seperti gambar dan file sementara lainnya.',
        sizeBytes: cacheSize,
        path: cacheDir.path,
      ),
      StorageDataItem(
        id: 'preferences',
        title: 'Pengaturan & preferensi',
        description: 'Data ringan berupa preferensi pengguna dan konfigurasi.',
        sizeBytes: prefsEstimate,
        extra: {
          'Catatan': 'Nilai merupakan perkiraan dari jumlah data yang tersimpan.',
        },
      ),
    ];
  }

  Future<int> _fileSize(File file) async {
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  Future<int> _directorySize(
    Directory dir, {
    bool Function(FileSystemEntity entity)? where,
  }) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        if (where != null && !where(entity)) continue;
        total += await entity.length();
      }
    }
    return total;
  }

  Future<int> _sharedPreferencesEstimate() async {
    final prefs = await SharedPreferences.getInstance();
    var total = 0;
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is String) {
        total += value.length * 2;
      } else if (value is List<String>) {
        total += value.fold<int>(0, (sum, item) => sum + item.length * 2);
      } else {
        total += 8;
      }
    }
    return total;
  }
}
