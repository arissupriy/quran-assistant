import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:quran_assistant/core/models/reading_session.dart';

final readingSessionRecorderProvider =
    NotifierProvider<ReadingSessionRecorder, void>(ReadingSessionRecorder.new);

class ReadingSessionRecorder extends Notifier<void> {
  Box<ReadingSession>? _box;
  ReadingSession? _activeSession;

  @override
  void build() {
    // Tidak ada state yang dipantau
  }

  Future<void> _initBox() async {
    _box ??= await Hive.openBox<ReadingSession>('reading_sessions');
  }

  Future<void> startSession({required int page, int? previousPage}) async {
    await _initBox();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _activeSession = ReadingSession(
      page: page,
      openedAt: now,
      closedAt: now, // placeholder, akan diperbarui saat endSession
      previousPage: previousPage,
      date: today,
    );
  }

  Future<void> endSession() async {
    if (_activeSession == null) return;
    await _initBox();

    final now = DateTime.now();
    _activeSession = _activeSession!.copyWith(closedAt: now);

    await _box?.add(_activeSession!);
    _activeSession = null;
  }

  ReadingSession? get activeSession => _activeSession;

  Future<List<ReadingSession>> getAllSessions() async {
    await _initBox();
    return _box?.values.toList() ?? [];
  }

  Future<List<ReadingSession>> getSessionsForDate(DateTime date) async {
    await _initBox();
    final onlyDate = DateTime(date.year, date.month, date.day);
    return _box?.values.where((s) => s.date == onlyDate).toList() ?? [];
  }

  Future<Duration> getDurationForDate(DateTime date) async {
    final sessions = await getSessionsForDate(date);
    return sessions.fold<Duration>(
      Duration.zero,
      (prev, s) => prev + s.duration,
    );
  }

  Future<Map<DateTime, Duration>> getDailyDurations() async {
    await _initBox();

    final sessions = _box?.values.toList() ?? [];
    final Map<DateTime, Duration> summary = {};

    for (final session in sessions) {
      summary.update(
        session.date,
        (existing) => existing + session.duration,
        ifAbsent: () => session.duration,
      );
    }

    return summary;
  }

  Future<void> clearAllSessions() async {
    await _initBox();
    await _box?.clear();
  }
}


final readingSessionsGroupedByDateProvider =
    FutureProvider<Map<DateTime, List<ReadingSession>>>((ref) async {
  final recorder = ref.read(readingSessionRecorderProvider.notifier);
  final sessions = await recorder.getAllSessions();

  final Map<DateTime, List<ReadingSession>> grouped = {};
  for (final session in sessions) {
    grouped.putIfAbsent(session.date, () => []).add(session);
  }

  final sorted = Map.fromEntries(
    grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)), // Descending by date
  );

  return sorted;
});