// The original content is temporarily commented out to allow generating a self-contained demo - feel free to uncomment later.

// // lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran_assistant/core/models/quiz_history.dart';
import 'package:quran_assistant/engine/init_quran_engine.dart';
import 'package:quran_assistant/main_screen.dart';

// Impor MainScreen dari file barunya

import 'package:quran_assistant/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ WAJIB


  await RustLib.init();

  await Hive.initFlutter();

  // Daftarkan TypeAdapters yang digenerate oleh hive_generator
  Hive.registerAdapter(QuizSessionAdapter());
  Hive.registerAdapter(QuizAttemptAdapter());
  Hive.registerAdapter(HiveQuizOptionAdapter()); // Jika Anda membuat adapter untuk itu

  // Buka "boxes" (mirip tabel)
  await Hive.openBox<QuizSession>('quizSessions');
  await Hive.openBox<QuizAttempt>('quizAttempts');

 

  
  // Lakukan Reset Data

  // Load Data
  await initQuranEngine(); // Inisialisasi Quran Engine
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
      home: MainScreen(),
    );
  }
}
//
//
//

// import 'package:flutter/material.dart';
// import 'package:quran_assistant/src/rust/api/simple.dart';
// import 'package:quran_assistant/src/rust/frb_generated.dart';

// Future<void> main() async {
//   await RustLib.init();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
//         body: Center(
//           child: Text(
//             'Action: Call Rust `greet("Tom")`\nResult: `${greet(name: "Tom")}`',
//           ),
//         ),
//       ),
//     );
//   }
// }
