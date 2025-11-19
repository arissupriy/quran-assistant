// lib/providers/download_progress_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

// Enum untuk merepresentasikan status unduhan
enum DownloadStatus {
  initial,
  checking,
  downloading,
  decompressing,
  completed,
  error,
  canceled,
}

// Model untuk menampung state progres unduhan
class DownloadProgressState {
  final DownloadStatus status;
  final double? progress; // null jika indeterminate
  final String message;
  final String? errorMessage; // Untuk menyimpan pesan error

  DownloadProgressState({
    this.status = DownloadStatus.initial,
    this.progress,
    this.message = '',
    this.errorMessage,
  });

  // Fungsi copyWith untuk memudahkan update state
  DownloadProgressState copyWith({
    DownloadStatus? status,
    double? progress,
    String? message,
    String? errorMessage,
  }) {
    return DownloadProgressState(
      status: status ?? this.status,
      progress:
          progress, // Ini penting: jika progress = null, harus tetap null.
      // Jangan gunakan '?? this.progress' di sini
      message: message ?? this.message,
      errorMessage:
          errorMessage, // Jika errorMessage diset null, maka akan dihapus.
    );
  }
}

// StateNotifier untuk mengelola state progres unduhan
class DownloadProgressNotifier extends StateNotifier<DownloadProgressState> {
  DownloadProgressNotifier() : super(DownloadProgressState()); // Initial state

  void setChecking() {
    state = state.copyWith(
      status: DownloadStatus.checking,
      message: "Memeriksa data mushaf...",
      progress: 0.0,
    );
  }

  void setDownloading(double? currentProgress) {
    state = state.copyWith(
      status: DownloadStatus.downloading,
      progress: currentProgress,
      message: "Mengunduh file mushaf...",
    );
  }

  void setDecompressing() {
    state = state.copyWith(
      status: DownloadStatus.decompressing,
      progress: null,
      message: "Mengekstrak file...",
    );
  }

  void setCompleted() {
    state = state.copyWith(
      status: DownloadStatus.completed,
      message: "Data siap!",
    );
  }

  void setCanceled() {
    state = state.copyWith(
      status: DownloadStatus.canceled,
      progress: null,
      message: "Download dibatalkan.",
      errorMessage: null,
    );
  }

  void setError(String message) {
    state = state.copyWith(
      status: DownloadStatus.error,
      errorMessage: message,
      message: "Gagal mempersiapkan data.",
    );
  }

  void setMessage(String message) {
    state = state.copyWith(message: message);
  }

  void updateFromDownloader(DownloadTaskStatus status, int progressValue) {
    switch (status) {
      case DownloadTaskStatus.enqueued:
        setChecking();
        break;
      case DownloadTaskStatus.running:
        final progress = progressValue >= 0 ? progressValue / 100 : null;
        setDownloading(progress);
        break;
      case DownloadTaskStatus.paused:
        state = state.copyWith(
          status: DownloadStatus.downloading,
          progress: progressValue >= 0 ? progressValue / 100 : state.progress,
          message: "Download dijeda",
        );
        break;
      case DownloadTaskStatus.complete:
        setCompleted();
        break;
      case DownloadTaskStatus.canceled:
        setCanceled();
        break;
      case DownloadTaskStatus.failed:
        setError('Download gagal. Coba lagi.');
        break;
      case DownloadTaskStatus.undefined:
        break;
    }
  }

  // Metode untuk mereset state (misalnya jika ingin mengulang unduhan)
  void reset() {
    state = DownloadProgressState();
  }
}

// Provider global untuk mengakses DownloadProgressNotifier
final downloadProgressProvider =
    StateNotifierProvider<DownloadProgressNotifier, DownloadProgressState>((
      ref,
    ) {
      return DownloadProgressNotifier();
    });
