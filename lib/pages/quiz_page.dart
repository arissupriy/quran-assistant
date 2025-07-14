// lib/pages/quiz_page.dart

import 'package:flutter/material.dart';
import 'package:quran_assistant/pages/quiz/quiz_history_page.dart';
import 'package:quran_assistant/pages/quiz_config_page.dart';

class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    final quizTypes = [
      {
        'type': 'verse_completion',
        'title': 'Melengkapi Ayat',
        'description': 'Lengkapi ayat berikutnya dari potongan ayat sebelumnya.',
        'icon': Icons.short_text_rounded,
      },
      {
        'type': 'fragment_completion',
        'title': 'Melengkapi Fragmen',
        'description': 'Tebak bagian ayat yang hilang dari satu ayat panjang.',
        'icon': Icons.edit_note_rounded,
      },
      // Anda bisa menambahkan jenis kuis lain di sini jika ada
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Jenis Kuis'),
        centerTitle: true,
        actions: [
          // Tambahkan IconButton di AppBar untuk menuju QuizHistoryPage
          IconButton(
            icon: const Icon(Icons.history_toggle_off_rounded), // Ikon riwayat
            tooltip: 'Riwayat Kuis', // Tooltip untuk aksesibilitas
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QuizHistoryPage(), // Navigasi ke QuizHistoryPage
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: quizTypes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final quiz = quizTypes[index];
          return ListTile(
            tileColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(quiz['icon'] as IconData, size: 32),
            title: Text(
              quiz['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(quiz['description'] as String),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizConfigPage(
                    selectedQuizType: quiz['type'] as String,
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