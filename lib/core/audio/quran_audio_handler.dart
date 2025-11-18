import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  QuranAudioHandler() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen(_handlePlayerState);

    _player.durationStream.listen((duration) {
      final currentItem = mediaItem.value;
      if (currentItem == null) return;
      mediaItem.add(currentItem.copyWith(duration: duration));
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final currentState = playbackState.value;
    playbackState.add(
      currentState.copyWith(
        controls: [
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1],
        processingState: _transformProcessingState(_player.processingState),
        playing: playing,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _transformProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  void _handlePlayerState(PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      stop();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    this.mediaItem.add(mediaItem);
    final localPath =
        mediaItem.extras != null ? mediaItem.extras!["path"] as String? : null;
    final uri = localPath != null ? Uri.file(localPath) : Uri.parse(mediaItem.id);
    await _player.setAudioSource(AudioSource.uri(uri));
    await _player.play();
  }

  @override
  Future<void> playFromUri(Uri uri, [Map<String, dynamic>? extras]) {
    final item = MediaItem(
      id: uri.toString(),
      title: extras?["title"] as String? ?? "Audio",
      artUri:
          extras?["artUri"] != null ? Uri.parse(extras!["artUri"] as String) : null,
      extras: extras,
    );
    return playMediaItem(item);
  }
}
