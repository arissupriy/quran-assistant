import 'package:flutter/material.dart';
import 'package:quran_assistant/pages/quiz/quiz_history_page.dart';
import 'package:quran_assistant/pages/quiz_config_page.dart';
import 'package:quran_assistant/core/themes/app_theme.dart'; // Import AppTheme

class QuizPage extends StatelessWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context) {
    final quizTypes = [
      {
        'type': 'verse_completion',
        'title': 'Melanjutkan Ayat',
        'description':
            'Lengkapi ayat berikutnya dari potongan ayat sebelumnya.',
        'icon': Icons.short_text_rounded,
      },
      {
        'type': 'fragment_completion',
        'title': 'Melengkapi Ayat',
        'description': 'Tebak bagian ayat yang hilang dari satu ayat panjang.',
        'icon': Icons.edit_note_rounded,
      },
      {
        'type': 'verse_previous',
        'title': 'Tebak Ayat Sebelumnya',
        'description': 'Tebak ayat yang datang sebelum ayat yang ditampilkan.',
        'icon': Icons.undo_rounded,
      },
      {
        'type': 'verse_order',
        'title': 'Puzzle Urutan Ayat',
        'description':
            'Urutkan potongan ayat yang telah diacak agar sesuai urutan aslinya.',
        'icon': Icons.sort_rounded,
      },
    ];

    // Hapus Scaffold dan AppBar di sini.
    // Konten QuizPage akan menjadi body dari Scaffold di MainScreen.
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start, // Agar teks "Pilih Jenis Kuis" rata kiri
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pilih Jenis Kuis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor, // Warna teks judul dari tema
                ),
              ),
              // Tombol untuk menuju QuizHistoryPage
              IconButton(
                icon: Icon(
                  Icons.history_toggle_off_rounded, // Ikon riwayat
                  color: AppTheme.iconColor, // Warna ikon dari tema
                ),
                tooltip: 'Riwayat Kuis', // Tooltip untuk aksesibilitas
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const QuizHistoryPage(), // Navigasi ke QuizHistoryPage
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quizTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quiz = quizTypes[index];
              return Card(
                // CardTheme sudah diatur di AppTheme
                margin: EdgeInsets.zero, // Hapus margin default Card di sini
                child: ListTile(
                  // tileColor: AppTheme.cardColor, // Warna tile akan mengikuti CardTheme
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Sudut membulat
                  ),
                  leading: Icon(
                    quiz['icon'] as IconData,
                    size: 32,
                    color: AppTheme.primaryColor, // Warna ikon dari tema
                  ),
                  title: Text(
                    quiz['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor, // Warna teks judul dari tema
                    ),
                  ),
                  subtitle: Text(
                    quiz['description'] as String,
                    style: TextStyle(
                      color: AppTheme
                          .secondaryTextColor, // Warna teks subtitle dari tema
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.secondaryTextColor, // Warna ikon dari tema
                  ),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
