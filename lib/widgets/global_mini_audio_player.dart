import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/articles/article_audio_detail_page.dart';
import 'package:quran_assistant/providers/global_audio_provider.dart';

class GlobalMiniAudioPlayer extends ConsumerWidget {
  const GlobalMiniAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(globalAudioControllerProvider);
    final audio = state.current;
    if (audio == null) {
      return const SizedBox.shrink();
    }

    final imageUrl = audio.featuredImageUrl ?? audio.article?.featuredImageUrl;
    final theme = Theme.of(context);
    final isInteracting = !state.isDownloading && state.error == null;
    final double progress = state.duration.inMilliseconds > 0
        ? (state.position.inMilliseconds / state.duration.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;
    final subtitle = state.error ?? audio.article?.title ?? 'Audio kajian';
    final subtitleColor = state.error != null ? Colors.redAccent : Colors.white70;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Padding(
        key: ValueKey(audio.id),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Dismissible(
          key: ValueKey('mini-player-${audio.id}'),
          direction: DismissDirection.horizontal,
          onDismissed: (_) => ref
              .read(globalAudioControllerProvider.notifier)
              .stopAndReset(),
          background: _buildDismissBackground(
            alignment: Alignment.centerLeft,
            icon: Icons.swipe_right_alt_rounded,
          ),
          secondaryBackground: _buildDismissBackground(
            alignment: Alignment.centerRight,
            icon: Icons.swipe_left_alt_rounded,
          ),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: Colors.black87,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleAudioDetailPage(audio: audio),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _MiniArtwork(
                          imageUrl: imageUrl,
                          playbackProgress: state.error != null ? 0 : progress,
                          downloadProgress: state.downloadProgress,
                          isDownloading: state.isDownloading,
                          hasError: state.error != null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                audio.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (state.isDownloading)
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              state.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                            onPressed: isInteracting
                                ? () => ref
                                    .read(globalAudioControllerProvider.notifier)
                                    .togglePlayPause()
                                : null,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground({
    required Alignment alignment,
    required IconData icon,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: Colors.white54),
    );
  }
}

class _MiniArtwork extends StatelessWidget {
  const _MiniArtwork({
    required this.imageUrl,
    required this.playbackProgress,
    required this.downloadProgress,
    required this.isDownloading,
    required this.hasError,
  });

  final String? imageUrl;
  final double playbackProgress;
  final double? downloadProgress;
  final bool isDownloading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final indicatorValue = (isDownloading ? (downloadProgress ?? 0) : playbackProgress)
        .clamp(0.0, 1.0);
    final Color progressColor = hasError ? Colors.redAccent : Colors.white70;

    Widget artwork = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade800,
      ),
      child: const Icon(Icons.podcasts_rounded, color: Colors.white70),
    );

    if (imageUrl != null) {
      artwork = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
        ),
      );
    }

    return SizedBox(
      width: 56,
      height: 56,
      child: CustomPaint(
        painter: _ArtworkBorderPainter(
          progress: indicatorValue.isNaN ? 0 : indicatorValue,
          color: progressColor,
          backgroundColor: Colors.white24,
          strokeWidth: 3,
        ),
        child: Center(child: artwork),
      ),
    );
  }
}

class _ArtworkBorderPainter extends CustomPainter {
  const _ArtworkBorderPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final deflate = strokeWidth / 2;
    final rect = Offset(deflate, deflate) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    final basePath = Path()..addRRect(rrect);
    final basePaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(basePath, basePaint);

    if (progress <= 0) return;

    final metrics = basePath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final targetLength = metric.length * progress.clamp(0.0, 1.0);
    final progressPath = metric.extractPath(0, targetLength);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(progressPath, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _ArtworkBorderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        color != oldDelegate.color ||
        backgroundColor != oldDelegate.backgroundColor ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
