// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:record/record.dart';
// import 'package:whisper_ggml/whisper_ggml.dart';

// class QuranRecorderPage extends StatefulWidget {
//   const QuranRecorderPage({super.key});

//   @override
//   State<QuranRecorderPage> createState() => _QuranRecorderPageState();
// }

// class _QuranRecorderPageState extends State<QuranRecorderPage> {
//   final model = WhisperModel.tiny; // Bisa ganti sesuai kebutuhan
//   final WhisperController whisperController = WhisperController();
//   final AudioRecorder audioRecorder = AudioRecorder();

//   bool isRecording = false;
//   bool isProcessing = false;
//   String transcription = "Tekan tombol mic untuk mulai rekam";

//   String? recordedFilePath;

//   @override
//   void initState() {
//     super.initState();
//     _initModel();
//   }

//   Future<void> _initModel() async {
//     try {
//       // Load model dari assets ke direktori yang bisa diakses
//       final bytes = await rootBundle.load('assets/ggml-${model.modelName}.bin');
//       final modelPath = await whisperController.getPath(model);
//       final file = File(modelPath);
//       await file.writeAsBytes(bytes.buffer.asUint8List());
//     } catch (e) {
//       // Kalau gagal, coba download model
//       await whisperController.downloadModel(model);
//     }
//   }

//   Future<void> _toggleRecording() async {
//     if (isRecording) {
//       // Stop recording
//       final path = await audioRecorder.stop();
//       setState(() {
//         isRecording = false;
//         isProcessing = true;
//         recordedFilePath = path;
//       });

//       if (path != null) {
//         // Transcribe audio file
//         final result = await whisperController.transcribe(
//           model: model,
//           audioPath: path,
//           lang: 'ar',
//         );

//         setState(() {
//           isProcessing = false;
//           transcription =
//               result?.transcription.text ?? "Tidak ada teks terdeteksi";
//         });
//       } else {
//         setState(() {
//           isProcessing = false;
//           transcription = "Rekaman gagal disimpan";
//         });
//       }
//     } else {
//       // Start recording
//       final hasPermission = await audioRecorder.hasPermission();
//       if (!hasPermission) {
//         setState(() {
//           transcription = "Izin rekaman tidak diberikan";
//         });
//         return;
//       }

//       final tempDir = await getTemporaryDirectory();
//       final path = '${tempDir.path}/quran_record.m4a';

//       await audioRecorder.start(
//         const RecordConfig(), // You can customize the config if needed
//         path: path,
//       );
//       setState(() {
//         isRecording = true;
//         transcription = "Sedang merekam...";
//       });
//     }
//   }

//   @override
//   void dispose() {
//     if (isRecording) {
//       audioRecorder.stop();
//     }
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Rekaman & Transkripsi Quran")),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton.icon(
//               icon: Icon(isRecording ? Icons.mic_off : Icons.mic),
//               label: Text(isRecording ? "Stop Rekam" : "Mulai Rekam"),
//               onPressed: isProcessing ? null : _toggleRecording,
//             ),
//             const SizedBox(height: 20),
//             if (isProcessing) ...[
//               const CircularProgressIndicator(),
//               const SizedBox(height: 20),
//             ],
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Text(
//                   transcription,
//                   style: const TextStyle(fontSize: 16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
