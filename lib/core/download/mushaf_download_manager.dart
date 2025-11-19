import 'dart:async';
import 'dart:isolate';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/download_progress_provider.dart';
import 'mushaf_download_preferences.dart';

const _downloadPortName = 'mushaf_download_port';
const _taskIdKey = 'mushaf_download_task_id';
const _filePathKey = 'mushaf_download_target_path';

@pragma('vm:entry-point')
void mushafDownloadBackgroundCallback(
  String id,
  int status,
  int progress,
) {
  final SendPort? send = IsolateNameServer.lookupPortByName(_downloadPortName);
  send?.send([id, status, progress]);
}

class MushafDownloadManager {
  MushafDownloadManager(this._ref) {
    _bindBackgroundIsolate();
    Future.microtask(_restoreExistingTask);
  }

  final Ref _ref;
  final ReceivePort _port = ReceivePort();
  StreamSubscription<dynamic>? _portSubscription;
  String? _activeTaskId;
  String? _targetFilePath;

  bool get hasActiveTask => _activeTaskId != null;

  Future<void> startDownload({
    required String url,
    required String savePath,
    int? initialPage,
  }) async {
    if (_activeTaskId != null) {
      if (kDebugMode) {
        debugPrint('[MushafDownloadManager] Download already running ($_activeTaskId)');
      }
      _ref
          .read(downloadProgressProvider.notifier)
          .setMessage('Melanjutkan unduhan di latar belakang...');
      return;
    }

    final file = File(savePath);
    if (await file.exists()) {
      await file.delete();
    }

    final directory = Directory(p.dirname(savePath));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    try {
      final taskId = await FlutterDownloader.enqueue(
        url: url,
        savedDir: directory.path,
        fileName: p.basename(savePath),
        showNotification: true,
        openFileFromNotification: false,
        saveInPublicStorage: false,
        requiresStorageNotLow: true,
        notificationTitle: 'Sedang mengunduh data mushaf',
        tapToOpenApp: true,
      );

      if (taskId == null) {
        throw Exception('Gagal membuat tugas unduhan');
      }

      _activeTaskId = taskId;
      _targetFilePath = savePath;
      await _persistTaskInfo();
  await MushafDownloadPreferences.setInitialPage(initialPage);
      _ref.read(downloadProgressProvider.notifier).setDownloading(0);
    } catch (e) {
      _ref.read(downloadProgressProvider.notifier).setError('Gagal memulai download: $e');
      rethrow;
    }
  }

  Future<void> cancelDownload() async {
    if (_activeTaskId == null) return;
    try {
      await FlutterDownloader.cancel(taskId: _activeTaskId!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MushafDownloadManager] Failed to cancel: $e');
      }
    } finally {
      if (_targetFilePath != null) {
        final partial = File(_targetFilePath!);
        if (await partial.exists()) {
          await partial.delete();
        }
      }
      _ref.read(downloadProgressProvider.notifier).setCanceled();
      await _clearPersistedTask();
      await MushafDownloadPreferences.clearInitialPage();
    }
  }

  void dispose() {
    _portSubscription?.cancel();
    _port.close();
    final existing = IsolateNameServer.lookupPortByName(_downloadPortName);
    if (existing != null) {
      IsolateNameServer.removePortNameMapping(_downloadPortName);
    }
  }

  void _bindBackgroundIsolate() {
    final existing = IsolateNameServer.lookupPortByName(_downloadPortName);
    if (existing != null) {
      IsolateNameServer.removePortNameMapping(_downloadPortName);
    }

    IsolateNameServer.registerPortWithName(_port.sendPort, _downloadPortName);
    _portSubscription = _port.listen(_handleBackgroundEvent);
  }

  void _handleBackgroundEvent(dynamic data) {
    if (data is! List || data.length < 3) return;
    final taskId = data[0] as String?;
  final statusValue = data[1] as int?;
    final progressValue = data[2] as int?;

    if (taskId == null || statusValue == null || progressValue == null) {
      return;
    }

    if (_activeTaskId != null && taskId != _activeTaskId) {
      return;
    }

    final status = DownloadTaskStatus.fromInt(statusValue);
    _ref.read(downloadProgressProvider.notifier).updateFromDownloader(status, progressValue);

    if (status == DownloadTaskStatus.complete) {
      _finalizeSuccessfulDownload();
    } else if (status == DownloadTaskStatus.failed || status == DownloadTaskStatus.canceled) {
      _clearPersistedTask();
    }
  }

  Future<void> _restoreExistingTask() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTaskId = prefs.getString(_taskIdKey);
    _targetFilePath = prefs.getString(_filePathKey);

    if (storedTaskId == null) {
      return;
    }

    final tasks = await FlutterDownloader.loadTasks();
    final task = _findTaskById(tasks, storedTaskId);

    if (task == null) {
      await _clearPersistedTask();
      return;
    }

    _activeTaskId = storedTaskId;
    _ref.read(downloadProgressProvider.notifier).updateFromDownloader(task.status, task.progress);

    if (task.status == DownloadTaskStatus.complete) {
      _finalizeSuccessfulDownload();
    }
  }

  Future<void> _persistTaskInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (_activeTaskId != null) {
      await prefs.setString(_taskIdKey, _activeTaskId!);
    }
    if (_targetFilePath != null) {
      await prefs.setString(_filePathKey, _targetFilePath!);
    }
  }

  Future<void> _clearPersistedTask() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_taskIdKey);
    await prefs.remove(_filePathKey);
    _activeTaskId = null;
    _targetFilePath = null;
  }

  Future<void> _finalizeSuccessfulDownload() async {
    final filePath = _targetFilePath;
    if (filePath != null) {
      final file = File(filePath);
      if (!await file.exists()) {
        // Jika file disimpan di lokasi sementara oleh plugin, cari dan pindahkan.
        final parent = Directory(p.dirname(filePath));
        final candidate = File(p.join(parent.path, p.basename(filePath)));
        if (await candidate.exists()) {
          await candidate.rename(filePath);
        }
      }
    }

    await _clearPersistedTask();
  }
}

DownloadTask? _findTaskById(List<DownloadTask>? tasks, String taskId) {
  if (tasks == null) return null;
  for (final task in tasks) {
    if (task.taskId == taskId) {
      return task;
    }
  }
  return null;
}

final mushafDownloadManagerProvider = Provider<MushafDownloadManager>((ref) {
  final manager = MushafDownloadManager(ref);
  ref.onDispose(manager.dispose);
  return manager;
});
