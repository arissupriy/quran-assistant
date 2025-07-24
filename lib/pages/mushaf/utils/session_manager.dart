// lib/pages/mushaf/utils/session_manager.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart';

class SessionManager {
  static const Duration _sessionDebounceDelay = Duration(milliseconds: 700);
  static const Duration _sessionTransitionDelay = Duration(milliseconds: 100);

  Timer? _sessionDebounceTimer;
  Timer? _sessionTransitionTimer;
  Completer<void>? _activeSessionTransition;
  int? _currentSessionPage;
  bool _isTransitioning = false;

  Future<void> handlePageChange({
    required WidgetRef ref,
    required int newPage,
    required int? previousPage,
  }) async {
    _sessionDebounceTimer?.cancel();
    _sessionTransitionTimer?.cancel();

    if (_activeSessionTransition != null && !_activeSessionTransition!.isCompleted) {
      await _activeSessionTransition!.future;
    }

    _sessionDebounceTimer = Timer(_sessionDebounceDelay, () {
      _executeSessionTransition(ref, newPage, previousPage);
    });
  }

  Future<void> _executeSessionTransition(
    WidgetRef ref,
    int newPage,
    int? previousPage,
  ) async {
    if (_isTransitioning) return;

    _isTransitioning = true;
    _activeSessionTransition = Completer<void>();

    try {
      if (_currentSessionPage != null) {
        await _endSession(ref);
      }

      await Future.delayed(_sessionTransitionDelay);
      await _startSession(ref, newPage, previousPage);
      _currentSessionPage = newPage;
    } catch (_) {} finally {
      _isTransitioning = false;
      _activeSessionTransition?.complete();
      _activeSessionTransition = null;
    }
  }

  Future<void> _startSession(WidgetRef ref, int page, int? previousPage) async {
    await ref.read(readingSessionRecorderProvider.notifier).startSession(page: page, previousPage: previousPage);
  }

  Future<void> _endSession(WidgetRef ref) async {
    await ref.read(readingSessionRecorderProvider.notifier).endSession();
  }

  Future<void> forceEndSession(WidgetRef ref) async {
    _sessionDebounceTimer?.cancel();
    _sessionTransitionTimer?.cancel();
    if (_currentSessionPage != null) {
      await _endSession(ref);
      _currentSessionPage = null;
    }
  }

  void dispose() {
    _sessionDebounceTimer?.cancel();
    _sessionTransitionTimer?.cancel();
  }
}


class AyahTapInfo {
  final int sura;
  final int ayah;
  final Offset globalPosition;

  AyahTapInfo({
    required this.sura,
    required this.ayah,
    required this.globalPosition,
  });
}