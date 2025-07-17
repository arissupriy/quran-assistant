import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:quran_assistant/core/models/reading_session.dart';

// Provider tidak berubah, tetap menggunakan NotifierProvider
final readingSessionRecorderProvider =
    NotifierProvider<ReadingSessionRecorder, void>(
  ReadingSessionRecorder.new,
);

class ReadingSessionRecorder extends Notifier<void> {
  // BARU: Gunakan Completer untuk memastikan box hanya diinisialisasi sekali.
  // Ini adalah pola yang umum untuk menangani inisialisasi asinkron dalam sebuah kelas.
  final _boxCompleter = Completer<Box<ReadingSession>>();

  // BARU: Getter privat untuk mendapatkan box yang sudah diinisialisasi.
  // Semua metode lain akan menggunakan `await _box` untuk memastikan box siap.
  Future<Box<ReadingSession>> get _box => _boxCompleter.future;

  ReadingSession? _activeSession;

  @override
  void build() {
    // BARU: Tambahkan baris ini di paling atas.
    ref.keepAlive();

    _initBox();

    ref.onDispose(() {
      debugPrint('🧼 Provider disposed, mengakhiri sesi aktif jika ada...');
      // Walaupun ada keepAlive, onDispose tetap berguna jika Anda
      // me-refresh provider secara manual.
      endSession();
    });
  }

  // DIUBAH: Metode inisialisasi sekarang hanya dipanggil sekali dari `build`.
  Future<void> _initBox() async {
    // Hindari membuka box yang sudah dalam proses pembukaan.
    if (_boxCompleter.isCompleted) return;
    
    final box = await Hive.openBox<ReadingSession>('reading_sessions');
    _boxCompleter.complete(box);
  }

  Future<void> startSession({required int page, int? previousPage}) async {

    // debugPrint(_activeSession.toString());
    // Pastikan tidak ada sesi yang sudah aktif
    if (_activeSession != null) {
      // Mungkin akhiri sesi sebelumnya atau lempar error
      // await endSession();
      _activeSession = null; // Reset sesi aktif jika ada
    }
    
    final now = DateTime.now();
    _activeSession = ReadingSession(
      page: page,
      openedAt: now,
      closedAt: now, // Placeholder
      previousPage: previousPage,
      date: DateTime(now.year, now.month, now.day),
    );
    debugPrint('Sesi dimulai untuk halaman $page');
  }

  Future<void> endSession() async {
    debugPrint('Mengakhiri sesi membaca...');

    debugPrint(_activeSession?.toString() ?? 'Tidak ada sesi aktif.');
    if (_activeSession == null) return;

    final box = await _box;
    _activeSession = _activeSession!.copyWith(closedAt: DateTime.now());


    debugPrint(_activeSession!.toString());

    if (_activeSession!.duration.inSeconds > 2) {
      await box.add(_activeSession!);
    }
    _activeSession = null;

    // Panggilan ini sekarang akan selalu aman karena provider tidak akan di-dispose.
    ref.invalidate(dailyReadingDurationsProvider);
    ref.invalidate(allReadingSessionsStreamProvider);

    debugPrint('Providers statistik di-invalidate.');
  }
  
  ReadingSession? get activeSession => _activeSession;

  Future<List<ReadingSession>> getAllSessions() async {
    final box = await _box; // DIUBAH: Gunakan getter
    final sessions = box.values.toList();
    // DIUBAH: Ekstrak logika sorting ke fungsi helper untuk reusabilitas
    return _sortSessions(sessions);
  }

  // DIUBAH: Implementasi stream yang jauh lebih sederhana menggunakan box.watch()
  Stream<List<ReadingSession>> getAllSessionsStream() async* {
    final box = await _box;
    // 1. Langsung emit data awal
    yield _sortSessions(box.values.toList());

    // 2. Dengarkan perubahan pada box dan emit data baru setiap ada perubahan
    await for (final event in box.watch()) {
      yield _sortSessions(box.values.toList());
    }
  }

  Future<Map<DateTime, Duration>> getDailyDurations() async {
    final sessions = await getAllSessions(); // Ini sudah menggunakan box yang diinisialisasi
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
  }
  
  // BARU: Fungsi helper untuk menghindari duplikasi kode sorting
  List<ReadingSession> _sortSessions(List<ReadingSession> sessions) {
    sessions.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return sessions;
  }

  Future<void> clearAllSessions() async {
    final box = await _box; // DIUBAH: Gunakan getter
    await box.clear();
    // Invalidate provider setelah data dibersihkan
    ref.invalidate(dailyReadingDurationsProvider);
    ref.invalidate(allReadingSessionsStreamProvider);
  }
}

// === DEFINISI PROVIDER (Disederhanakan) ===

// Provider ini tetap sama, mengambil data durasi harian.
final dailyReadingDurationsProvider = FutureProvider<Map<DateTime, Duration>>((ref) {
  // DIUBAH: Gunakan watch jika Anda ingin provider ini otomatis refresh jika dependensinya berubah.
  // Tapi dalam kasus ini, `read` sudah cukup karena kita me-refresh-nya secara manual dengan `invalidate`.
  final recorder = ref.read(readingSessionRecorderProvider.notifier);
  return recorder.getDailyDurations();
});

// Provider ini menjadi lebih sederhana.
final allReadingSessionsStreamProvider = StreamProvider<List<ReadingSession>>((ref) {
  final recorder = ref.read(readingSessionRecorderProvider.notifier);
  // Langsung kembalikan stream dari recorder. Riverpod akan menanganinya.
  return recorder.getAllSessionsStream();
});


// Provider ini mungkin tidak lagi diperlukan jika Anda memproses data stream secara langsung di UI.
// Namun jika tetap dibutuhkan, implementasinya sudah benar.
final readingSessionsGroupedByDateProvider =
    FutureProvider<Map<DateTime, List<ReadingSession>>>((ref) async {
  // Anda bisa memilih untuk menggunakan stream atau future.
  // Menggunakan stream akan lebih reaktif.
  final sessions = await ref.watch(allReadingSessionsStreamProvider.future);

  final Map<DateTime, List<ReadingSession>> grouped = {};
  for (final session in sessions) {
    grouped.putIfAbsent(session.date, () => []).add(session);
  }

  // Sorting map berdasarkan key (tanggal)
  return Map.fromEntries(
    grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)), // Descending by date
  );
});