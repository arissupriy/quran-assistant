import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart'; // Import AppTheme
import 'package:quran_assistant/core/models/reading_session.dart'; // Import model ReadingSession Anda
import 'package:intl/intl.dart'; // Untuk format tanggal dan durasi

// Dummy Data Provider (untuk tujuan mockup)
final dummyReadingSessionsProvider = Provider<List<ReadingSession>>((ref) {
  // Membuat beberapa dummy data sesi membaca
  return [
    ReadingSession(
      page: 10,
      openedAt: DateTime(2023, 10, 26, 8, 0, 0),
      closedAt: DateTime(2023, 10, 26, 8, 15, 30),
      previousPage: 5,
      date: DateTime(2023, 10, 26),
    ),
    ReadingSession(
      page: 25,
      openedAt: DateTime(2023, 10, 26, 10, 0, 0),
      closedAt: DateTime(2023, 10, 26, 10, 45, 0),
      previousPage: 15,
      date: DateTime(2023, 10, 26),
    ),
    ReadingSession(
      page: 50,
      openedAt: DateTime(2023, 10, 27, 14, 0, 0),
      closedAt: DateTime(2023, 10, 27, 14, 30, 0),
      previousPage: 30,
      date: DateTime(2023, 10, 27),
    ),
    ReadingSession(
      page: 70,
      openedAt: DateTime(2023, 10, 28, 7, 0, 0),
      closedAt: DateTime(2023, 10, 28, 7, 50, 0),
      previousPage: 55,
      date: DateTime(2023, 10, 28),
    ),
    ReadingSession(
      page: 80,
      openedAt: DateTime(2023, 10, 28, 19, 0, 0),
      closedAt: DateTime(2023, 10, 28, 19, 10, 0),
      previousPage: 75,
      date: DateTime(2023, 10, 28),
    ),
  ];
});

class QuranStatisticPage extends ConsumerWidget {
  const QuranStatisticPage({super.key});

  // Helper untuk memformat durasi menjadi string yang mudah dibaca
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}j ${twoDigitMinutes}m ${twoDigitSeconds}d";
    } else if (duration.inMinutes > 0) {
      return "${twoDigitMinutes}m ${twoDigitSeconds}d";
    } else {
      return "${twoDigitSeconds}d";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingSessions = ref.watch(dummyReadingSessionsProvider);

    // Hitung statistik dari dummy data
    final totalDuration = readingSessions.fold(
      Duration.zero,
      (sum, session) => sum + session.duration,
    );
    final totalPagesRead = readingSessions.map((s) => s.page).toSet().length; // Halaman unik
    final totalSessions = readingSessions.length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor, // Latar belakang dari tema
      appBar: AppBar(
        title: Text(
          'Statistik Bacaan',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.iconColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Ringkasan Statistik
            Card(
              color: AppTheme.primaryColor, // Warna primary untuk card ringkasan
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Progres Anda',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatRow(
                      context,
                      Icons.timer_rounded,
                      'Total Waktu Baca:',
                      _formatDuration(totalDuration),
                      Colors.white,
                    ),
                    _buildStatRow(
                      context,
                      Icons.menu_book_rounded,
                      'Total Halaman Unik Dibaca:',
                      '$totalPagesRead halaman',
                      Colors.white,
                    ),
                    _buildStatRow(
                      context,
                      Icons.history_rounded,
                      'Total Sesi Baca:',
                      '$totalSessions sesi',
                      Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Judul Riwayat Sesi
            Text(
              'Riwayat Sesi Bacaan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 12),

            // Daftar Riwayat Sesi Bacaan
            if (readingSessions.isEmpty)
              Center(
                child: Text(
                  'Belum ada riwayat sesi bacaan.',
                  style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: readingSessions.length,
                itemBuilder: (context, index) {
                  final session = readingSessions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    color: AppTheme.cardColor, // Warna latar belakang kartu
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.secondaryColor.withOpacity(0.1),
                        child: Text(
                          '${session.page}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      ),
                      title: Text(
                        'Halaman ${session.page}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor),
                      ),
                      subtitle: Text(
                        'Waktu: ${DateFormat('HH:mm').format(session.openedAt)} - ${DateFormat('HH:mm').format(session.closedAt)}\nDurasi: ${_formatDuration(session.duration)}',
                        style: TextStyle(fontSize: 12, color: AppTheme.secondaryTextColor),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                      onTap: () {
                        // TODO: Aksi saat sesi bacaan di-tap (misal: navigasi ke halaman tersebut)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Membuka Halaman ${session.page}')),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Helper widget untuk membangun baris statistik
  Widget _buildStatRow(BuildContext context, IconData icon, String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.9)),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }
}
