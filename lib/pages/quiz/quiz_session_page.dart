import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quran_assistant/core/models/quiz_history.dart';
import 'package:quran_assistant/core/themes/app_theme.dart'; // Import AppTheme
import 'dart:convert';
import 'package:quran_assistant/src/rust/data_loader/quiz_models.dart' as RustModels;
import 'dart:async';

// FamilyProvider untuk stream semua attempt kuis berdasarkan `sessionId` yang diberikan.
final quizAttemptsHistoryStreamProvider = StreamProvider.family<List<QuizAttempt>, String>((ref, sessionId) {
  final controller = StreamController<List<QuizAttempt>>();
  final box = Hive.box<QuizAttempt>('quizAttempts');

  final listener = () {
    final attempts = box.values
        .where((attempt) => attempt.sessionId == sessionId)
        .toList();
    attempts.sort((a, b) => a.questionIndex.compareTo(b.questionIndex));
    controller.sink.add(attempts);
  };

  box.listenable().addListener(listener);
  listener(); // Panggil sekali untuk data awal

  ref.onDispose(() {
    box.listenable().removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

class QuizSessionDetailPage extends ConsumerWidget {
  final QuizSession quizSession;

  const QuizSessionDetailPage({super.key, required this.quizSession});

  // Helper function to format quiz type (manual capitalization)
  String _formatQuizType(String quizType) {
    String formatted = quizType.replaceAll('_', ' ');
    if (formatted.isEmpty) return '';
    return formatted[0].toUpperCase() + formatted.substring(1).toLowerCase();
  }

  // Helper function to format scope details
  String _formatScopeDetails(String scopeType, Map<String, dynamic> scopeDetails) {
    switch (scopeType) {
      case 'all':
        return 'Semua Ayat';
      case 'by_surah':
        return 'Surah ${scopeDetails['surahId']}';
      case 'by_juz':
        final juzNumbers = (scopeDetails['juzNumbers'] as List).cast<int>();
        if (juzNumbers.length == 1) {
          return 'Juz ${juzNumbers[0]}';
        } else {
          return 'Juz ${juzNumbers.first} - ${juzNumbers.last}';
        }
      default:
        return 'Tidak Diketahui';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(quizAttemptsHistoryStreamProvider(quizSession.sessionId));

    final scopeDetails = jsonDecode(quizSession.scopeDetailsJson);
    final quizTypeDisplay = _formatQuizType(quizSession.quizType); // Menggunakan helper function
    final scopeDisplay = _formatScopeDetails(quizSession.scopeType, scopeDetails); // Menggunakan helper function

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Warna latar belakang dari tema
      appBar: AppBar(
        title: Text(
          'Detail Sesi Kuis',
          style: TextStyle(
            color: AppTheme.textColor, // Warna teks judul dari tema
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor, // Warna latar belakang AppBar
        elevation: 0, // Menghilangkan bayangan
        iconTheme: IconThemeData(color: AppTheme.iconColor), // Warna ikon back button
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 3,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), // Sudut membulat
                ),
                color: AppTheme.cardColor, // Warna latar belakang kartu
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Sesi',
                        style: TextStyle(
                          fontSize: 20, // Ukuran font
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor, // Warna teks
                        ),
                      ),
                      const Divider(height: 24, thickness: 1, color: AppTheme.secondaryTextColor), // Divider bertema
                      _buildInfoRow(context, 'Jenis Kuis:', quizTypeDisplay),
                      _buildInfoRow(context, 'Cakupan Soal:', scopeDisplay),
                      _buildInfoRow(context, 'Jumlah Soal (Diminta/Aktual):', '${quizSession.requestedQuestionCount}/${quizSession.actualQuestionCount}'),
                      _buildInfoRow(context, 'Jawaban Benar:', '${quizSession.correctAnswersCount} soal', valueColor: Colors.green.shade700),
                      _buildInfoRow(context, 'Jawaban Salah:', '${quizSession.incorrectAnswersCount} soal', valueColor: Colors.red.shade700),
                      _buildInfoRow(context, 'Akurasi:', '${((quizSession.correctAnswersCount / quizSession.actualQuestionCount) * 100).toStringAsFixed(2)}%', valueColor: AppTheme.primaryColor),
                      _buildInfoRow(context, 'Waktu Mulai:', quizSession.startTime.toLocal().toString().split('.')[0]),
                      _buildInfoRow(context, 'Waktu Selesai:', quizSession.endTime.toLocal().toString().split('.')[0]),
                      _buildInfoRow(context, 'Total Durasi:', '${quizSession.totalDurationSeconds} detik'),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Detail Jawaban Per Soal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor),
              ),
            ),

            attemptsAsync.when(
              loading: () => Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              )),
              error: (err, stack) => Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error memuat detail jawaban: ${err.toString()}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )),
              data: (attempts) {
                if (attempts.isEmpty) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Tidak ada detail jawaban untuk sesi ini.',
                      style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
                    ),
                  ));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = attempts[index];
                    
                    List<RustModels.QuizOption> options;
                    try {
                      options = (jsonDecode(attempt.optionsJson) as List)
                          .map((e) => RustModels.QuizOption(
                                text: e['text'] as String, 
                                isCorrect: e['is_correct'] as bool,
                              ))
                          .toList();
                    } catch (e) {
                      options = [];
                      debugPrint('Error decoding optionsJson for attempt ${attempt.attemptId}: $e');
                    }

                    final cardColor = attempt.isCorrect ? Colors.green.shade50 : Colors.red.shade50;
                    final statusTextColor = attempt.isCorrect ? Colors.green.shade900 : Colors.red.shade900;

                    // Menggabungkan bagian teks pertanyaan
                    final String fullQuestionText = 
                        '${attempt.questionTextPart1.trim()} _____ ${attempt.missingPartText.trim()} _____ ${attempt.questionTextPart2.trim()}';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Sudut membulat
                      ),
                      color: cardColor, // Warna latar belakang kartu dinamis
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Soal #${attempt.questionIndex + 1}', 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColor)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ayat: ${attempt.verseKey}',
                              style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.secondaryTextColor)
                            ),
                            const SizedBox(height: 8),

                            // Teks Pertanyaan Lengkap (rata kanan untuk Arab)
                            Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                fullQuestionText,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textColor, fontFamily: 'UthmanicHafs'),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Text(
                              'Waktu Habis: ${attempt.timeSpentSeconds} detik',
                              style: TextStyle(color: AppTheme.secondaryTextColor)
                            ),
                            if (attempt.userAnswerIndex != null && 
                                attempt.userAnswerIndex! >= 0 && 
                                attempt.userAnswerIndex! < options.length)
                                Text(
                                  'Jawaban Anda: ${options[attempt.userAnswerIndex!].text}', 
                                  style: TextStyle(
                                    color: attempt.isCorrect ? Colors.green.shade800 : Colors.red.shade800,
                                    fontFamily: 'UthmanicHafs', // Terapkan font Arab
                                    fontSize: 16,
                                  )
                                ),
                            Text(
                              'Jawaban Benar: ${options[attempt.correctAnswerIndex].text}', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontFamily: 'UthmanicHafs', fontSize: 16)
                            ),
                            Text(
                              'Status: ${attempt.isCorrect ? 'Benar ✅' : 'Salah ❌'}', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: statusTextColor)
                            ),
                            Text(
                              'Dicatat: ${attempt.timestamp.toLocal().toString().split('.')[0]}',
                              style: TextStyle(color: AppTheme.secondaryTextColor)
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget untuk membangun baris informasi (label dan nilai).
  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textColor)),
          Text(value, style: TextStyle(color: valueColor ?? AppTheme.textColor)), // Gunakan valueColor jika ada, default textColor
        ],
      ),
    );
  }
}

// Hapus StringExtension dari sini jika ada
// extension StringExtension on String {
//   String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
//   String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str.toCapitalized()).join(' ');
// }
