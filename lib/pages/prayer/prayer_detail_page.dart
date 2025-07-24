import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/core/models/prayer_data_model.dart';
import 'package:quran_assistant/providers/prayer_api_time_provider.dart'; // Perbarui import ini

class PrayerSchedulePage extends ConsumerWidget {
  const PrayerSchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mengawasi provider data sholat
    final ParsedPrayerData? prayerData = ref.watch(dummyPrayerTimesProvider); // Bisa null

    if (prayerData == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            'Jadwal Sholat',
            style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.iconColor),
        ),
        body: Center(
          child: Text(
            'Data jadwal sholat tidak tersedia.',
            style: TextStyle(fontSize: 16.0, color: AppTheme.secondaryTextColor),
          ),
        ),
      );
    }

    final List<PrayerTime> prayers = prayerData.prayerTimesList;
    final String locationName = '${prayerData.location.lokasi}, ${prayerData.location.daerah}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Jadwal Sholat',
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
            // Ringkasan Lokasi dan Tanggal
            Card(
              color: AppTheme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lokasi:',
                      style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
                    ),
                    Text(
                      locationName,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tanggal:',
                      style: TextStyle(fontSize: 16, color: AppTheme.secondaryTextColor),
                    ),
                    Text(
                      prayerData.schedule.tanggal, // Tanggal dari data dummy
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Waktu Sholat Hari Ini',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 12),

            // Daftar Waktu Sholat Lengkap
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prayers.length,
              itemBuilder: (context, index) {
                final prayer = prayers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: AppTheme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          prayer.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textColor,
                          ),
                        ),
                        Text(
                          prayer.time.format(context),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
