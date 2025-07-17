import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:quran_assistant/core/models/quiz_history.dart';
import 'package:quran_assistant/core/models/reading_session.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/engine/init_quran_engine.dart';
import 'package:quran_assistant/main_screen.dart';
import 'package:quran_assistant/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // WAJIB

  await RustLib.init();

  await Hive.initFlutter();

  // Daftarkan TypeAdapters yang digenerate oleh hive_generator
  Hive.registerAdapter(QuizSessionAdapter());
  Hive.registerAdapter(QuizAttemptAdapter());
  Hive.registerAdapter(HiveQuizOptionAdapter()); // Pastikan ini ada jika Anda menggunakannya
  Hive.registerAdapter(ReadingSessionAdapter());

  // Buka "boxes" (mirip tabel)
  await Hive.openBox<QuizSession>('quizSessions');
  await Hive.openBox<QuizAttempt>('quizAttempts');

  // Load Data
  await initQuranEngine(); // Inisialisasi Quran Engine

  FlutterError.onError = FlutterError.dumpErrorToConsole;

  runZonedGuarded(() {
    runApp(const ProviderScope(child: MyApp()));
  }, (Object error, StackTrace stack) {
    debugPrint("❗ Global error caught: $error");
    debugPrint("🧵 Stacktrace:\n$stack");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Menggunakan tema dari AppTheme
      home: const MainScreen(),
    );
  }
}
