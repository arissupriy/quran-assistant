import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quran_assistant/core/models/prayer_data_model.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';

// Dummy data mentah sesuai format JSON yang Anda berikan
final Map<String, dynamic> _rawDummyPrayerData = {
  "status": true,
  "data": {
    "id": "1609",
    "lokasi": "KAB. KEDIRI",
    "daerah": "JAWA TIMUR",
    "koordinat": {
      "lat": -7.819372222222222,
      "lon": 112.04153611111111,
      "lintang": "7° 49' 9.74\" S",
      "bujur": "112° 02' 29.53\" E"
    },
    "jadwal": {
      "tanggal": "Rabu, 23/06/2021",
      "imsak": "04:13",
      "subuh": "04:23",
      "terbit": "05:41", // Ini akan digunakan sebagai Syuruq
      "dhuha": "06:10",
      "dzuhur": "11:38",
      "ashar": "14:57",
      "maghrib": "17:27",
      "isya": "18:42",
      "date": "2021-06-23"
    }
  }
};

// Dummy data provider yang mem-parse data mentah menjadi ParsedPrayerData
final dummyPrayerTimesProvider = Provider<ParsedPrayerData>((ref) {
  final data = _rawDummyPrayerData['data'] as Map<String, dynamic>;
  final location = PrayerLocation.fromJson(data);
  final schedule = PrayerSchedule.fromJson(data['jadwal']);

  // Membuat daftar PrayerTime dari jadwal yang di-parse, termasuk Imsak di awal
  final List<PrayerTime> prayers = [
    PrayerTime(name: 'Imsak', time: schedule.imsak), // Tambahkan Imsak di sini
    PrayerTime(name: 'Subuh', time: schedule.subuh),
    PrayerTime(name: 'Syuruq', time: schedule.terbit), // Menggunakan 'terbit' sebagai Syuruq
    PrayerTime(name: 'Dhuha', time: schedule.dhuha), // Menggunakan 'dhuha'
    PrayerTime(name: 'Dzuhur', time: schedule.dzuhur),
    PrayerTime(name: 'Ashar', time: schedule.ashar),
    PrayerTime(name: 'Maghrib', time: schedule.maghrib),
    PrayerTime(name: 'Isya', time: schedule.isya),
  ];

  return ParsedPrayerData(
    location: location,
    schedule: schedule,
    prayerTimesList: prayers,
  );
});

// Provider yang mengeluarkan DateTime.now() setiap detik untuk memicu pembaruan UI
final timeTickerProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (count) => DateTime.now());
});


class PrayerTimesWidget extends ConsumerWidget {
  const PrayerTimesWidget({super.key});

