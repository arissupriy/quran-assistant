import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/providers/quiz_provider.dart'; // Impor providers Anda

class QuizSummaryPage extends ConsumerWidget {
  const QuizSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ambil hasil kuis dari provider yang menyimpan data sesi terakhir
    final correctCount = ref.watch(lastQuizCorrectCountProvider);
    final incorrectCount = ref.watch(lastQuizIncorrectCountProvider);
    final totalCount = ref.watch(lastQuizTotalCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rangkuman Kuis'),
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
              const Text(
                'Kuis Selesai!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              
              // Menampilkan total soal
              _buildSummaryRow(
                context,
                'Total Soal:',
                totalCount.toString(),
                Colors.black, // Warna netral
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
                onPressed: () async { // Pastikan onPressed adalah async
                  // Panggil endQuizSession() untuk menyimpan statistik akhir.
                  // Ini akan menunggu proses penyimpanan ke Hive selesai.
                  await ref.read(quizSessionControllerProvider).endQuizSession();

                  // Setelah endQuizSession() selesai, baru navigasi kembali.
                  // Tidak perlu context.mounted di sini karena kita sudah await.
                  // Jika context sudah tidak mounted, exception akan terjadi di sini,
                  // TAPI karena endQuizSession() sudah selesai, data sudah tersimpan.
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}