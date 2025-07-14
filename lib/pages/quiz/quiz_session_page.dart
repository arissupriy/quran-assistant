// lib/pages/quiz_session_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quran_assistant/core/models/quiz_history.dart';
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
  listener();

  ref.onDispose(() {
    box.listenable().removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

class QuizSessionDetailPage extends ConsumerWidget {
  final QuizSession quizSession;

  const QuizSessionDetailPage({super.key, required this.quizSession});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptsAsync = ref.watch(quizAttemptsHistoryStreamProvider(quizSession.sessionId));

    final scopeDetails = jsonDecode(quizSession.scopeDetailsJson);
    final quizTypeDisplay = quizSession.quizType.replaceAll('_', ' ').toCapitalized();
    final scopeDisplay = quizSession.scopeType == 'All' 
        ? 'Semua Ayat' 
        : '${quizSession.scopeType} - ${scopeDetails['type'] == 'all' ? '' : scopeDetails}'; // Sedikit perbaikan tampilan ScopeDetails

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Sesi Kuis')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 3,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Sesi',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      _buildInfoRow('Jenis Kuis:', quizTypeDisplay),
                      _buildInfoRow('Cakupan Soal:', scopeDisplay),
                      _buildInfoRow('Jumlah Soal (Diminta/Aktual):', '${quizSession.requestedQuestionCount}/${quizSession.actualQuestionCount}'),
                      _buildInfoRow('Jawaban Benar:', '${quizSession.correctAnswersCount} soal'),
                      _buildInfoRow('Jawaban Salah:', '${quizSession.incorrectAnswersCount} soal'),
                      _buildInfoRow('Akurasi:', '${((quizSession.correctAnswersCount / quizSession.actualQuestionCount) * 100).toStringAsFixed(2)}%'),
                      _buildInfoRow('Waktu Mulai:', quizSession.startTime.toLocal().toString().split('.')[0]),
                      _buildInfoRow('Waktu Selesai:', quizSession.endTime.toLocal().toString().split('.')[0]),
                      _buildInfoRow('Total Durasi:', '${quizSession.totalDurationSeconds} detik'),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Detail Jawaban Per Soal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            attemptsAsync.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )),
              error: (err, stack) => Center(child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Error memuat detail jawaban: ${err.toString()}'),
              )),
              data: (attempts) {
                if (attempts.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Tidak ada detail jawaban untuk sesi ini.'),
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

                    final cardColor = attempt.isCorrect ? Colors.green[50] : Colors.red[50];
                    final statusTextColor = attempt.isCorrect ? Colors.green.shade900 : Colors.red.shade900;

                    // Menggabungkan bagian teks pertanyaan
                    final String fullQuestionText = 
                        '${attempt.questionTextPart1.trim()} _____ ${attempt.missingPartText.trim()} _____ ${attempt.questionTextPart2.trim()}';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      elevation: 2,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Soal #${attempt.questionIndex + 1}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                            const SizedBox(height: 4),
                            Text('Ayat: ${attempt.verseKey}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 8),

                            // --- Teks Pertanyaan Lengkap ---
                            Text(
                              'Pertanyaan: $fullQuestionText',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            // --- AKHIR Teks Pertanyaan Lengkap ---

                            Text('Waktu Habis: ${attempt.timeSpentSeconds} detik'),
                            if (attempt.userAnswerIndex != null && 
                                attempt.userAnswerIndex! >= 0 && 
                                attempt.userAnswerIndex! < options.length)
                                Text(
                                  'Jawaban Anda: ${options[attempt.userAnswerIndex!].text}', 
                                  style: TextStyle(
                                    color: attempt.isCorrect ? Colors.green.shade800 : Colors.red.shade800
                                  )
                                ),
                            Text(
                              'Jawaban Benar: ${options[attempt.correctAnswerIndex].text}', 
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                            Text(
                              'Status: ${attempt.isCorrect ? 'Benar ✅' : 'Salah ❌'}', 
                              style: TextStyle(fontWeight: FontWeight.bold, color: statusTextColor)
                            ),
                            Text('Dicatat: ${attempt.timestamp.toLocal().toString().split('.')[0]}'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }
}
// Helper extension for String capitalization (if not already defined elsewhere)
extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str.toCapitalized()).join(' ');
}