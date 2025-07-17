import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/pages/prayer/prayer_detail_page.dart';
import 'package:quran_assistant/pages/statistics/quran_statistic_page.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/providers/reading_session_provider.dart';
import 'package:quran_assistant/widgets/prayer_times_widget.dart';
import 'package:quran_assistant/widgets/reading_statistics_card.dart';
import 'package:quran_assistant/widgets/last_read_card.dart'; // BARU: Import widget baru

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  // Helper untuk memformat durasi menjadi string yang mudah dibaca
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}j ${twoDigitMinutes}m";
    } else if (duration.inMinutes > 0) {
      return "${twoDigitMinutes}m ${twoDigitSeconds}d";
    } else {
      return "${twoDigits(duration.inSeconds)}d";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Dummy Data untuk Mockup (selain statistik bacaan)
    final String userName = "Tanvir Ahassan";
    final double completionPercentage = 0.83; // This can be dynamic later

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bagian Salam dan Nama Pengguna
          

          // Jadwal Sholat
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrayerSchedulePage()),
              );
            },
            child: SizedBox(
              height: 265,
              child: const PrayerTimesWidget(),
            ),
          ),
          const SizedBox(height: 24),

          // Card "Quran Completion" (sekarang menggunakan LastReadCard)
          LastReadCard(
            // completionPercentage: completionPercentage,
            isHomePage: true, // Beri tahu widget bahwa ini digunakan di home_page
          ),
          const SizedBox(height: 24),

          // Bagian "Reading Statistics" (sekarang adalah widget terpisah)
          const ReadingStatisticsCard(),
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
}
