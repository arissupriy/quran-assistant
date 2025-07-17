import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/core/models/prayer_data_model.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/providers/prayer_api_time_provider.dart';

class PrayerTimesWidget extends ConsumerWidget {
  const PrayerTimesWidget({super.key});

  /// Helper untuk menghitung sisa waktu ke sholat berikutnya
  String _getTimeRemaining(DateTime targetTime) {
    final now = DateTime.now();
    Duration remaining = targetTime.difference(now);

    if (remaining.isNegative) {
      targetTime = targetTime.add(const Duration(days: 1));
      remaining = targetTime.difference(now);
    }

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(remaining.inHours);
    String minutes = twoDigits(remaining.inMinutes.remainder(60));
    String seconds = twoDigits(remaining.inSeconds.remainder(60));

    if (remaining.inHours > 0) {
      return "$hours jam $minutes menit lagi";
    } else if (remaining.inMinutes > 0) {
      return "$minutes menit $seconds detik lagi";
    } else {
      return "$seconds detik lagi";
    }
  }

  /// Helper untuk mendapatkan path gambar latar belakang lokal berdasarkan waktu
  String _getBackgroundImagePath(List<PrayerTime> prayers, DateTime now) {
    DateTime getTodayPrayerTime(String name) {
      final prayer = prayers.firstWhere((p) => p.name == name);
      return DateTime(now.year, now.month, now.day, prayer.time.hour, prayer.time.minute);
    }

    try {
      final imsakTime = getTodayPrayerTime('Imsak');
      final dhuhaTime = getTodayPrayerTime('Dhuha');
      final asrTime = getTodayPrayerTime('Ashar');
      final ishaTime = getTodayPrayerTime('Isya');

      if (now.isAfter(ishaTime) || now.isBefore(imsakTime)) {
        return 'assets/images/night.png';
      } else if (now.isAfter(imsakTime) && now.isBefore(dhuhaTime)) {
        return 'assets/images/sunrise.png';
      } else if (now.isAfter(dhuhaTime) && now.isBefore(asrTime)) {
        return 'assets/images/noon.png';
      } else if (now.isAfter(asrTime) && now.isBefore(ishaTime)) {
        return 'assets/images/sunset.png';
      }
    } catch (e) {
      // Fallback jika salah satu nama sholat tidak ditemukan
      return 'assets/images/noon.png';
    }

    return 'assets/images/noon.png'; // Default
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DateTime> timeAsync = ref.watch(timeTickerProvider);
    final ParsedPrayerData? prayerData = ref.watch(dummyPrayerTimesProvider);

    final bool hasData = prayerData != null && prayerData.prayerTimesList.isNotEmpty;
    final List<PrayerTime> prayers = hasData ? prayerData!.prayerTimesList : [];
    final String locationName = hasData ? '${prayerData!.location.lokasi}, ${prayerData.location.daerah}' : 'Lokasi Tidak Ditemukan';

    final now = timeAsync.value ?? DateTime.now();

    String displayTime = '--:--';
    String displayName = '--';
    String displayRemainingTime = '--';
    String backgroundImagePath = 'assets/images/noon.png';

    if (hasData) {
      try {
        List<DateTime> todayPrayerTimes = prayers
            .map((p) => DateTime(now.year, now.month, now.day, p.time.hour, p.time.minute))
            .toList();

        int nextPrayerIndex = todayPrayerTimes.indexWhere((time) => time.isAfter(now));

        PrayerTime nextPrayer;
        DateTime nextPrayerDateTime;

        if (nextPrayerIndex != -1) {
          nextPrayer = prayers[nextPrayerIndex];
          nextPrayerDateTime = todayPrayerTimes[nextPrayerIndex];
        } else {
          nextPrayer = prayers.firstWhere((p) => p.name == 'Imsak');
          nextPrayerDateTime = DateTime(now.year, now.month, now.day, nextPrayer.time.hour, nextPrayer.time.minute).add(const Duration(days: 1));
        }

        displayTime = nextPrayer.time.format(context);
        displayName = nextPrayer.name;
        displayRemainingTime = _getTimeRemaining(nextPrayerDateTime);
        backgroundImagePath = _getBackgroundImagePath(prayers, now);
      } catch (e) {
        // Menangani error jika data sholat tidak lengkap, biarkan placeholder yang digunakan
        debugPrint("Error saat memproses data sholat: $e");
      }
    }

    final bool isNoon = backgroundImagePath.contains('noon.png');

    return Container(
      height: 220, // Beri tinggi agar konsisten
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // --- LAPISAN 1: GAMBAR LATAR (Selalu ada) ---
            Positioned.fill(
              child: Image.asset(
                backgroundImagePath,
                fit: BoxFit.cover,
              ),
            ),

            // --- LAPISAN 2: EFEK GELAP (Hanya jika 'noon.png') ---
            if (isNoon)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                ),
              ),

            // --- LAPISAN 3: EFEK WARNA DEFAULT (Selalu ada) ---
            Positioned.fill(
              child: Container(
                foregroundDecoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  backgroundBlendMode: BlendMode.overlay,
                ),
              ),
            ),

            // --- LAPISAN 4: KONTEN TEKS (Selalu ada) ---
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lokasi', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Icon(Icons.person, color: Colors.white.withOpacity(0.8), size: 20),
                        ),
                      ],
                    ),
                    Text(locationName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
                    const Spacer(), // Mendorong konten ke bawah
                    Text(displayTime, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Selanjutnya $displayName', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9))),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sisa waktu: $displayRemainingTime',
                              style: const TextStyle(fontSize: 14, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}