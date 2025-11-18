import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/models/article_models.dart';
import 'package:quran_assistant/pages/articles/article_detail_page.dart';
import 'package:quran_assistant/providers/global_audio_provider.dart';
import 'package:share_plus/share_plus.dart';

class ArticleAudioDetailPage extends ConsumerStatefulWidget {
  const ArticleAudioDetailPage({super.key, required this.audio});

  final ArticleAudio audio;

  @override
  ConsumerState<ArticleAudioDetailPage> createState() =>
      _ArticleAudioDetailPageState();
}

class _ArticleAudioDetailPageState
    extends ConsumerState<ArticleAudioDetailPage> {
  // Local UI state will be driven from global audio controller provider

  @override
  void initState() {
    super.initState();
    // Trigger global player to prepare and play this audio when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(globalAudioControllerProvider.notifier);
      final currentState = ref.read(globalAudioControllerProvider);
      final isSameAudio = currentState.current?.id == widget.audio.id;
      final hasLoadedMedia = currentState.mediaItem != null;
      final hasError = currentState.error != null;

      if (!isSameAudio || !hasLoadedMedia || hasError) {
        controller.playArticleAudio(widget.audio);
      }
    });
  }

  @override
  void dispose() {
    // Keep global player alive; controller will dispose it when app exits
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    await ref.read(globalAudioControllerProvider.notifier).togglePlayPause();
  }

  void _seek(double value) {
    final target = Duration(milliseconds: value.round());
    ref.read(globalAudioControllerProvider.notifier).seek(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl =
        widget.audio.featuredImageUrl ?? widget.audio.article?.featuredImageUrl;
    final audioState = ref.watch(globalAudioControllerProvider);
    final isCurrent = audioState.current?.id == widget.audio.id;
    final error = isCurrent ? audioState.error : null;
    final isDownloading = isCurrent && audioState.isDownloading;
    final downloadProgress = isCurrent ? audioState.downloadProgress : null;
    final isLoading = isCurrent && audioState.mediaItem == null && !isDownloading && error == null;
    final canPlay = isCurrent && audioState.mediaItem != null && !isDownloading && error == null;
    final isPlaying = isCurrent && audioState.isPlaying;
    final duration = isCurrent ? audioState.duration : Duration.zero;
    final position = isCurrent ? audioState.position : Duration.zero;
    final isCached = isCurrent && audioState.cachedPath != null;
    final showProgressIndicator = isLoading || isDownloading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _AudioBackdrop(imageUrl: imageUrl),
          SafeArea(
            child: Column(
              children: [
                _buildToolbar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildArtwork(imageUrl),
                          const SizedBox(height: 32),
                          _buildTitles(theme),
                          const SizedBox(height: 28),
                          _buildProgress(
                            context,
                            theme,
                            position,
                            duration,
                            canPlay,
                          ),
                          const SizedBox(height: 28),
                          _buildControls(
                            context,
                            theme,
                            canPlay,
                            isPlaying,
                          ),
                          const SizedBox(height: 28),
                          _buildDownloadProgress(
                            theme,
                            error: error,
                            isCached: isCached,
                            isDownloading: isDownloading,
                            downloadProgress: downloadProgress,
                          ),
                          const SizedBox(height: 20),
                          if (widget.audio.article != null)
                            _buildArticleButton(context, theme),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                error,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.redAccent,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (showProgressIndicator)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isLoading
                                        ? 'Menyiapkan audio...'
                                        : 'Audio sedang diunduh, mohon tunggu',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 34,
            color: Colors.white,
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Sedang Diputar',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            color: Colors.white70,
            onPressed: widget.audio.audioUrl != null ? _shareAudio : null,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            color: Colors.white70,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Future<void> _shareAudio() async {
    final url = widget.audio.audioUrl;
    if (url == null) return;
    await Share.share(url, subject: widget.audio.title);
  }

  Widget _buildArtwork(String? imageUrl) {
    return Hero(
      tag: widget.audio.heroTag,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: AspectRatio(
            aspectRatio: 1,
            child: imageUrl == null
                ? Container(
                    color: Colors.grey.shade900,
                    child: const Icon(
                      Icons.podcasts_rounded,
                      size: 72,
                      color: Colors.white70,
                    ),
                  )
                : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildTitles(ThemeData theme) {
    final parent = widget.audio.article;
    return Column(
      children: [
        Text(
          widget.audio.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        if (parent != null)
          Text(
            parent.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          )
        else
          Text(
            'Audio kajian',
            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70),
          ),
      ],
    );
  }

  Widget _buildProgress(
    BuildContext context,
    ThemeData theme,
    Duration position,
    Duration duration,
    bool canSeek,
  ) {
    final double sliderMax = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final double sliderValue = position.inMilliseconds.toDouble().clamp(
      0,
      sliderMax,
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: sliderValue,
            min: 0,
            max: sliderMax,
            onChanged: canSeek ? (value) => _seek(value) : null,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(position),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
            Text(
              _formatDuration(duration),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(
    BuildContext context,
    ThemeData theme,
    bool canPlay,
    bool isPlaying,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.favorite_border_rounded),
          color: Colors.white70,
          onPressed: () {},
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded),
          color: Colors.white24,
          iconSize: 32,
          onPressed: null,
        ),
        const SizedBox(width: 4),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(18),
          ),
          onPressed: canPlay ? _togglePlayback : null,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 34,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          color: Colors.white24,
          iconSize: 32,
          onPressed: null,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded),
          color: Colors.white70,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildArticleButton(BuildContext context, ThemeData theme) {
    final parent = widget.audio.article;
    if (parent == null) return const SizedBox.shrink();

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArticleDetailPage(articleId: parent.id),
          ),
        );
      },
      icon: const Icon(Icons.menu_book_rounded),
      label: const Text('Baca artikel terkait'),
    );
  }

  Widget _buildDownloadProgress(
    ThemeData theme, {
    required String? error,
    required bool isCached,
    required bool isDownloading,
    required double? downloadProgress,
  }) {
    if (error != null) return const SizedBox.shrink();
    if (isCached) {
      return Text(
        'Audio tersimpan untuk diputar ulang offline.',
        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
        textAlign: TextAlign.center,
      );
    }

    if (!isDownloading) {
      return const SizedBox.shrink();
    }

    final progressText = downloadProgress != null
        ? '${(downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
        : 'menghitung ukuran...';

    return Column(
      children: [
        LinearProgressIndicator(
          value: downloadProgress,
          minHeight: 6,
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          'Mengunduh audio ($progressText)',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _AudioBackdrop extends StatelessWidget {
  const _AudioBackdrop({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      colors: [
        Colors.black.withValues(alpha: 0.95),
        Colors.black.withValues(alpha: 0.9),
        Colors.black.withValues(alpha: 0.85),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: imageUrl == null
            ? const SizedBox.shrink()
            : Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
