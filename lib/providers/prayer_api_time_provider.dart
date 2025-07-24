import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart'; // Diperlukan untuk TimeOfDay
import 'package:quran_assistant/core/models/prayer_data_model.dart'; // Import model data sholat

// Dummy data mentah sesuai format JSON yang Anda berikan
// Anda bisa mengubah ini menjadi null atau data kosong untuk menguji skenario "data tidak ditemukan"
final Map<String, dynamic>? _rawDummyPrayerData = {
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

// Provider yang mem-parse data mentah menjadi ParsedPrayerData.
// Mengembalikan null jika data mentah tidak ditemukan atau tidak valid.
// Di masa mendatang, ini akan diganti dengan FutureProvider untuk panggilan API nyata.
final dummyPrayerTimesProvider = Provider<ParsedPrayerData?>((ref) {
  if (_rawDummyPrayerData == null || _rawDummyPrayerData!['data'] == null) {
    return null; // Mengembalikan null jika tidak ada data
  }

  final data = _rawDummyPrayerData!['data'] as Map<String, dynamic>;
  final location = PrayerLocation.fromJson(data);
  final schedule = PrayerSchedule.fromJson(data['jadwal']);

  // Membuat daftar PrayerTime dari jadwal yang di-parse, diurutkan berdasarkan waktu
  final List<PrayerTime> prayers = [
    PrayerTime(name: 'Imsak', time: schedule.imsak),
    PrayerTime(name: 'Subuh', time: schedule.subuh),
    PrayerTime(name: 'Syuruq', time: schedule.terbit),
    PrayerTime(name: 'Dhuha', time: schedule.dhuha),
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

// Provider yang mengeluarkan DateTime.now() setiap detik untuk memicu pembaruan UI.
// Digunakan untuk membuat widget jadwal sholat otomatis refresh.
final timeTickerProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (count) => DateTime.now());
});