  // Helper untuk menghitung sisa waktu ke sholat berikutnya
  String _getTimeRemaining(DateTime targetTime) {
    final now = DateTime.now();
    Duration remaining = targetTime.difference(now);

    // Jika waktu target sudah lewat hari ini, hitung untuk besok
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

  // Helper untuk mendapatkan path gambar latar belakang lokal berdasarkan waktu
  String _getBackgroundImagePath(List<PrayerTime> prayers, DateTime now) {
    // Helper untuk mendapatkan objek DateTime untuk waktu sholat hari ini
    DateTime getTodayPrayerTime(String name) {
      final prayer = prayers.firstWhere((p) => p.name == name);
      return DateTime(now.year, now.month, now.day, prayer.time.hour, prayer.time.minute);
    }

    final imsakTime = getTodayPrayerTime('Imsak'); // Dapatkan waktu Imsak
    final subuhTime = getTodayPrayerTime('Subuh');
    final syuruqTime = getTodayPrayerTime('Syuruq');
    final dhuhaTime = getTodayPrayerTime('Dhuha');
    final asrTime = getTodayPrayerTime('Ashar');
    final maghribTime = getTodayPrayerTime('Maghrib');
    final ishaTime = getTodayPrayerTime('Isya');

    // Logika pemilihan gambar berdasarkan waktu
    if (now.isAfter(ishaTime) || now.isBefore(imsakTime)) { // Malam: Setelah Isya ATAU sebelum Imsak
      return 'assets/images/night.png';
    } else if (now.isAfter(imsakTime) && now.isBefore(dhuhaTime)) { // Matahari Terbit: Setelah Imsak dan sebelum Dhuha
      return 'assets/images/sunrise.png';
    } else if (now.isAfter(dhuhaTime) && now.isBefore(asrTime)) { // Siang: Setelah Dhuha dan sebelum Ashar
      return 'assets/images/noon.png';
    } else if (now.isAfter(asrTime) && now.isBefore(ishaTime)) { // Matahari Terbenam: Setelah Ashar dan sebelum Isya
      return 'assets/images/sunset.png';
    }
    
    return 'assets/images/noon.png'; // Default ke siang (seharusnya tidak tercapai)
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mengawasi timeTickerProvider untuk memicu rebuild setiap detik
    final AsyncValue<DateTime> timeAsync = ref.watch(timeTickerProvider);

    final ParsedPrayerData prayerData = ref.watch(dummyPrayerTimesProvider);
    final List<PrayerTime> prayers = prayerData.prayerTimesList;
    final String locationName = '${prayerData.location.lokasi}, ${prayerData.location.daerah}';

    // Dapatkan waktu saat ini
    final now = timeAsync.value ?? DateTime.now();

    // Konversi TimeOfDay ke DateTime untuk hari ini untuk semua waktu sholat
    List<DateTime> todayPrayerTimes = prayers.map((p) => 
      DateTime(now.year, now.month, now.day, p.time.hour, p.time.minute)
    ).toList();

    // Tentukan waktu sholat berikutnya
    int nextPrayerIndex = -1;
    for (int i = 0; i < todayPrayerTimes.length; i++) {
      if (todayPrayerTimes[i].isAfter(now)) {
        nextPrayerIndex = i;
        break;
      }
    }

    PrayerTime nextPrayer;
    DateTime nextPrayerDateTime;
    
    if (nextPrayerIndex != -1) {
      // Ada sholat berikutnya hari ini
      nextPrayer = prayers[nextPrayerIndex];
      nextPrayerDateTime = todayPrayerTimes[nextPrayerIndex];
    } else {
      // Semua sholat hari ini sudah lewat, sholat berikutnya adalah Imsak besok
      nextPrayer = prayers.firstWhere((p) => p.name == 'Imsak'); // Pastikan Imsak diambil
      nextPrayerDateTime = DateTime(now.year, now.month, now.day, nextPrayer.time.hour, nextPrayer.time.minute).add(const Duration(days: 1));
    }

    final String timeRemainingText = _getTimeRemaining(nextPrayerDateTime);
    final String backgroundImagePath = _getBackgroundImagePath(prayers, now);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        image: DecorationImage(
          image: AssetImage(backgroundImagePath), // Menggunakan path aset lokal
          fit: BoxFit.cover,
          opacity: 1.0,
          colorFilter: ColorFilter.mode(
            AppTheme.primaryColor.withOpacity(0.4),
            BlendMode.overlay,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lokasi',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
              ),
              // Ikon profil dummy
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(Icons.person, color: Colors.white.withOpacity(0.8), size: 20),
              ),
            ],
          ),
          Text(
            locationName, // Menampilkan lokasi dari data dummy
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          const SizedBox(height: 20),
          // Bagian ini menampilkan waktu sholat berikutnya
          Text(
            nextPrayer.time.format(context), // Waktu sholat berikutnya
            style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            'Selanjutnya ${nextPrayer.name}', // Nama sholat berikutnya
            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.9)),
          ),
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
                Icon(Icons.access_time_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sisa waktu: $timeRemainingText', // Teks sisa waktu
                    style: TextStyle(fontSize: 14, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
