// // lib/pages/mushaf_download_page.dart

// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:quran_assistant/core/api/ffi.dart';
// import 'package:quran_assistant/pages/quran_detail_page.dart';
// import 'package:quran_assistant/utils/mushaf_utils.dart';
// import 'package:quran_assistant/providers/download_progress_provider.dart';
// import 'package:google_fonts/google_fonts.dart';

// class MushafDownloadPage extends ConsumerStatefulWidget {
//   final int? initialPage;
//   const MushafDownloadPage({super.key, this.initialPage});

//   @override
//   ConsumerState<MushafDownloadPage> createState() => _MushafDownloadPageState();
// }

// class _MushafDownloadPageState extends ConsumerState<MushafDownloadPage> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback(
//       (_) => _checkAndProcessMushaf(),
//     );
//   }

//   // Method untuk memulai ulang proses unduhan dari awal
//   void _retryDownload() {
//     ref.read(downloadProgressProvider.notifier).reset(); // Reset state Riverpod
//     _checkAndProcessMushaf(); // Mulai ulang proses
//   }

//   Future<void> _checkAndProcessMushaf() async {
//     final notifier = ref.read(downloadProgressProvider.notifier);
//     notifier.setChecking();

//     try {
//       final status = await MushafUtils.checkMushafStatus(
//         MediaQuery.of(context).size.width,
//       );

//       if (status.isDownloaded) {
//         notifier.setCompleted();
//         await Future.delayed(const Duration(milliseconds: 800));
//         _navigateToQuran(status.variant, widget.initialPage);
//       } else {
//         await _startDownloadAndDecompress(
//           url: status.downloadUrl,
//           savePath: status.archivePath,
//           outputDir: status.outputPath,
//         );
//       }
//     } catch (e) {
//       debugPrint("Terjadi error saat check status: $e");
//       notifier.setError(
//         'Gagal memeriksa data: ${e.toString()}',
//       ); // Pastikan error message diubah ke String
//     }
//   }

//   Future<void> _startDownloadAndDecompress({
//     required String url,
//     required String savePath,
//     required String outputDir,
//   }) async {
//     final notifier = ref.read(downloadProgressProvider.notifier);

//     try {
//       notifier.setDownloading(0.0);
//       final dio = Dio();
//       await dio.download(
//         url,
//         savePath,
//         onReceiveProgress: (received, total) {
//           if (mounted) {
//             if (total != -1) {
//               notifier.setDownloading(received / total);
//             } else {
//               notifier.setDownloading(0.0);
//             }
//           }
//         },
//         options: Options(
//           responseType: ResponseType.bytes,
//           followRedirects: false,
//           receiveTimeout: const Duration(minutes: 5),
//         ),
//       );

//       notifier.setDecompressing();
//       debugPrint("Download selesai. Memulai dekompresi...");
//       await compute(_decompressInIsolate, {
//         'input': savePath,
//         'output': outputDir,
//       });
//       debugPrint("Dekompresi selesai.");

//       await File(savePath).delete();

//       if (mounted) {
//         notifier.setCompleted();
//         await Future.delayed(const Duration(milliseconds: 800));
//         _navigateToQuran(outputDir.split('/').last, widget.initialPage);
//       }
//     } catch (e) {
//       debugPrint("Terjadi error: $e");
//       if (mounted) {
//         notifier.setError(
//           'Gagal mengunduh atau mengekstrak data: ${e.toString()}',
//         ); // Pastikan error message diubah ke String
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Gagal mempersiapkan data: ${e.toString()}')),
//         );
//       }
//     }
//   }

//   void _navigateToQuran(String resolution, int? targetPage) {
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (_) =>
//             QuranPerPage(resolution: resolution, initialPage: targetPage),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final downloadState = ref.watch(downloadProgressProvider);

//     return Scaffold(
//       backgroundColor: Colors.teal[50],
//       body: SafeArea(
//         child: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Text(
//                   'Mempersiapkan Mushaf Digital',
//                   style: GoogleFonts.poppins(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.teal[800],
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//                 const SizedBox(height: 40),

//                 _buildStatusIndicator(downloadState),

//                 const SizedBox(height: 30),

//                 Text(
//                   downloadState.message.isNotEmpty
//                       ? downloadState.message
//                       : (downloadState.status == DownloadStatus.initial
//                             ? "Memulai proses..."
//                             : "Memeriksa data mushaf..."), // Pesan default yang lebih jelas
//                   style: GoogleFonts.roboto(
//                     fontSize: 18,
//                     color: Colors.teal[700],
//                   ),
//                   textAlign: TextAlign.center,
//                 ),

//                 const SizedBox(height: 20),

//                 if (downloadState.status == DownloadStatus.downloading ||
//                     downloadState.status == DownloadStatus.decompressing)
//                   Column(
//                     children: [
//                       LinearProgressIndicator(
//                         value: downloadState.progress,
//                         backgroundColor: Colors.teal[100],
//                         valueColor: const AlwaysStoppedAnimation<Color>(
//                           Colors.teal,
//                         ),
//                         minHeight: 8,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       const SizedBox(height: 10),
//                       Text(
//                         downloadState.progress != null
//                             ? '${(downloadState.progress! * 100).toStringAsFixed(1)}%'
//                             : 'Mohon tunggu...',
//                         style: GoogleFonts.roboto(
//                           fontSize: 16,
//                           color: Colors.teal[600],
//                         ),
//                       ),
//                     ],
//                   ),

//                 if (downloadState.errorMessage != null)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 20),
//                     child: Text(
//                       downloadState.errorMessage!,
//                       style: GoogleFonts.roboto(
//                         color: Colors.red[700],
//                         fontSize: 15,
//                         fontWeight: FontWeight.w500,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),

//                 // Tombol "Download Ulang" jika terjadi error
//                 if (downloadState.status == DownloadStatus.error)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 30),
//                     child: ElevatedButton.icon(
//                       onPressed: _retryDownload, // Panggil fungsi retry
//                       icon: const Icon(Icons.refresh_rounded),
//                       label: const Text('Download Ulang'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor:
//                             Colors.red, // Warna tombol merah untuk error
//                         foregroundColor: Colors.white,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 24,
//                           vertical: 12,
//                         ),
//                         textStyle: GoogleFonts.roboto(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusIndicator(DownloadProgressState state) {
//     switch (state.status) {
//       case DownloadStatus.initial:
//       case DownloadStatus.checking:
//         return Column(
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               'Memeriksa...',
//               style: GoogleFonts.roboto(color: Colors.teal[600]),
//             ),
//           ],
//         );
//       case DownloadStatus.downloading:
//         return Icon(Icons.cloud_download_rounded, size: 80, color: Colors.teal);
//       case DownloadStatus.decompressing:
//         return Icon(Icons.archive_rounded, size: 80, color: Colors.teal);
//       case DownloadStatus.completed:
//         return Icon(Icons.check_circle_rounded, size: 80, color: Colors.green);
//       case DownloadStatus.error:
//         return Icon(Icons.error_outline_rounded, size: 80, color: Colors.red);
//       default:
//         return const CircularProgressIndicator();
//     }
//   }
// }

// Future<void> _decompressInIsolate(Map<String, String> paths) async {
//   final inputPath = paths['input']!;
//   final outputPath = paths['output']!;
//   decompressFile(inputPath, outputPath);
// }
