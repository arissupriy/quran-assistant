// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Impor MainScreen dari file barunya
import 'package:quran_assistant/splash_loader.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ WAJIB

  // RustEngineService().initEngine();
  // await GlyphCache().preloadAllGlyphs(); // Preload saat awal
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Assistant',
      theme: ThemeData(
        primaryColor: const Color(0xFF00796B), // Deep Teal
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
            .copyWith(secondary: const Color(0xFFE57373)), // Soft Coral
        
        scaffoldBackgroundColor: const Color(0xFFF0F4F8), // Light Blue-Gray, bersih

        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).copyWith(
          bodyLarge: const TextStyle(fontFamily: 'UthmaniHafs'), // Contoh penggunaan font Arab
          bodyMedium: const TextStyle(fontFamily: 'UthmaniHafs'), // Contoh penggunaan font Arab
        ),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00796B), // Deep Teal
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          // PERBAIKAN DI SINI: Background solid untuk BottomNavigationBar
          backgroundColor: Color(0xFFE0E5EA), // Warna abu-abu terang yang solid
          selectedItemColor: Color(0xFF00796B), // Deep Teal
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 8, // Beri sedikit bayangan untuk pemisahan
        ),
        useMaterial3: true,
      ),
      home: const SplashLoader(),
    );
  }
}


