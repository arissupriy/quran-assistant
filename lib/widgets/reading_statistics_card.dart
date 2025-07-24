import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:quran_assistant/pages/statistics/quran_statistic_page.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart';

class ReadingStatisticsCard extends ConsumerWidget {
  const ReadingStatisticsCard({super.key});

  // Helper untuk memformat durasi menjadi string yang lebih ringkas
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");

    if (duration.inHours >= 1) { // Jika durasi 1 jam atau lebih
      return "${twoDigits(duration.inHours)}j ${twoDigits(duration.inMinutes.remainder(60))}m";
    } else { // Jika durasi kurang dari 1 jam
      return "${twoDigits(duration.inMinutes.remainder(60))}m ${twoDigits(duration.inSeconds.remainder(60))}d";
    }
  }

  // Fungsi untuk mendapatkan pesan perbandingan
  String _getComparisonMessage(Duration todayDuration, Duration yesterdayDuration) {
    if (todayDuration.inSeconds == 0 && yesterdayDuration.inSeconds == 0) {
      return 'Anda belum mulai membaca. Ayo semangat!';
    } else if (todayDuration.inSeconds > 0 && yesterdayDuration.inSeconds == 0) {
      return 'Hebat! Anda mulai membaca hari ini. Pertahankan!';
    } else if (todayDuration.inSeconds == 0 && yesterdayDuration.inSeconds > 0) {
      return 'Anda belum membaca hari ini. Mari lanjutkan semangat kemarin!';
    }

    double todaySeconds = todayDuration.inSeconds.toDouble();
    double yesterdaySeconds = yesterdayDuration.inSeconds.toDouble();

    if (todaySeconds > yesterdaySeconds) {
      double percentageIncrease = ((todaySeconds - yesterdaySeconds) / yesterdaySeconds) * 100;
      return 'Luar biasa! Anda membaca ${percentageIncrease.toStringAsFixed(0)}% lebih banyak dari hari kemarin.';
    } else if (todaySeconds < yesterdaySeconds) {
      double percentageDecrease = ((yesterdaySeconds - todaySeconds) / yesterdaySeconds) * 100;
      return 'Anda membaca ${percentageDecrease.toStringAsFixed(0)}% lebih sedikit dari hari kemarin. Ayo tingkatkan lagi!';
    } else {
      return 'Progres bacaan Anda konsisten dengan hari kemarin. Terus istiqomah!';
    }
  }

  // Helper widget baru untuk menampilkan satu metrik statistik secara menarik
  Widget _buildStatMetricCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Card(
        color: AppTheme.backgroundColor, // Latar belakang kartu metrik
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final AsyncValue<List<ReadingSession>> readingSessionsAsync = ref.watch(allReadingSessionsStreamProvider);
    final AsyncValue<Map<DateTime, Duration>> dailyDurationsAsync = ref.watch(dailyReadingDurationsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reading Statistics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuranStatisticPage()),
                );
              },
              child: Text(
                'See All',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Kartu Perbandingan Harian
        dailyDurationsAsync.when(
          loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          error: (err, stack) => Center(
            child: Text(
              'Error memuat perbandingan: ${err.toString()}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          data: (dailyDurations) {
            final yesterday = today.subtract(const Duration(days: 1));
            
            final todayDuration = dailyDurations[today] ?? Duration.zero;
            final yesterdayDuration = dailyDurations[yesterday] ?? Duration.zero;

            return Card(
              color: AppTheme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: AppTheme.primaryColor, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perbandingan Hari Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getComparisonMessage(todayDuration, yesterdayDuration),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Kartu Statistik Hari Ini dengan Tampilan Baru
        Card(
          color: AppTheme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: readingSessionsAsync.when(
              loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              error: (err, stack) => Center(
                child: Text(
                  'Error memuat statistik: ${err.toString()}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (allReadingSessions) {
                final todayReadingSessions = allReadingSessions.where((session) {
                  final sessionDate = DateTime(session.date.year, session.date.month, session.date.day);
                  return sessionDate.isAtSameMomentAs(today);
                }).toList();

                if (todayReadingSessions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.secondaryTextColor.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text(
                            'Anda belum membaca mushaf pada aplikasi ini hari ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mari luangkan waktu untuk membaca Al-Qur\'an!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14.0, color: AppTheme.secondaryTextColor.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalDuration = todayReadingSessions.fold(
                  Duration.zero,
                  (sum, session) => sum + session.duration,
                );
                final totalPagesRead = todayReadingSessions.map((s) => s.page).toSet().length;
                final totalSessions = todayReadingSessions.length;
                final averageSessionDuration = todayReadingSessions.isNotEmpty
                    ? totalDuration ~/ todayReadingSessions.length
                    : Duration.zero;

                return Column(
                  children: [
                    Row(
                      children: [
                        _buildStatMetricCard(
                          context: context,
                          icon: Icons.timer_rounded,
                          value: _formatDuration(totalDuration), // Menggunakan format baru
                          label: 'Waktu Baca',
                        ),
                        const SizedBox(width: 8),
                        _buildStatMetricCard(
                          context: context,
                          icon: Icons.auto_stories_rounded,
                          value: '$totalPagesRead',
                          label: 'Halaman Unik',
                        ),
                        const SizedBox(width: 8),
                        _buildStatMetricCard(
                          context: context,
                          icon: Icons.history_rounded,
                          value: '$totalSessions',
                          label: 'Total Sesi',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
