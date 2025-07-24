import 'package:flutter/material.dart';

// Model untuk satu waktu sholat
class PrayerTime {
  final String name;
  final TimeOfDay time;

  PrayerTime({required this.name, required this.time});
}

// Model untuk data jadwal sholat lengkap
class PrayerSchedule {
  final String tanggal;
  final TimeOfDay imsak; // Tambahkan properti imsak
  final TimeOfDay subuh;
  final TimeOfDay terbit; // Syuruq
  final TimeOfDay dhuha;
  final TimeOfDay dzuhur;
  final TimeOfDay ashar;
  final TimeOfDay maghrib;
  final TimeOfDay isya;
  final String date;

  PrayerSchedule({
    required this.tanggal,
    required this.imsak, // Wajib di konstruktor
    required this.subuh,
    required this.terbit,
    required this.dhuha,
    required this.dzuhur,
    required this.ashar,
    required this.maghrib,
    required this.isya,
    required this.date,
  });

  // Helper untuk mengonversi string "HH:mm" menjadi TimeOfDay
  static TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  factory PrayerSchedule.fromJson(Map<String, dynamic> json) {
    return PrayerSchedule(
      tanggal: json['tanggal'],
      imsak: _parseTime(json['imsak']), // Parse imsak
      subuh: _parseTime(json['subuh']),
      terbit: _parseTime(json['terbit']),
      dhuha: _parseTime(json['dhuha']),
      dzuhur: _parseTime(json['dzuhur']),
      ashar: _parseTime(json['ashar']),
      maghrib: _parseTime(json['maghrib']),
      isya: _parseTime(json['isya']),
      date: json['date'],
    );
  }
}

// Model untuk data lokasi
class PrayerLocation {
  final String id;
  final String lokasi;
  final String daerah;

  PrayerLocation({
    required this.id,
    required this.lokasi,
    required this.daerah,
  });

  factory PrayerLocation.fromJson(Map<String, dynamic> json) {
    return PrayerLocation(
      id: json['id'],
      lokasi: json['lokasi'],
      daerah: json['daerah'],
    );
  }
}

// Model utama untuk menyimpan semua data sholat yang relevan
class ParsedPrayerData {
  final PrayerLocation location;
  final PrayerSchedule schedule;
  final List<PrayerTime> prayerTimesList; // Daftar PrayerTime yang sudah diurutkan

  ParsedPrayerData({
    required this.location,
    required this.schedule,
    required this.prayerTimesList,
  });
}
