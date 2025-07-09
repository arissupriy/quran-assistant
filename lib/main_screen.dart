// lib/main_screen.dart
import 'dart:ui'; // Import untuk ImageFilter
import 'package:flutter/material.dart';
// Jika masih menggunakan Riverpod
// Untuk GoogleFonts

// Impor halaman-halaman yang sudah dibuat
import 'package:quran_assistant/pages/home_page.dart';
import 'package:quran_assistant/pages/search_page.dart';
import 'package:quran_assistant/pages/quiz_page.dart';
import 'package:quran_assistant/pages/more_page.dart';

// Asumsi RustEngineService dan model sudah diinisialisasi dan diimpor di main.dart
// import 'package:quran_assistant/core/api/rust_engine_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0; // Indeks halaman yang aktif

  // Daftar halaman yang akan ditampilkan
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
      body: _pages[_selectedIndex], // Menampilkan halaman yang dipilih

      // Implementasi BottomNavigationBar dengan Frosted Glass
      bottomNavigationBar: ClipRRect( // ClipRRect untuk sudut membulat jika diinginkan
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Efek blur
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5), // Warna dasar transparan untuk efek
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.3), width: 0.5), // Border atas tipis
              ),
            ),
            child: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), // Rekomendasi ikon
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search_rounded), // Rekomendasi ikon
                  label: 'Pencarian',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.lightbulb_outline_rounded), // Rekomendasi ikon
                  label: 'Kuis',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_rounded), // Rekomendasi ikon (hamburger icon)
                  label: 'Lainnya',
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            ),
          ),
        ),
      ),
    );
  }
}