import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/providers/quiz_provider.dart'; // Impor providers Anda
import 'package:quran_assistant/core/themes/app_theme.dart'; // Impor AppTheme

class QuizSummaryPage extends ConsumerWidget {
  const QuizSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ambil hasil kuis dari provider yang menyimpan data sesi terakhir
    final correctCount = ref.watch(lastQuizCorrectCountProvider);
    final incorrectCount = ref.watch(lastQuizIncorrectCountProvider);
    final totalCount = ref.watch(lastQuizTotalCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Warna latar belakang dari tema
      appBar: AppBar(
        title: Text(
          'Rangkuman Kuis',
          style: TextStyle(
            color: AppTheme.textColor, // Warna teks judul dari tema
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor, // Warna latar belakang AppBar
        elevation: 0, // Menghilangkan bayangan
        // Sembunyikan tombol kembali default di AppBar
        // Karena pengguna harus menekan tombol 'Kembali ke Menu Utama'
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // Pusatkan secara horizontal
            children: [
              Text(
                'Kuis Selesai!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor, // Warna judul utama dari tema
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Menampilkan total soal
              _buildSummaryRow(
                context,
                'Total Soal:',
                totalCount.toString(),
                AppTheme.textColor, // Warna netral dari tema
              ),
              const SizedBox(height: 15),

              // Menampilkan jumlah jawaban benar
              _buildSummaryRow(
                context,
                'Jawaban Benar:',
                '$correctCount soal',
                Colors.green.shade700!, // Warna hijau untuk benar
              ),
              const SizedBox(height: 15),

              // Menampilkan jumlah jawaban salah
              _buildSummaryRow(
                context,
                'Jawaban Salah:',
                '$incorrectCount soal',
                Colors.red.shade700!, // Warna merah untuk salah
              ),
              const SizedBox(height: 40),

              // Tombol untuk kembali ke menu utama
              ElevatedButton.icon(
                icon: const Icon(Icons.home_rounded),
                label: const Text('Kembali ke Menu Utama'),
                onPressed: () async {
                  // Panggil endQuizSession() untuk menyimpan statistik akhir.
                  // Ini akan menunggu proses penyimpanan ke Hive selesai.
                  await ref.read(quizSessionControllerProvider).endQuizSession();

                  // Setelah endQuizSession() selesai, baru navigasi kembali ke root.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget untuk membangun baris ringkasan (label dan nilai).
  Widget _buildSummaryRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Agar label di kiri, nilai di kanan
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textColor), // Warna teks dari tema
        ),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
