import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ==== Warna dasar ====
  static const Color primaryColor = Color(0xFF00796B); // Deep Teal
  static const Color secondaryColor = Color(0xFF1DE9B6); // Teal A400
  static const Color backgroundColor = Color(0xFFF0F4F8); // Light Greyish Blue
  static const Color cardColor = Colors.white;

  // ==== Warna teks ====
  static const Color textColor = Color(0xFF263238); // Dark Grey
  static const Color secondaryTextColor = Color(0xFF78909C); // Blue Grey

  // ==== Ikon & efek ====
  static const Color iconColor = Color(0xFF4DB6AC); // Teal 200
  static const Color shadowColor = Color(0x30000000); // Semi-transparent black
  static const Color subtleShadowColor = Color(0x15000000); // Lembut

  // ==== Gradien ====
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00796B), Color(0xFF009688)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFF1DE9B6), Color(0xFF64FFDA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==== Warna tambahan ====
  static const Color surfaceVariant = Color(0xFFF8F9FA); // untuk container ringan
  static const Color borderColor = Color(0xFFE0E0E0); // untuk outline lembut
  static const Color tooltipBackground = Color(0xFF37474F); // abu gelap
  static const Color tooltipText = Colors.white;

  // ==== Font ====
  static const String arabFontFamily = 'UthmaniHafs';

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(
      secondary: secondaryColor,
      background: backgroundColor,
      surface: cardColor,
    ),

    // ==== Text Theme ====
    textTheme: GoogleFonts.interTextTheme().copyWith(
      bodyLarge: const TextStyle(
        fontFamily: arabFontFamily,
        color: textColor,
        fontSize: 16,
      ),
      bodyMedium: const TextStyle(
        fontFamily: arabFontFamily,
        color: textColor,
        fontSize: 14,
      ),
      titleLarge: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: textColor,
      ),
      titleMedium: const TextStyle(
        color: secondaryTextColor,
        fontSize: 16,
      ),
      labelLarge: const TextStyle(
        color: textColor,
      ),
    ),

    // ==== AppBar ====
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    // ==== FAB ====
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: secondaryColor,
      foregroundColor: Colors.white,
    ),

    // ==== Bottom Nav ====
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFE0E5EA),
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // ==== Cards ====
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: shadowColor,
    ),

    // ==== Buttons ====
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // ==== Input Field ====
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    ),

    // ==== Icon ====
    iconTheme: const IconThemeData(color: iconColor),

    // ==== Tooltip ====
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: tooltipBackground,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      textStyle: TextStyle(
        color: tooltipText,
        fontSize: 12,
      ),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    useMaterial3: true,
  );
}
