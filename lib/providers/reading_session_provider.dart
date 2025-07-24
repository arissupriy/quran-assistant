import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:quran_assistant/src/rust/api/quran/chapter.dart'; // Import getChapterByPage
import 'package:quran_assistant/src/rust/api/quran/metadata.dart';
import 'package:quran_assistant/src/rust/frb_generated.dart'; // Import api

// Provider tidak berubah, tetap menggunakan NotifierProvider
final readingSessionRecorderProvider =
    NotifierProvider<ReadingSessionRecorder, void>(ReadingSessionRecorder.new);

class ReadingSessionRecorder extends Notifier<void> {
  final _boxCompleter = Completer<Box<ReadingSession>>();
  Future<Box<ReadingSession>> get _box => _boxCompleter.future;

  ReadingSession? _activeSession;

  @override
  void build() {
    ref.keepAlive();
    _initBox();
    ref.onDispose(() {
      debugPrint('🧼 Provider disposed, mengakhiri sesi aktif jika ada...');
      endSession();
    });
  }

  Future<void> _initBox() async {
    if (_boxCompleter.isCompleted) return;
    
    try {
      // Check if box is already open
      if (Hive.isBoxOpen('reading_sessions')) {
        debugPrint('📦 Box reading_sessions already open, using existing box');
        final box = Hive.box<ReadingSession>('reading_sessions');
        _boxCompleter.complete(box);
      } else {
        debugPrint('📦 Opening new reading_sessions box');
        final box = await Hive.openBox<ReadingSession>('reading_sessions');
        _boxCompleter.complete(box);
      }
    } catch (e) {
      debugPrint('❌ Error initializing box: $e');
      
      // If there's a type mismatch, close and reopen with correct type
      if (e.toString().contains('already open')) {
        try {
          await Hive.close();
          debugPrint('🔄 Closed all Hive boxes, reopening with correct type');
          final box = await Hive.openBox<ReadingSession>('reading_sessions');
          _boxCompleter.complete(box);
        } catch (retryError) {
          debugPrint('❌ Failed to reopen box: $retryError');
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }

  Future<void> startSession({required int page, int? previousPage}) async {
    if (_activeSession != null) {
      _activeSession = null;
    }
    final now = DateTime.now();
    _activeSession = ReadingSession(
      page: page,
      openedAt: now,
      closedAt: now, // Placeholder
      previousPage: previousPage,
      date: DateTime(now.year, now.month, now.day),
    );
    debugPrint('DEBUG_SESSION: Sesi dimulai untuk halaman $page');
  }

  Future<void> endSession() async {
    debugPrint('DEBUG_SESSION: Mengakhiri sesi membaca...');
    debugPrint(
      'DEBUG_SESSION: Sesi aktif sebelum berakhir: ${_activeSession?.toString() ?? "Tidak ada sesi aktif."}',
    );
    if (_activeSession == null) return;

    try {
      final box = await _box;
      _activeSession = _activeSession!.copyWith(closedAt: DateTime.now());

      debugPrint(
        'DEBUG_SESSION: Sesi aktif setelah diperbarui: ${_activeSession!.toString()}',
      );

      if (_activeSession!.duration.inSeconds > 2) {
        await box.add(_activeSession!);
        debugPrint('DEBUG_SESSION: Sesi ditambahkan ke Hive.');
      } else {
        debugPrint('DEBUG_SESSION: Durasi sesi terlalu pendek, tidak disimpan.');
      }
      _activeSession = null;

      ref.invalidate(dailyReadingDurationsProvider);
      ref.invalidate(allReadingSessionsStreamProvider);
      ref.invalidate(lastReadInfoProvider);
      ref.invalidate(lastReadDisplayDataProvider);
      debugPrint('DEBUG_SESSION: Providers statistik di-invalidate.');
    } catch (e) {
      debugPrint('❌ Error ending session: $e');
    }
  }

  ReadingSession? get activeSession => _activeSession;

  Future<List<ReadingSession>> getAllSessions() async {
    try {
      final box = await _box;
      final sessions = box.values.toList();
      return _sortSessions(sessions);
    } catch (e) {
      debugPrint('❌ Error getting all sessions: $e');
      return [];
    }
  }

  Stream<List<ReadingSession>> getAllSessionsStream() async* {
    try {
      final box = await _box;
      yield _sortSessions(box.values.toList());
      await for (final event in box.watch()) {
        debugPrint(
          'DEBUG_SESSION: Hive box changed. Refreshing sessions stream.',
        );
        yield _sortSessions(box.values.toList());
      }
    } catch (e) {
      debugPrint('❌ Error in sessions stream: $e');
      yield [];
    }
  }

  Future<Map<DateTime, Duration>> getDailyDurations() async {
    try {
      final sessions = await getAllSessions();
      final Map<DateTime, Duration> summary = {};

      for (final session in sessions) {
        final sessionDate = session.date;
        summary.update(
          sessionDate,
          (existing) => existing + session.duration,
          ifAbsent: () => session.duration,
        );
      }
      return summary;
    } catch (e) {
      debugPrint('❌ Error getting daily durations: $e');
      return {};
    }
  }

  List<ReadingSession> _sortSessions(List<ReadingSession> sessions) {
    sessions.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return sessions;
  }

  Future<void> clearAllSessions() async {
    try {
      final box = await _box;
      await box.clear();
      debugPrint('DEBUG_SESSION: Semua sesi dihapus dari Hive.');
      ref.invalidate(dailyReadingDurationsProvider);
      ref.invalidate(allReadingSessionsStreamProvider);
      ref.invalidate(lastReadInfoProvider);
      ref.invalidate(lastReadDisplayDataProvider);
    } catch (e) {
      debugPrint('❌ Error clearing sessions: $e');
    }
  }
}

// === DEFINISI PROVIDER ===

final dailyReadingDurationsProvider = FutureProvider<Map<DateTime, Duration>>((
  ref,
) {
  final recorder = ref.read(readingSessionRecorderProvider.notifier);
  return recorder.getDailyDurations();
});

final allReadingSessionsStreamProvider = StreamProvider<List<ReadingSession>>((
  ref,
) {
  final recorder = ref.read(readingSessionRecorderProvider.notifier);
  return recorder.getAllSessionsStream();
});

final readingSessionsGroupedByDateProvider =
    FutureProvider<Map<DateTime, List<ReadingSession>>>((ref) async {
      final sessions = await ref.watch(allReadingSessionsStreamProvider.future);
      final Map<DateTime, List<ReadingSession>> grouped = {};
      for (final session in sessions) {
        grouped.putIfAbsent(session.date, () => []).add(session);
      }
      return Map.fromEntries(
        grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
      );
    });

// Provider untuk mengambil informasi sesi bacaan terakhir
final lastReadInfoProvider = FutureProvider<ReadingSession?>((ref) async {
  debugPrint(
    'DEBUG_PROVIDER: lastReadInfoProvider: Memulai pengambilan sesi terakhir...',
  );
  final sessions = await ref.watch(allReadingSessionsStreamProvider.future);
  if (sessions.isEmpty) {
    debugPrint(
      'DEBUG_PROVIDER: lastReadInfoProvider: Tidak ada sesi ditemukan.',
    );
    return null;
  }
  debugPrint(
    'DEBUG_PROVIDER: lastReadInfoProvider: Sesi terakhir ditemukan untuk halaman ${sessions.first.page}',
  );
  return sessions.first;
});

// DIUBAH: Derived provider untuk menggabungkan data sesi terakhir dan data chapters
final lastReadDisplayDataProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  debugPrint('DEBUG_PROVIDER: lastReadDisplayDataProvider: Memulai proses.');
  final lastReadSession = await ref.watch(lastReadInfoProvider.future);

  debugPrint(
    'DEBUG_PROVIDER: Last Read Session (dari lastReadInfoProvider): ${lastReadSession?.toString()}',
  );
  if (lastReadSession == null) {
    debugPrint(
      'DEBUG_PROVIDER: lastReadDisplayDataProvider: lastReadSession adalah null, mengembalikan isAvailable: false.',
    );
    return {'isAvailable': false};
  }

  debugPrint(
    'DEBUG_PROVIDER: lastReadDisplayDataProvider: Memanggil getChapterByPage untuk halaman ${lastReadSession.page}',
  );
  
  try {
    final pageInfo = await getChapterByPageNumber(
      pageNumber: lastReadSession.page,
    );

    // Calculate percentage of current page position in surah range
    final currentPage = lastReadSession.page;
    final surahPageRange = pageInfo!.pages; // [startPage, endPage]

    double progressPercentage = 0.0;

    if (surahPageRange.length >= 2) {
      final startPage = surahPageRange[0];
      final endPage = surahPageRange[1];
      final totalPages = endPage - startPage + 1;
      final currentPosition = currentPage - startPage + 1;

      progressPercentage = (currentPosition / totalPages) * 100;

      debugPrint(
        '📊 Page $currentPage in range [$startPage, $endPage]: ${progressPercentage.toStringAsFixed(1)}%',
      );
    } else if (surahPageRange.length == 1) {
      // Single page surah
      progressPercentage = currentPage == surahPageRange[0] ? 100.0 : 0.0;
      debugPrint(
        '📊 Single page surah: ${progressPercentage.toStringAsFixed(1)}%',
      );
    }

    debugPrint(progressPercentage.toString());

    return {
      'isAvailable': true,
      'session': lastReadSession,
      'surahName': pageInfo.nameSimple,
      'progressPercentage': progressPercentage,
    };
  } catch (e) {
    debugPrint('❌ Error in lastReadDisplayDataProvider: $e');
    return {'isAvailable': false, 'error': e.toString()};
  }
});