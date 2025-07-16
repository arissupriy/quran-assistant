import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Definisi tema aplikasi untuk Quran Assistant
class AppTheme {
  // Warna primer aplikasi, menggunakan shade teal yang lebih gelap
  static const Color primaryColor = Color(0xFF00796B); // Deep Teal
  // Warna aksen/sekunder, diubah menjadi shade teal yang lebih cerah agar lebih harmonis
  static const Color secondaryColor = Color(0xFF1DE9B6); // Teal A400 - Lebih harmonis
  // Warna latar belakang utama aplikasi
  static const Color backgroundColor = Color(0xFFF0F4F8); // Light Greyish Blue
  // Warna latar belakang untuk kartu atau elemen yang ditinggikan
  static const Color cardColor = Colors.white;
  // Warna teks utama, untuk kontras yang baik dengan latar belakang terang
  static const Color textColor = Color(0xFF263238); // Dark Grey
  // Warna teks sekunder, untuk informasi tambahan atau teks yang kurang menonjol
  static const Color secondaryTextColor = Color(0xFF78909C); // Blue Grey
  // Warna untuk ikon (sudah disesuaikan di iterasi sebelumnya)
  static const Color iconColor = Color(0xFF4DB6AC); // Teal 200
  // Warna untuk bayangan, memberikan kedalaman pada elemen UI (ditingkatkan)
  static const Color shadowColor = Color(0x30000000); // Semi-transparent black, sedikit lebih gelap
  static const Color subtleShadowColor = Color(0x15000000); // Bayangan yang lebih halus

  // Definisi Gradien Primer
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF00796B), // primaryColor (Deep Teal)
      Color(0xFF009688), // Sedikit lebih terang dari primaryColor (Teal 500)
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Definisi Gradien Aksen (opsional, jika ingin gradien di secondaryColor)
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [
      Color(0xFF1DE9B6), // secondaryColor (Teal A400)
      Color(0xFF64FFDA), // Teal A700
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );


  // Mendefinisikan ThemeData untuk aplikasi
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
        .copyWith(secondary: secondaryColor),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    textTheme: GoogleFonts.interTextTheme().copyWith(
      bodyLarge: const TextStyle(fontFamily: 'UthmanicHafs'),
      bodyMedium: const TextStyle(fontFamily: 'UthmanicHafs'),
      displayLarge: const TextStyle(color: textColor),
      displayMedium: const TextStyle(color: textColor),
      displaySmall: const TextStyle(color: textColor),
      headlineMedium: const TextStyle(color: textColor),
      headlineSmall: const TextStyle(color: textColor),
      titleLarge: const TextStyle(color: textColor),
      titleMedium: const TextStyle(color: secondaryTextColor),
      titleSmall: const TextStyle(color: secondaryTextColor),
      bodySmall: const TextStyle(color: secondaryTextColor),
      labelLarge: const TextStyle(color: textColor),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondaryColor,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFE0E5EA),
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 6, // <--- Meningkatkan elevasi default Card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Sudut membulat pada card
      ),
      shadowColor: shadowColor, // <--- Menggunakan shadowColor yang lebih terlihat
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[200],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    iconTheme: const IconThemeData(
      color: iconColor,
    ),
    useMaterial3: true,
  );
}
