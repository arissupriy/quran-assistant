// lib/pages/mushaf_download_page.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/pages/mushaf_detail_page.dart';
import 'package:quran_assistant/providers/download_progress_provider.dart';
import 'package:quran_assistant/utils/quran_utils.dart';
import 'package:google_fonts/google_fonts.dart';

class MushafDownloadPage extends ConsumerStatefulWidget {
  final int? initialPage;
  const MushafDownloadPage({super.key, this.initialPage});

  @override
  ConsumerState<MushafDownloadPage> createState() => _MushafDownloadPageState();
}

class _MushafDownloadPageState extends ConsumerState<MushafDownloadPage> {
  @override
  void initState() {
    super.initState();
    // debugPrint('MushafDownloadPage initialized with initialPage: ${widget.initialPage}');
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndDownloadIfNeeded());
  }

  void _retryDownload() {
    ref.read(downloadProgressProvider.notifier).reset();
    _checkAndDownloadIfNeeded();
  }

  Future<void> _checkAndDownloadIfNeeded() async {
    final notifier = ref.read(downloadProgressProvider.notifier);
    notifier.setChecking();

    try {
      final resolution = getMushafResolutionSuffix(context);
      final mushafDir = await getApplicationSupportDirectory();
      final mushafPath = '${mushafDir.path}/data.mushafpack';
      final mushafFile = File(mushafPath);

      final url = await getMushafDownloadUrl(resolution);

      if (mushafFile.existsSync()) {
        notifier.setCompleted();
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateToMushaf();
      } else {
        await _downloadMushaf(url, mushafPath);
      }
    } catch (e) {
      notifier.setError('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> _downloadMushaf(String url, String savePath) async {
    final notifier = ref.read(downloadProgressProvider.notifier);

    try {
      notifier.setDownloading(0.0);
      final dio = Dio();

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            notifier.setDownloading(progress);
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      notifier.setCompleted();
      await Future.delayed(const Duration(milliseconds: 500));
      _navigateToMushaf();
    } catch (e) {
      notifier.setError('Download gagal: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh mushaf: $e')),
      );
    }
  }

  void _navigateToMushaf() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MushafDetailPage(
          pageNumber: widget.initialPage ?? 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(downloadProgressProvider);

    return Scaffold(
      backgroundColor: Colors.teal[50],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Mempersiapkan Mushaf Digital',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                _buildStatusIndicator(state),
                const SizedBox(height: 30),
                Text(
                  state.message.isNotEmpty
                      ? state.message
                      : 'Memeriksa data mushaf...',
                  style: GoogleFonts.roboto(fontSize: 18, color: Colors.teal[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (state.status == DownloadStatus.downloading)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: state.progress,
                        backgroundColor: Colors.teal[100],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${(state.progress! * 100).toStringAsFixed(1)}%',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.teal[600],
                        ),
                      ),
                    ],
                  ),
                if (state.status == DownloadStatus.error)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: ElevatedButton.icon(
                      onPressed: _retryDownload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        textStyle: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(DownloadProgressState state) {
    switch (state.status) {
      case DownloadStatus.checking:
        return const CircularProgressIndicator();
      case DownloadStatus.downloading:
        return const Icon(Icons.cloud_download_rounded, size: 80, color: Colors.teal);
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green);
      case DownloadStatus.error:
        return const Icon(Icons.error_outline_rounded, size: 80, color: Colors.red);
      default:
        return const SizedBox.shrink();
    }
  }
}
