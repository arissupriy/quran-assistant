import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quran_assistant/core/models/quiz_history.dart';
import 'package:quran_assistant/pages/quiz/quiz_session_page.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
// import 'package:quran_assistant/utils/string_extensions.dart'; // Hapus impor ini
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
          backgroundColor: AppTheme.cardColor, // Warna latar belakang dialog
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Sudut membulat
          title: Text(
            'Reset Riwayat Kuis?',
            style: TextStyle(color: AppTheme.textColor),
          ),
          content: Text(
            'Semua riwayat kuis, termasuk detail jawaban, akan dihapus secara permanen. Apakah Anda yakin?',
            style: TextStyle(color: AppTheme.secondaryTextColor),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal', style: TextStyle(color: AppTheme.primaryColor)),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), // Warna merah dari tema error
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
          SnackBar(
            content: Text(
              'Riwayat kuis berhasil direset.',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary), // Warna teks kontras
            ),
            backgroundColor: AppTheme.primaryColor, // Latar belakang snackbar sukses
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mereset riwayat kuis: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error, // Latar belakang snackbar error
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(quizSessionsHistoryStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Warna latar belakang dari tema
      appBar: AppBar(
        title: Text(
          'Riwayat Kuis',
          style: TextStyle(
            color: AppTheme.textColor, // Warna teks judul dari tema
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor, // Warna latar belakang AppBar
        elevation: 0, // Menghilangkan bayangan
        iconTheme: IconThemeData(color: AppTheme.iconColor), // Warna ikon back button
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever_rounded, color: AppTheme.iconColor), // Warna ikon delete
            tooltip: 'Reset Riwayat Kuis',
            onPressed: () => _resetQuizHistory(context, ref),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)), // Warna indikator
        error: (err, stack) => Center(
          child: Text(
            'Error memuat riwayat kuis: ${err.toString()}',
            style: TextStyle(color: Theme.of(context).colorScheme.error), // Warna teks error
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Text(
                'Belum ada riwayat kuis yang tersimpan.',
                style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor), // Warna teks
              ),
            );
          }

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final scopeDetails = jsonDecode(session.scopeDetailsJson);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Sudut membulat
                ),
                color: AppTheme.cardColor, // Warna latar belakang kartu
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Menggunakan replaceAll saja, tanpa toTitleCase
                        'Kuis ${session.quizType.replaceAll('_', ' ')}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cakupan: ${_formatScopeDetails(session.scopeType, scopeDetails)}', // Fungsi helper untuk format scope
                        style: TextStyle(color: AppTheme.secondaryTextColor),
                      ),
                      Text(
                        'Waktu Mulai: ${session.startTime.toLocal().toString().split('.')[0]}',
                        style: TextStyle(color: AppTheme.secondaryTextColor),
                      ),
                      Text(
                        'Durasi: ${session.totalDurationSeconds} detik',
                        style: TextStyle(color: AppTheme.secondaryTextColor),
                      ),
                      Text(
                        'Soal Benar: ${session.correctAnswersCount}/${session.actualQuestionCount}',
                        style: TextStyle(
                          color: session.correctAnswersCount == session.actualQuestionCount
                              ? Colors.green.shade700 // Hijau jika semua benar
                              : AppTheme.textColor, // Warna teks normal
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizSessionDetailPage(quizSession: session),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor, // Warna tombol
                            foregroundColor: Colors.white, // Warna teks tombol
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8), // Sudut membulat tombol
                            ),
                          ),
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

  /// Helper widget untuk membangun baris ringkasan (label dan nilai).
  Widget _buildSummaryRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textColor),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
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
}

// Hapus ekstensi StringExtension dari sini
// extension StringExtension on String {
//   String toCapitalized() => length > 0 ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : '';
//   String toTitleCase() => replaceAll(RegExp(' +'), ' ').split(' ').map((str) => str.toCapitalized()).join(' ');
// }
