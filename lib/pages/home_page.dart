import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/pages/prayer/prayer_detail_page.dart';
import 'package:quran_assistant/pages/statistics/quran_statistic_page.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/widgets/prayer_times_widget.dart'; // Import PrayerTimesWidget

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  // Helper untuk memformat durasi menjadi string yang mudah dibaca
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}j ${twoDigitMinutes}m"; // Hanya jam dan menit
    } else if (duration.inMinutes > 0) {
      return "${twoDigitMinutes}m ${twoDigitSeconds}d";
    } else {
      return "${twoDigits(duration.inSeconds)}d"; // Hanya detik
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dummy Data untuk Mockup
    final String userName = "Tanvir Ahassan";
    final String lastReadSurah = "Al-Baqarah 1";
    final double completionPercentage = 0.83;

    final List<Map<String, dynamic>> readingSchedule = [
      {
        'date': '9 FEB 21',
        'title': 'Quran Juz 1',
        'subtitle': 'Al-Fatihah 1 - Al-Baqarah 141',
      },
      {
        'date': '10 FEB 21',
        'title': 'Quran Juz 2',
        'subtitle': 'Al-Baqarah 142 - An-Nisa 24',
      },
      {
        'date': '10 FEB 21',
        'title': 'TPQ 1',
        'subtitle': 'Al-Baqarah',
      },
    ];

    final List<Map<String, dynamic>> communities = [
      {
        'name': 'Quran Lovers',
        'members': '100 Members',
        'icon': Icons.favorite_rounded,
        'iconColor': Colors.pink.shade300,
      },
      {
        'name': 'TPQ Malang',
        'members': '205 Members',
        'icon': Icons.group_rounded,
        'iconColor': Colors.green.shade300,
      },
      {
        'name': 'Hafidz Indonesia',
        'members': '300 Members',
        'icon': Icons.verified_user_rounded,
        'iconColor': Colors.blue.shade300,
      },
    ];

    final readingSessions = ref.watch(dummyReadingSessionsProvider);

    final totalDuration = readingSessions.fold(
      Duration.zero,
      (sum, session) => sum + session.duration,
    );
    final totalPagesRead = readingSessions.map((s) => s.page).toSet().length;
    final averageSessionDuration = readingSessions.isNotEmpty
        ? totalDuration ~/ readingSessions.length
        : Duration.zero;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Salam dan Nama Pengguna
          Text(
            'Assalamualaikum',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            userName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 24),

          // Jadwal Sholat (Widget yang baru dan didesain ulang)
          // Menambahkan GestureDetector untuk navigasi
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrayerSchedulePage()),
              );
            },
            child: SizedBox(
              height: 265, // Tinggi yang sudah disesuaikan
              child: const PrayerTimesWidget(),
            ),
          ),
          const SizedBox(height: 24),

          // Card "Quran Completion"
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.shadowColor.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Card(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quran Completion',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Last Read $lastReadSurah',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: completionPercentage,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            borderRadius: BorderRadius.circular(5),
                            minHeight: 8,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(completionPercentage * 100).toInt()}%',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Image.network(
                      'https://placehold.co/100x100/00796B/FFFFFF?text=Quran',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.menu_book_rounded, size: 80, color: Colors.white.withOpacity(0.7));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bagian "Reading Statistics"
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
          Card(
            color: AppTheme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildCompactStatRow(
                    context,
                    Icons.timer_rounded,
                    'Waktu Baca Total:',
                    _formatDuration(totalDuration),
                  ),
                  _buildCompactStatRow(
                    context,
                    Icons.auto_stories_rounded,
                    'Halaman Unik Dibaca:',
                    '$totalPagesRead',
                  ),
                  _buildCompactStatRow(
                    context,
                    Icons.av_timer_rounded,
                    'Durasi Sesi Rata-rata:',
                    _formatDuration(averageSessionDuration),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bagian "My Schedule"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Schedule',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Aksi Lihat Semua Jadwal
                },
                child: Text(
                  'See All',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: readingSchedule.length,
            itemBuilder: (context, index) {
              final schedule = readingSchedule[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: Text(
                    schedule['date'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  title: Text(
                    schedule['title'] as String,
                    style: TextStyle(color: AppTheme.textColor),
                  ),
                  subtitle: Text(
                    schedule['subtitle'] as String,
                    style: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                  onTap: () {
                    // TODO: Aksi saat jadwal di-tap
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Bagian "Community"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Community',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Aksi Lihat Semua Komunitas
                },
                child: Text(
                  'See All',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final community = communities[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (community['iconColor'] as Color).withOpacity(0.1),
                    child: Icon(
                      community['icon'] as IconData,
                      color: community['iconColor'] as Color,
                    ),
                  ),
                  title: Text(
                    community['name'] as String,
                    style: TextStyle(color: AppTheme.textColor),
                  ),
                  subtitle: Text(
                    community['members'] as String,
                    style: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                  onTap: () {
                    // TODO: Aksi saat komunitas di-tap
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Helper widget baru untuk membangun baris statistik ringkas
  Widget _buildCompactStatRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 16, color: AppTheme.textColor),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }
}
