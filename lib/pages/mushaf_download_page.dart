import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/core/api/ffi.dart';
import 'package:quran_assistant/pages/quran_detail_page.dart';
import 'package:quran_assistant/utils/mushaf_utils.dart';

class MushafDownloadPage extends StatefulWidget {
  const MushafDownloadPage({super.key});

  @override
  State<MushafDownloadPage> createState() => _MushafDownloadPageState();
}

class _MushafDownloadPageState extends State<MushafDownloadPage> {
  @override
  void initState() {
    super.initState();
    // Memulai proses pengecekan setelah frame pertama selesai dibangun
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndProcessMushaf());
  }

  /// Fungsi utama yang mengatur seluruh logika
  Future<void> _checkAndProcessMushaf() async {
    // Panggil utility untuk mendapatkan semua informasi yang kita butuhkan
    final status = await MushafUtils.checkMushafStatus(
      MediaQuery.of(context).size.width,
    );

    if (status.isDownloaded) {
      // Jika sudah ada, langsung navigasi
      _navigateToQuran(status.variant);
    } else {
      // Jika belum ada, mulai proses download menggunakan info dari status
      await _startDownloadAndDecompress(
        url: status.downloadUrl,
        savePath: status.archivePath,
        outputDir: status.outputPath,
      );
    }
  }

  /// Menangani proses download (dengan dialog progres) dan dekompresi
  Future<void> _startDownloadAndDecompress({
    required String url,
    required String savePath,
    required String outputDir,
  }) async {
    double? progress = 0.0;
    String statusMessage = "Mengunduh file mushaf...";

    // Tampilkan dialog yang tidak bisa ditutup
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Mempersiapkan Data'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(statusMessage),
                const SizedBox(height: 16),
                // Indikator akan menjadi indeterminate (bergerak terus) saat progress = null
                LinearProgressIndicator(value: progress), 
                const SizedBox(height: 8),
                Text(progress != null ? '${(progress! * 100).toStringAsFixed(1)}%' : 'Mohon tunggu...'),
              ],
            ),
          );
        },
      ),
    );

    try {
      // --- TAHAP DOWNLOAD ---
      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            // Update UI dialog dari dalam showDialog
            (context as Element).markNeedsBuild(); 
            progress = received / total;
          }
        },
      );

      // --- TAHAP DEKOMPRESI ---
      if (mounted) {
        // Update status di dialog
        (context as Element).markNeedsBuild();
        statusMessage = "Mengekstrak file...";
        progress = null; // Buat progress bar menjadi indeterminate
      }
      
      debugPrint("Download selesai. Memulai dekompresi...");
      // Menjalankan FFI di background thread agar UI tidak freeze
      await compute(_decompressInIsolate, {'input': savePath, 'output': outputDir});
      debugPrint("Dekompresi selesai.");

      // Hapus file archive setelah berhasil didekompresi untuk menghemat ruang
      await File(savePath).delete();

      // Jika semua berhasil, tutup dialog dan navigasi
      if (mounted) {
        Navigator.pop(context); // Tutup dialog
        _navigateToQuran(outputDir.split('/').last); // Ambil nama varian dari path
      }
    } catch (e) {
      debugPrint("Terjadi error: $e");
      if (mounted) {
        Navigator.pop(context); // Tutup dialog jika error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mempersiapkan data: $e')),
        );
      }
    }
  }

  void _navigateToQuran(String resolution) {
    // Ganti halaman saat ini dengan halaman Quran, sehingga tidak bisa kembali ke halaman download
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuranPerPage(resolution: resolution),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan loading awal sebelum logika pengecekan selesai
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Memeriksa data mushaf..."),
          ],
        ),
      ),
    );
  }
}

/// Fungsi top-level untuk menjalankan dekompresi di isolate terpisah
Future<void> _decompressInIsolate(Map<String, String> paths) async {
  // Pastikan path tidak null
  final inputPath = paths['input']!;
  final outputPath = paths['output']!;
  decompressFile(inputPath, outputPath); // Panggil fungsi FFI Anda di sini
}