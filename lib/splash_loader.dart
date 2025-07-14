// lib/splash_loader.dart
import 'package:flutter/material.dart';
import 'package:quran_assistant/main_screen.dart';
import 'package:quran_assistant/utils/glyph_cache_utils.dart';

class SplashLoader extends StatefulWidget {
  const SplashLoader({super.key});

  @override
  State<SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<SplashLoader>
    with SingleTickerProviderStateMixin {
  bool _isReady = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _initApp();
  }

  Future<void> _initApp() async {
    // await RustEngineService().initEngine();

    // final glyphCache = GlyphCache();
    // await glyphCache.preloadAllGlyphs();

    // if (!mounted) return;
    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return const MainScreen();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF00796B), // Teal
              Color(0xFF004D40), // Darker Teal
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🌙 Logo atau Icon
              const Icon(
                Icons.menu_book_rounded,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),

              // 🕊️ Judul
              const Text(
                'Quran Assistant',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 40),

              // ⏳ Loading indicator modern
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return Transform.rotate(
                    angle: _controller.value * 6.3,
                    child: const Icon(
                      Icons.sync_rounded,
                      color: Colors.white70,
                      size: 32,
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // 💬 Status
              const Text(
                'Menyiapkan data Mushaf...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
