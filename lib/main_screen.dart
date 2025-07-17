import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quran_assistant/pages/fts_search_page.dart';
import 'package:quran_assistant/pages/home_page.dart';
import 'package:quran_assistant/pages/quiz_page.dart';
import 'package:quran_assistant/pages/more_page.dart';
import 'package:quran_assistant/pages/quran_page.dart';
import 'package:quran_assistant/pages/statistics/quran_statistic_page.dart';
import 'package:quran_assistant/widgets/quran_navigation_widgets.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Daftar halaman yang akan ditampilkan, sesuai urutan BottomNavigationBar
  final List<Widget> _pages = [
    const HomePage(),
    const FtsSearchPage(),
    const QuranPage(),
    const QuizPage(),
    const MorePage(),
  ];

  // Daftar judul untuk AppBar
  final List<String> _appBarTitles = [
    'Quran App', // Untuk Beranda
    'Pencarian', // Untuk Pencarian
    'Quran',      // Untuk Quran
    'Kuis',       // Untuk Kuis
    'Lainnya',    // Untuk Lainnya
  ];

  // Daftar item navigasi kustom
  final List<CustomBottomNavigationItem> _navItems = [
    CustomBottomNavigationItem(
      label: 'Beranda',
      iconData: Icons.home_rounded,
    ),
    CustomBottomNavigationItem(
      label: 'Pencarian',
      iconData: Icons.search_rounded,
    ),
    CustomBottomNavigationItem(
      label: 'Quran',
      iconData: Icons.menu_book_rounded, // Menggunakan IconData untuk ikon Quran
      isProminent: true, // Set isProminent ke true untuk efek menonjol
    ),
    // Contoh penggunaan imagePath (jika Anda punya aset gambar di 'assets/icons/quiz.png')
    // CustomBottomNavigationItem(
    //   label: 'Kuis',
    //   imagePath: 'assets/icons/quiz.png',
    // ),
    CustomBottomNavigationItem(
      label: 'Kuis',
      iconData: Icons.lightbulb_outline_rounded,
    ),
    CustomBottomNavigationItem(
      label: 'Lainnya',
      iconData: Icons.menu_rounded,
    ),
  ];


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: CustomAppBar(
        title: _appBarTitles[_selectedIndex],
        // showSearch: _selectedIndex == 1,
        // showMenu: _selectedIndex == 0,
      ),
      body: SafeArea(
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemTapped,
        showMenuTitles: false, // Anda bisa mengubah ini menjadi false jika tidak ingin menampilkan judul
        items: _navItems, // Meneruskan daftar item navigasi kustom

      ),
    );
  }
}
