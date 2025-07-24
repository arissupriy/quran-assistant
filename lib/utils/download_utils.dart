// // // lib/pages/mushaf_download_page.dart

// // import 'dart:io';
// // import 'package:dio/dio.dart';
// // import 'package:flutter/foundation.dart';
// // import 'package:flutter/material.dart';
// // import 'package:quran_assistant/core/api/ffi.dart';
// // import 'package:quran_assistant/pages/quran_detail_page.dart';
// // import 'package:quran_assistant/utils/mushaf_utils.dart';

// // class MushafDownloadPage extends StatefulWidget {
// //   final int?
// //   initialPage; // Parameter: Halaman awal yang akan ditampilkan setelah unduhan
// //   const MushafDownloadPage({super.key, this.initialPage});

// //   @override
// //   State<MushafDownloadPage> createState() => _MushafDownloadPageState();
// // }

// // class _MushafDownloadPageState extends State<MushafDownloadPage> {
// //   @override
// //   void initState() {
// //     super.initState();
// //     // Memulai proses pengecekan setelah frame pertama selesai dibangun
// //     WidgetsBinding.instance.addPostFrameCallback(
// //       (_) => _checkAndProcessMushaf(),
// //     );
// //   }

// //   /// Fungsi utama yang mengatur seluruh logika
// //   Future<void> _checkAndProcessMushaf() async {
// //     // Panggil utility untuk mendapatkan semua informasi yang kita butuhkan
// //     final status = await MushafUtils.checkMushafStatus(
// //       MediaQuery.of(context).size.width,
// //     );

// //     if (status.isDownloaded) {
// //       // Jika sudah ada, langsung navigasi ke QuranPerPage
// //       // Meneruskan initialPage yang diterima dari halaman sebelumnya
// //       _navigateToQuran(status.variant, widget.initialPage);
// //     } else {
// //       // Jika belum ada, mulai proses download menggunakan info dari status
// //       await _startDownloadAndDecompress(
// //         url: status.downloadUrl,
// //         savePath: status.archivePath,
// //         outputDir: status.outputPath,
// //       );
// //     }
// //   }

// //   /// Menangani proses download (dengan dialog progres) dan dekompresi
// //   Future<void> _startDownloadAndDecompress({
// //     required String url,
// //     required String savePath,
// //     required String outputDir,
// //   }) async {
// //     // Pindahkan deklarasi progress dan statusMessage ke dalam scope builder
// //     // agar dapat diakses dan diupdate oleh setState() dari StatefulBuilder.
// //     double? dialogProgress = 0.0;
// //     String dialogStatusMessage = "Mengunduh file mushaf...";

// //     late StateSetter setDialogState; // Deklarasikan StateSetter

// //     // Tampilkan dialog yang tidak bisa ditutup
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (dialogContext) {
// //         // Ganti nama parameter context menjadi dialogContext
// //         return StatefulBuilder(
// //           // StatefulBuilder digunakan untuk mengelola state di dalam dialog
// //           builder: (context, setInnerState) {
// //             // setInnerState adalah setState() khusus untuk builder ini
// //             setDialogState = setInnerState; // Simpan reference setInnerState
// //             return AlertDialog(
// //               title: const Text('Mempersiapkan Data'),
// //               content: Column(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   Text(dialogStatusMessage), // Gunakan _dialogStatusMessage
// //                   const SizedBox(height: 16),
// //                   LinearProgressIndicator(
// //                     value: dialogProgress,
// //                   ), // Gunakan _dialogProgress
// //                   const SizedBox(height: 8),
// //                   Text(
// //                     dialogProgress != null
// //                         ? '${(dialogProgress! * 100).toStringAsFixed(1)}%'
// //                         : 'Mohon tunggu...',
// //                   ),
// //                 ],
// //               ),
// //             );
// //           },
// //         );
// //       },
// //     );

// //     try {
// //       // --- TAHAP DOWNLOAD ---
// //       final dio = Dio();
// //       await dio.download(
// //         url,
// //         savePath,
// //         onReceiveProgress: (received, total) {
// //           if (total != -1 && mounted) {
// //             // Panggil _setDialogState untuk memperbarui UI dialog
// //             setDialogState(() {
// //               dialogProgress = received / total;
// //             });
// //           }
// //         },
// //         options: Options(
// //           // Pastikan options ini ada jika Anda memilikinya di downloadWithDio
// //           responseType: ResponseType.bytes,
// //           followRedirects: false,
// //           receiveTimeout: const Duration(minutes: 5),
// //         ),
// //       );

// //       // --- TAHAP DEKOMPRESI ---
// //       if (mounted) {
// //         // Update status di dialog melalui _setDialogState
// //         setDialogState(() {
// //           dialogStatusMessage = "Mengekstrak file...";
// //           dialogProgress = null; // Buat progress bar menjadi indeterminate
// //         });
// //       }

// //       debugPrint("Download selesai. Memulai dekompresi...");
// //       // Menjalankan FFI di background thread agar UI tidak freeze
// //       await compute(_decompressInIsolate, {
// //         'input': savePath,
// //         'output': outputDir,
// //       });
// //       debugPrint("Dekompresi selesai.");

// //       // Hapus file archive setelah berhasil didekompresi untuk menghemat ruang
// //       await File(savePath).delete();

// //       // Jika semua berhasil, tutup dialog dan navigasi
// //       if (mounted) {
// //         Navigator.pop(context); // Tutup dialog
// //         // Navigasi ke QuranPerPage dengan initialPage yang diterima oleh MushafDownloadPage
// //         _navigateToQuran(outputDir.split('/').last, widget.initialPage);
// //       }
// //     } catch (e) {
// //       debugPrint("Terjadi error: $e");
// //       if (mounted) {
// //         Navigator.pop(context); // Tutup dialog jika error
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(SnackBar(content: Text('Gagal mempersiapkan data: $e')));
// //       }
// //     }
// //   }

// //   /// Navigasi ke halaman Quran setelah proses selesai
// //   /// Menerima parameter targetPage untuk mengatur halaman awal PageView
// //   void _navigateToQuran(String resolution, int? targetPage) {
// //     Navigator.pushReplacement(
// //       context,
// //       MaterialPageRoute(
// //         builder: (_) => QuranPerPage(
// //           resolution: resolution,
// //           initialPage: targetPage, // Teruskan initialPage
// //         ),
// //       ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     // Tampilan loading awal sebelum logika pengecekan selesai
// //     return const Scaffold(
// //       body: Center(
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             CircularProgressIndicator(),
// //             SizedBox(height: 16),
// //             Text("Memeriksa data mushaf..."),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// Fungsi top-level untuk menjalankan dekompresi di isolate terpisah
// Future<void> _decompressInIsolate(Map<String, String> paths) async {
//   // Pastikan path tidak null
//   final inputPath = paths['input']!;
//   final outputPath = paths['output']!;
//   // Memanggil fungsi dekompresi dari Rust FFI
//   decompressFile(inputPath, outputPath);
// }
