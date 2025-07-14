// lib/utils/quran_utils.dart

import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Kembalikan resolusi layar sebagai suffix mushafpack
String getMushafResolutionSuffix(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  // Bisa kamu ganti batas sesuai desain
  return width >= 1080 ? '1440' : '1080';
}

Future<String?> getMushafFilePathIfExists() async {
  final dir = await getApplicationSupportDirectory();

  // Prioritaskan file hasil unduhan dengan nama tetap
  final downloadedFile = File('${dir.path}/data.mushafpack');
  if (await downloadedFile.exists()) return downloadedFile.path;

  // // Cek juga file default sesuai resolusi
  // final defaultFile = File('${dir.path}/madani-$resolution.mushafpack');
  // if (await defaultFile.exists()) return defaultFile.path;

  return null;
}


Future<File?> getMushafDownloadedFile(String fileName) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$fileName');
    return file.existsSync() ? file : null;
  } catch (e) {
    return null;
  }
}


/// Ganti URL sesuai kebutuhan
Future<String> getMushafDownloadUrl(String resolution) async {
  // Contoh URL:
  return 'https://quran.tsaqafah.id/madani-$resolution.mushafpack';
}

