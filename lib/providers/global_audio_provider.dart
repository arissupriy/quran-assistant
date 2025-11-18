import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/core/models/article_models.dart';
import 'package:quran_assistant/providers/article_provider.dart';
import 'package:quran_assistant/providers/audio_handler_provider.dart';

class GlobalAudioState {
  static const _sentinel = Object();

  final ArticleAudio? current;
  final MediaItem? mediaItem;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool isDownloading;
  final double? downloadProgress;
  final String? cachedPath;
  final String? error;

  const GlobalAudioState({
    this.current,
    this.mediaItem,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isDownloading = false,
    this.downloadProgress,
    this.cachedPath,
    this.error,
  });

  GlobalAudioState copyWith({
    Object? current = _sentinel,
    Object? mediaItem = _sentinel,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isDownloading,
    Object? downloadProgress = _sentinel,
    Object? cachedPath = _sentinel,
    Object? error = _sentinel,
  }) {
    return GlobalAudioState(
      current:
          identical(current, _sentinel) ? this.current : current as ArticleAudio?,
      mediaItem:
          identical(mediaItem, _sentinel) ? this.mediaItem : mediaItem as MediaItem?,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: identical(downloadProgress, _sentinel)
          ? this.downloadProgress
          : downloadProgress as double?,
      cachedPath: identical(cachedPath, _sentinel)
          ? this.cachedPath
          : cachedPath as String?,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

class GlobalAudioController extends StateNotifier<GlobalAudioState> {
  GlobalAudioController(this.ref, this._audioHandler)
      : _dio = Dio(),
        super(const GlobalAudioState()) {
    _playbackSub = _audioHandler.playbackState.listen(_handlePlaybackState);
    _mediaItemSub = _audioHandler.mediaItem.listen(_handleMediaItem);
    _positionSub = AudioService.position.listen((pos) {
      state = state.copyWith(position: pos);
    });
  }

  final Ref ref;
  final AudioHandler _audioHandler;
  final Dio _dio;
  late final StreamSubscription<PlaybackState> _playbackSub;
  late final StreamSubscription<MediaItem?> _mediaItemSub;
  late final StreamSubscription<Duration> _positionSub;
  PlaybackState? _latestPlaybackState;

  void _handlePlaybackState(PlaybackState playbackState) {
    _latestPlaybackState = playbackState;
    state = state.copyWith(isPlaying: playbackState.playing);
    if (playbackState.processingState == AudioProcessingState.idle &&
        !playbackState.playing) {
      state = state.copyWith(position: Duration.zero, isPlaying: false);
    }
  }

  void _handleMediaItem(MediaItem? item) {
    if (item == null) return;
    state = state.copyWith(
      mediaItem: item,
      duration: item.duration ?? state.duration,
    );
  }

  @override
  void dispose() {
    _playbackSub.cancel();
    _mediaItemSub.cancel();
    _positionSub.cancel();
    super.dispose();
  }

  Future<void> playArticleAudio(ArticleAudio audio) async {
    state = GlobalAudioState(current: audio);

    final rawUrl = audio.audioUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      state = state.copyWith(error: 'Audio belum tersedia untuk konten ini.');
      return;
    }

    Uri? uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      state = state.copyWith(error: 'URL audio tidak valid.');
      return;
    }

    if (!uri.hasScheme || uri.host.isEmpty) {
      final baseUrl = ref.read(articleApiServiceProvider).baseUrl;
      final baseUri = Uri.parse(baseUrl);
      uri = baseUri.resolve(rawUrl);
    }

    try {
      await _audioHandler.stop();
      final file = await _getOrDownloadFile(audio, uri);

      final imageUrl = audio.featuredImageUrl ?? audio.article?.featuredImageUrl;
      final mediaItem = MediaItem(
        id: audio.id,
        album: audio.article?.title ?? 'Audio',
        title: audio.title,
        artUri: imageUrl != null ? Uri.parse(imageUrl) : null,
        extras: {'path': file.path},
      );

      if (kDebugMode) {
        debugPrint('[GlobalAudio] Prepared file=${file.path}');
      }

      state = state.copyWith(
        current: audio,
        mediaItem: mediaItem,
        cachedPath: file.path,
        error: null,
        isDownloading: false,
  downloadProgress: 1.0,
      );
      await _audioHandler.playMediaItem(mediaItem);
    } catch (err) {
      debugPrint('[GlobalAudio] Error preparing audio: $err');
      state = state.copyWith(error: 'Gagal memuat audio: $err', isDownloading: false);
    }
  }

  Future<File> _getOrDownloadFile(ArticleAudio audio, Uri uri) async {
    final cacheFile = await _resolveCacheFile(audio.id);
    if (await cacheFile.exists()) {
      if (kDebugMode) debugPrint('[GlobalAudio] Using cached file ${cacheFile.path}');
      state = state.copyWith(
        isDownloading: false,
        downloadProgress: 1.0,
        cachedPath: cacheFile.path,
      );
      return cacheFile;
    }

  state = state.copyWith(isDownloading: true, downloadProgress: 0.0);
    if (kDebugMode) debugPrint('[GlobalAudio] Download started: $uri');

    try {
      await _dio.downloadUri(
        uri,
        cacheFile.path,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          state = state.copyWith(downloadProgress: total > 0 ? received / total : null);
          if (total > 0 && kDebugMode) {
            debugPrint('[GlobalAudio] Download ${(received / total * 100).toStringAsFixed(1)}%');
          }
        },
      );
  state = state.copyWith(isDownloading: false, downloadProgress: 1.0);
      if (kDebugMode) debugPrint('[GlobalAudio] Download finished: ${cacheFile.path}');
      return cacheFile;
    } catch (err) {
      debugPrint('[GlobalAudio] Download error: $err');
      state = state.copyWith(isDownloading: false, downloadProgress: null);
      rethrow;
    }
  }

  Future<File> _resolveCacheFile(String id) async {
    final dir = await getTemporaryDirectory();
    final fileName = 'article_audio_$id.mp3';
    return File(p.join(dir.path, fileName));
  }

  Future<void> togglePlayPause() async {
    final processingState = _latestPlaybackState?.processingState;

    if (!state.isPlaying &&
        processingState == AudioProcessingState.idle &&
        state.mediaItem != null) {
      await _audioHandler.playMediaItem(state.mediaItem!);
      return;
    }

    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  Future<void> stopAndReset() async {
    await _audioHandler.stop();
    state = const GlobalAudioState();
    _latestPlaybackState = null;
  }
}

final globalAudioControllerProvider =
    StateNotifierProvider<GlobalAudioController, GlobalAudioState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return GlobalAudioController(ref, handler);
});
