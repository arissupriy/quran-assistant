// lib/pages/mushaf_download_page.dart

import 'dart:io';
import 'dart:ui';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndDownloadIfNeeded(),
    );
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
    ref.listen<DownloadProgressState>(downloadProgressProvider, (
      previous,
      next,
    ) {
      if (!mounted) return;

      if (next.status == DownloadStatus.completed && !_navigateScheduled) {
        _navigateScheduled = true;
        Future.delayed(const Duration(milliseconds: 350), _navigateToMushaf);
      } else if (next.status == DownloadStatus.error &&
          next.errorMessage != null) {
        _showSnack(next.errorMessage!);
      } else if (next.status == DownloadStatus.canceled) {
        _showSnack('Unduhan mushaf dibatalkan.');
      }
    });

    final state = ref.watch(downloadProgressProvider);
    final mediaQuery = MediaQuery.of(context);
    final statusVisual = _resolveStatusVisual(state.status);
    final statusMessage = state.message.isNotEmpty
        ? state.message
        : statusVisual.subtitle;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF041C32),
              Color(0xFF04293A),
              Color(0xFF064663),
              Color(0xFF71C9CE),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: -40,
              child: _GradientBlob(
                size: 220,
                colors: [
                  Colors.white.withOpacity(0.18),
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
            Positioned(
              bottom: -80,
              right: -20,
              child: _GradientBlob(
                size: 300,
                colors: [
                  Colors.cyanAccent.withOpacity(0.14),
                  Colors.transparent,
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          mediaQuery.size.height -
                          mediaQuery.padding.vertical -
                          48,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 28),
                        _buildStatusCard(state, statusVisual, statusMessage),
                        const SizedBox(height: 24),
                        _buildInfoSection(state),
                        const SizedBox(height: 32),
                        _buildFooterActions(state),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Mushaf Superior',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Mempersiapkan Mushaf Digital',
          style: GoogleFonts.poppins(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Unduhan sekali agar bacaan mulus dan bebas distraksi kapan pun.',
          style: GoogleFonts.roboto(
            fontSize: 16,
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    DownloadProgressState state,
    _StatusVisual visual,
    String message,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.28),
                Colors.white.withOpacity(0.05),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: visual.colors),
                      boxShadow: [
                        BoxShadow(
                          color: visual.colors.last.withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(visual.icon, size: 34, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visual.title,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            message,
                            key: ValueKey(message),
                            style: GoogleFonts.roboto(
                              fontSize: 15,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (state.status == DownloadStatus.downloading)
                _buildProgressSection(state)
              else if (state.status == DownloadStatus.error)
                _buildErrorCaption(state)
              else if (state.status == DownloadStatus.completed)
                _buildCompletedCaption(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(DownloadProgressState state) {
    final progressValue = state.progress ?? 0;
    final progressText =
        '${(progressValue * 100).clamp(0, 100).toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: LinearProgressIndicator(
            value: progressValue,
            minHeight: 12,
            backgroundColor: Colors.white.withOpacity(0.18),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF4ADEDE)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              progressText,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Kemajuan unduhan',
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              state.progress == null ? 'Menghitung...' : 'Tetap nyala',
              style: GoogleFonts.roboto(fontSize: 13, color: Colors.white60),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorCaption(DownloadProgressState state) {
    return Text(
      state.errorMessage ?? 'Terjadi kesalahan yang tidak diketahui.',
      style: GoogleFonts.roboto(fontSize: 15, color: Colors.red[200]),
    );
  }

  Widget _buildCompletedCaption() {
    return Text(
      'Selesai! Mushaf siap digunakan secara offline. Kami akan mengarahkan Anda sebentar lagi.',
      style: GoogleFonts.roboto(fontSize: 15, color: Colors.greenAccent[100]),
    );
  }

  Widget _buildInfoSection(DownloadProgressState state) {
    final cards = _infoCardsForState(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kenapa harus menunggu?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) => _InfoCard(data: card)).toList(),
        ),
      ],
    );
  }

  Widget _buildFooterActions(DownloadProgressState state) {
    switch (state.status) {
      case DownloadStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontrol unduhan',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _cancelDownload,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Batalkan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.4)),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _showSnack(
                      'Anda bisa menutup aplikasi, proses tetap berjalan.',
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Lanjutkan aktivitas'),
                  ),
                ),
              ],
            ),
          ],
        );
      case DownloadStatus.error:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _retryDownload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Coba unduh lagi'),
        );
      case DownloadStatus.completed:
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF5DE0E6),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: _navigateToMushaf,
          icon: const Icon(Icons.menu_book_rounded),
          label: const Text('Buka Mushaf sekarang'),
        );
      case DownloadStatus.canceled:
        return Text(
          'Unduhan dibatalkan. Anda bisa mengetuk "Coba unduh lagi" untuk memulai ulang.',
          style: GoogleFonts.roboto(color: Colors.white70),
        );
      default:
        return Text(
          'Kami sedang memastikan file Anda lengkap sebelum digunakan.',
          style: GoogleFonts.roboto(color: Colors.white70),
        );
    }
  }

  List<_InfoCardData> _infoCardsForState(DownloadProgressState state) {
    final cards = <_InfoCardData>[
      const _InfoCardData(
        icon: Icons.offline_pin_rounded,
        title: 'Akses penuh',
        description: 'Baca mushaf kapan saja tanpa koneksi internet.',
        colors: [Color(0xFF5DE0E6), Color(0xFF004AAD)],
      ),
      const _InfoCardData(
        icon: Icons.security_rounded,
        title: 'Terverifikasi',
        description: 'File resmi Quran Assistant yang aman dan bersih.',
        colors: [Color(0xFFA8FF78), Color(0xFF78FFD6)],
      ),
      const _InfoCardData(
        icon: Icons.bolt_rounded,
        title: 'Tetap berjalan',
        description: 'Anda boleh menutup halaman ini, unduhan terus bekerja.',
        colors: [Color(0xFFFFA17F), Color(0xFF00223E)],
      ),
    ];

    if (state.status == DownloadStatus.downloading && state.progress != null) {
      cards.insert(
        0,
        _InfoCardData(
          icon: Icons.timelapse_rounded,
          title: '${(state.progress! * 100).toStringAsFixed(1)}% progres',
          description: 'Kami sedang mengemas halaman mushaf resolusi tinggi.',
          colors: const [Color(0xFFFFD200), Color(0xFFF7971E)],
        ),
      );
    }

    if (state.status == DownloadStatus.error) {
      cards.add(
        const _InfoCardData(
          icon: Icons.info_outline_rounded,
          title: 'Troubleshooting',
          description: 'Pastikan koneksi stabil atau coba beralih ke Wi-Fi.',
          colors: [Color(0xFFFF5858), Color(0xFFFBAB7E)],
        ),
      );
    }

    return cards;
  }

  _StatusVisual _resolveStatusVisual(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloading:
        return const _StatusVisual(
          title: 'Sedang mengunduh',
          subtitle: 'Mengambil paket mushaf Anda, mohon ditunggu.',
          icon: Icons.cloud_download_rounded,
          colors: [Color(0xFF00C6FB), Color(0xFF005BEA)],
        );
      case DownloadStatus.completed:
        return const _StatusVisual(
          title: 'Siap dibaca',
          subtitle: 'Mushaf berhasil disiapkan.',
          icon: Icons.check_circle_rounded,
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        );
      case DownloadStatus.error:
        return const _StatusVisual(
          title: 'Gagal memuat',
          subtitle: 'Ada gangguan ketika mengunduh file.',
          icon: Icons.error_outline_rounded,
          colors: [Color(0xFFFF512F), Color(0xFFDD2476)],
        );
      case DownloadStatus.canceled:
        return const _StatusVisual(
          title: 'Unduhan dibatalkan',
          subtitle: 'Anda bisa memulai ulang kapan saja.',
          icon: Icons.block_rounded,
          colors: [Color(0xFFFFA17F), Color(0xFF00223E)],
        );
      case DownloadStatus.checking:
      case DownloadStatus.decompressing:
      case DownloadStatus.initial:
        return const _StatusVisual(
          title: 'Menyiapkan data',
          subtitle:
              'Kami sedang memeriksa file mushaf terbaik untuk perangkat Anda.',
          icon: Icons.auto_fix_high_rounded,
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        );
    }
  }
}

class _GradientBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GradientBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _InfoCardData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> colors;

  const _InfoCardData({
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
  });
}

class _InfoCard extends StatelessWidget {
  final _InfoCardData data;

  const _InfoCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: data.colors,
        ),
        boxShadow: [
          BoxShadow(
            color: data.colors.last.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            data.title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.description,
            style: GoogleFonts.roboto(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusVisual {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;

  const _StatusVisual({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });
}
