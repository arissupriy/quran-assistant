// lib/pages/mushaf_download_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/core/download/mushaf_download_manager.dart';
import 'package:quran_assistant/core/download/mushaf_download_preferences.dart';
import 'package:quran_assistant/main_screen.dart';
import 'package:quran_assistant/pages/mushaf/mushaf_detail_page.dart';
import 'package:quran_assistant/providers/download_progress_provider.dart';
import 'package:quran_assistant/utils/quran_utils.dart';

class MushafDownloadPage extends ConsumerStatefulWidget {
  final int? initialPage;
  const MushafDownloadPage({super.key, this.initialPage});

  @override
  ConsumerState<MushafDownloadPage> createState() => _MushafDownloadPageState();
}

class _MushafDownloadPageState extends ConsumerState<MushafDownloadPage> {
  bool _navigateScheduled = false;

  @override
  void initState() {
    super.initState();
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
      final mushafPath = await _resolveMushafPath();
      final mushafFile = File(mushafPath);

      final url = await getMushafDownloadUrl(resolution);

      if (await mushafFile.exists()) {
        notifier.setCompleted();
        await MushafDownloadPreferences.clearInitialPage();
        return;
      }

      final manager = ref.read(mushafDownloadManagerProvider);
      await MushafDownloadPreferences.setInitialPage(widget.initialPage);
      await manager.startDownload(
        url: url,
        savePath: mushafPath,
        initialPage: widget.initialPage,
      );
    } catch (e) {
      notifier.setError('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<String> _resolveMushafPath() async {
    final mushafDir = await getApplicationSupportDirectory();
    return '${mushafDir.path}/data.mushafpack';
  }

  Future<void> _cancelDownload() async {
    final manager = ref.read(mushafDownloadManagerProvider);
    await manager.cancelDownload();
  }

  void _navigateToMushaf() {
    if (!mounted) return;
    final target = widget.initialPage != null
        ? MushafDetailPage(pageNumber: widget.initialPage!)
        : const MainScreen();

    MushafDownloadPreferences.clearInitialPage();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DownloadProgressState>(downloadProgressProvider, (previous, next) {
      if (!mounted) return;

      if (next.status == DownloadStatus.completed && !_navigateScheduled) {
        _navigateScheduled = true;
        Future.delayed(const Duration(milliseconds: 350), _navigateToMushaf);
      } else if (next.status == DownloadStatus.error && next.errorMessage != null) {
        _showSnack(next.errorMessage!);
      } else if (next.status == DownloadStatus.canceled) {
        _showSnack('Unduhan mushaf dibatalkan.');
      }
    });

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
                        state.progress != null
                            ? '${(state.progress! * 100).toStringAsFixed(1)}%'
                            : 'Menyiapkan unduhan...',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: Colors.teal[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _cancelDownload,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Batalkan unduhan'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[700],
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
      case DownloadStatus.canceled:
        return const Icon(Icons.cancel_outlined, size: 80, color: Colors.orange);
      default:
        return const SizedBox.shrink();
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
