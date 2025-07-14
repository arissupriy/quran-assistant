// lib/pages/quiz_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quran_assistant/core/models/quiz_history.dart';
import 'package:quran_assistant/pages/quiz/quiz_session_page.dart';
import 'dart:convert';
import 'dart:async';

// Provider untuk stream semua sesi kuis dari Hive.
final quizSessionsHistoryStreamProvider = StreamProvider<List<QuizSession>>((ref) {
  final controller = StreamController<List<QuizSession>>();
  final box = Hive.box<QuizSession>('quizSessions');

  final listener = () {
    final sessions = box.values.toList();
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    controller.sink.add(sessions);
  };

  box.listenable().addListener(listener);
  listener(); // Panggil sekali untuk data awal

  ref.onDispose(() {
    box.listenable().removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

class QuizHistoryPage extends ConsumerWidget {
  const QuizHistoryPage({super.key});

  Future<void> _resetQuizHistory(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset Riwayat Kuis?'),
          content: const Text('Semua riwayat kuis, termasuk detail jawaban, akan dihapus secara permanen. Apakah Anda yakin?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Hapus Semua'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final sessionBox = Hive.box<QuizSession>('quizSessions');
        final attemptBox = Hive.box<QuizAttempt>('quizAttempts');

        await sessionBox.clear();
        await attemptBox.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Riwayat kuis berhasil direset.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mereset riwayat kuis: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(quizSessionsHistoryStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Kuis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            tooltip: 'Reset Riwayat Kuis',
            onPressed: () => _resetQuizHistory(context, ref),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error memuat riwayat kuis: ${err.toString()}')),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(child: Text('Belum ada riwayat kuis yang tersimpan.'));
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final scopeDetails = jsonDecode(session.scopeDetailsJson); 
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kuis ${session.quizType.replaceAll('_', ' ')}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Cakupan: ${session.scopeType} - ${scopeDetails['type'] == 'all' ? 'Semua Ayat' : scopeDetails}'),
                      Text('Waktu Mulai: ${session.startTime.toLocal().toString().split('.')[0]}'),
                      Text('Durasi: ${session.totalDurationSeconds} detik'),
                      Text('Soal Benar: ${session.correctAnswersCount}/${session.actualQuestionCount}'),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                // --- PERUBAHAN DI SINI ---
                                // Teruskan seluruh objek QuizSession
                                builder: (_) => QuizSessionDetailPage(quizSession: session),
                              ),
                            );
                          },
                          child: const Text('Lihat Detail'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension StringExtension on String {
  String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
  String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str).join(' ');
}