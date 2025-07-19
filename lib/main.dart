import 'dart:async';

import 'package:flutter/foundation.dart';
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
  // Set untuk membuat zone errors menjadi non-fatal untuk mengatasi zone mismatch
  BindingBase.debugZoneErrorsAreFatal = false;
  
  // Enhanced error handling untuk Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🐛 Flutter Error: ${details.exception}');
    debugPrint('🧵 Stack trace: ${details.stack}');
    
    // Handle image decoding errors specifically
    if (details.exception.toString().contains('Failed to decode image') ||
        details.exception.toString().contains('ImageDecoder')) {
      debugPrint('🖼️ Image decoding error - this is likely due to corrupted image data');
    }
    
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(() async {
    // Pastikan binding diinisialisasi dalam zone yang sama
    WidgetsFlutterBinding.ensureInitialized();
    
    try {
      await RustLib.init();
      debugPrint('✅ RustLib initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize RustLib: $e');
      rethrow;
    }

    try {
      await initQuranEngine(); // Inisialisasi Quran Engine
      debugPrint('✅ Quran Engine initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Quran Engine: $e');
      rethrow;
    }

    try {
      await Hive.initFlutter();
      debugPrint('✅ Hive initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Hive: $e');
      rethrow;
    }

    try {
      // Daftarkan TypeAdapters yang digenerate oleh hive_generator
      Hive.registerAdapter(QuizSessionAdapter());
      Hive.registerAdapter(QuizAttemptAdapter());
      Hive.registerAdapter(HiveQuizOptionAdapter()); // Pastikan ini ada jika Anda menggunakannya
      Hive.registerAdapter(ReadingSessionAdapter());
      debugPrint('✅ Hive adapters registered successfully');
    } catch (e) {
      debugPrint('❌ Failed to register Hive adapters: $e');
      rethrow;
    }

    try {
      // Buka "boxes" (mirip tabel) with error handling
      await Hive.openBox<QuizSession>('quizSessions');
      await Hive.openBox<QuizAttempt>('quizAttempts');
      await Hive.openBox<ReadingSession>('reading_sessions'); // Add reading sessions box
      debugPrint('✅ Hive boxes opened successfully');
    } catch (e) {
      debugPrint('❌ Failed to open Hive boxes: $e');
      // Try to recover by clearing corrupted boxes
      try {
        await Hive.deleteBoxFromDisk('quizSessions');
        await Hive.deleteBoxFromDisk('quizAttempts');
        await Hive.deleteBoxFromDisk('reading_sessions');
        debugPrint('🔄 Cleared corrupted Hive boxes, retrying...');
        
        await Hive.openBox<QuizSession>('quizSessions');
        await Hive.openBox<QuizAttempt>('quizAttempts');
        await Hive.openBox<ReadingSession>('reading_sessions');
        debugPrint('✅ Hive boxes recreated successfully');
      } catch (recoveryError) {
        debugPrint('❌ Failed to recover Hive boxes: $recoveryError');
        rethrow;
      }
    }

    debugPrint('🚀 Starting app...');
    runApp(const ProviderScope(child: MyApp()));
    
  }, (Object error, StackTrace stack) {
    debugPrint("❗ Global error caught: $error");
    debugPrint("🧵 Stacktrace:\n$stack");
    
    // Log additional context
    debugPrint("🔍 Error type: ${error.runtimeType}");
    if (error is FlutterError) {
      debugPrint("🔍 Flutter error details: ${error.toStringShort()}");
    }
    
    // Handle specific error types
    if (error.toString().contains('ImageDecoder') || 
        error.toString().contains('Failed to decode image')) {
      debugPrint("🖼️ Image decoding error detected - app will continue running");
    }
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
      
      // Enhanced error handling untuk build context
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          debugPrint('🚨 Widget Error: ${errorDetails.exception}');
          
          // Handle image errors gracefully
          if (errorDetails.exception.toString().contains('Failed to decode image') ||
              errorDetails.exception.toString().contains('ImageDecoder')) {
            return Material(
              child: Container(
                color: Colors.grey.shade100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Image loading error',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Default error widget for other errors
          return Material(
            child: Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                  const SizedBox(height: 16),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please restart the app',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red.shade600,
                    ),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Debug info: ${errorDetails.exception}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        };
        return child ?? const SizedBox();
      },
    );
  }
}