// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Impor MainScreen dari file barunya
import 'package:quran_assistant/main_screen.dart'; 

// Asumsi RustEngineService dan model sudah diimpor jika diperlukan untuk initEngine()
import 'package:quran_assistant/core/api/rust_engine_service.dart';

void main() {
  RustEngineService().initEngine();
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
      home: const MainScreen(),
    );
  }
}

// MainScreen kini ada di file main_screen.dart yang terpisah
// lib/main_screen.dart akan memiliki kode di bawah ini

/*
// main_screen.dart (konten akan sama seperti sebelumnya, tapi tanpa efek blur di bottomNavigationBar)
import 'dart:ui'; // Masih diimpor karena efek blur bisa dipakai di tempat lain
import 'package:flutter/material.dart';
// ... (impor halaman lainnya)

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    SearchPage(),
    QuizPage(),
    MorePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quran Assistant'),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar( // PERBAIKAN: Hapus ClipRRect dan BackdropFilter
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Pencarian',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline_rounded),
            label: 'Kuis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_rounded),
            label: 'Lainnya',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
*/