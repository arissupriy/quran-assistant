import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// Fungsi downloadWithDio Anda tetap sama, tidak perlu diubah.
Future<void> downloadWithDio({
  required String url,
  required String filename,
  required void Function(double) onProgress,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final savePath = '${dir.path}/$filename';

  final dio = Dio();
  await dio.download(
    url,
    savePath,
    onReceiveProgress: (received, total) {
      if (total != -1) {
        double progress = received / total;
        onProgress(progress);
      }
    },
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: false,
      receiveTimeout: const Duration(minutes: 5),
    ),
  );
}

// ===================================================================
// PERUBAIKAN UTAMA ADA DI SINI
// ===================================================================

/// Fungsi `startDownload` sekarang hanya menampilkan dialog.
/// Logika utamanya dipindahkan ke Widget di bawah.
void startDownload(
  BuildContext context, {
  required String url,
  required String filename,
  required VoidCallback onSuccess,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    // Kita tidak lagi menggunakan StatefulBuilder, tapi widget khusus.
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Mengunduh Mushaf...'),
        // Konten dialog sekarang adalah StatefulWidget tersendiri.
        content: _DownloadDialogContent(
          url: url,
          filename: filename,
          onSuccess: () {
            // Tutup dialog dari sini setelah sukses
            Navigator.pop(dialogContext);
            onSuccess();
          },
          onError: (e) {
            Navigator.pop(dialogContext);
            debugPrint('Download failed: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal mengunduh: $e')),
            );
          },
        ),
      );
    },
  );
}

/// Widget khusus untuk menangani state dan UI dari konten dialog.
class _DownloadDialogContent extends StatefulWidget {
  final String url;
  final String filename;
  final VoidCallback onSuccess;
  final Function(Object) onError;

  const _DownloadDialogContent({
    required this.url,
    required this.filename,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_DownloadDialogContent> createState() => _DownloadDialogContentState();
}

class _DownloadDialogContentState extends State<_DownloadDialogContent> {
  // Variabel progress sekarang menjadi state dari widget ini.
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    // Memulai proses download HANYA SATU KALI di initState.
    _startDownloading();
  }

  void _startDownloading() {
    downloadWithDio(
      url: widget.url,
      filename: widget.filename,
      onProgress: (p) {
        // Cukup panggil setState untuk update UI.
        setState(() {
          _progress = p;
        });
      },
    ).then((_) {
      // Jika berhasil, panggil callback onSuccess.
      widget.onSuccess();
    }).catchError((e) {
      // Jika gagal, panggil callback onError.
      widget.onError(e);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Metode build sekarang hanya fokus untuk menampilkan UI.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),
        Text('${(_progress * 100).toStringAsFixed(1)}%'),
      ],
    );
  }
}