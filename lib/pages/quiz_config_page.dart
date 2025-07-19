import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/quiz_play.dart';
import 'package:quran_assistant/src/rust/api/quiz/quiz_fragment_completion.dart';
import 'package:quran_assistant/src/rust/api/quiz/verse_completion.dart';
import 'package:quran_assistant/src/rust/api/quiz/verse_order.dart';
import 'package:quran_assistant/src/rust/api/quiz/verse_previous.dart';
import 'package:quran_assistant/src/rust/data_loader/quiz_models.dart';
import 'package:quran_assistant/providers/quiz_provider.dart';
import 'package:quran_assistant/core/themes/app_theme.dart'; // Import AppTheme

class QuizConfigPage extends ConsumerStatefulWidget {
  final String selectedQuizType;

  const QuizConfigPage({super.key, required this.selectedQuizType});

  @override
  ConsumerState<QuizConfigPage> createState() => _QuizConfigPageState();
}

class _QuizConfigPageState extends ConsumerState<QuizConfigPage> {
  String selectedScopeType = 'all';
  final surahIdController = TextEditingController(text: '1');
  final juzStartController = TextEditingController(text: '1');
  final juzEndController = TextEditingController(text: '1');
  final questionCountController = TextEditingController(text: '5');

  late QuizScope scope;
  int questionCount = 5;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    scope = const QuizScope.all(); // default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quizSessionControllerProvider).resetAllQuizState();
    });
  }

  @override
  void dispose() {
    surahIdController.dispose();
    juzStartController.dispose();
    juzEndController.dispose();
    questionCountController.dispose();
    super.dispose();
  }

  void _onScopeChanged(String type) {
    setState(() {
      selectedScopeType = type;
      switch (type) {
        case 'surah':
          final id = int.tryParse(surahIdController.text.trim()) ?? 1;
          scope = QuizScope.bySurah(surahId: id);
          break;
        case 'juz':
          final start = int.tryParse(juzStartController.text.trim()) ?? 1;
          final end = int.tryParse(juzEndController.text.trim()) ?? start;

          if (start < 1 || end < 1 || start > end || end > 30) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Rentang Juz tidak valid",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            return;
          }

          debugPrint('Start: $start, End: $end');
          final juzList = <int>[start, end];

          scope = QuizScope.byJuz(juzNumbers: Uint32List.fromList(juzList));

          debugPrint('Juz yang dipilih: $juzList');
          break;
        default:
          scope = const QuizScope.all();
      }
    });
  }

  void _startQuiz() async {
    setState(() {
      _isLoading = true;
    });

    final count = int.tryParse(questionCountController.text.trim()) ?? 5;
    questionCount = count;

    debugPrint("🟦 Memulai _startQuiz");
    debugPrint("🟦 selectedScopeType: $selectedScopeType");
    debugPrint("🟦 scope.runtimeType: ${scope.runtimeType}");
    debugPrint("🟦 scope.toString(): $scope");
    debugPrint("🟦 Jumlah soal yang diminta: $count");

    final filter = QuizFilter(scope: scope, quizCount: count);

    QuizQuestions result;

    debugPrint("🟦 Filter terkirim ke Rust: $filter");

    try {
      switch (widget.selectedQuizType) {
        case 'fragment_completion':
          debugPrint("🟩 Menjalankan generateBatchFragmentQuizzes...");
          result = await generateBatchFragmentQuizzes(filter: filter);
          break;
        case 'verse_previous':
          debugPrint("🟩 Menjalankan generateBatchVersePreviousQuizzes...");
          result = await generateBatchVersePreviousQuizzes(filter: filter);
          break;
        case 'verse_order':
          debugPrint("🟩 Menjalankan generateBatchVerseOrderQuizzes...");
          result = await generateBatchVerseOrderQuizzes(filter: filter);
          break;
        default:
          debugPrint("🟩 Menjalankan generateBatchVerseCompletionQuizzes...");
          result = await generateBatchVerseCompletionQuizzes(filter: filter);
          break;
      }

      debugPrint("🟩 Fungsi Rust selesai dipanggil.");

      if (!mounted) {
        debugPrint("🟨 Widget tidak lagi mounted, abort.");
        return;
      }

      debugPrint("🟩 Jumlah soal yang dihasilkan: ${result.questions.length}");

      if (result.questions.isEmpty) {
        debugPrint("🟥 Tidak ada soal berhasil dihasilkan.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak ada soal berhasil dihasilkan.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      ref
          .read(quizSessionControllerProvider)
          .startNewQuizSession(
            questions: result.questions,
            quizType: widget.selectedQuizType,
            scope: scope,
            requestedQuestionCount: count,
            actualQuestionCount: result.questions.length,
          );

      debugPrint("✅ Navigasi ke QuizPlay dimulai...");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QuizPlay()),
      ).then((_) {
        debugPrint("🟪 QuizPlay ditutup, mengakhiri sesi kuis.");
        ref.read(quizSessionControllerProvider).endQuizSession();
      });
    } catch (e, stacktrace) {
      debugPrint('🟥 Error generating quiz: $e');
      debugPrint('🟥 Stacktrace: $stacktrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghasilkan kuis: $e',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Konfigurasi Kuis',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.iconColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Cakupan Soal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedScopeType,
            isExpanded: true, // Tambahkan properti ini
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(
                  'Semua Ayat',
                  style: TextStyle(color: AppTheme.textColor),
                ),
              ),
              DropdownMenuItem(
                value: 'juz',
                child: Text(
                  'Berdasarkan Juz',
                  style: TextStyle(color: AppTheme.textColor),
                ),
              ),
              DropdownMenuItem(
                value: 'surah',
                child: Text(
                  'Berdasarkan Surah',
                  style: TextStyle(color: AppTheme.textColor),
                ),
              ),
            ],
            onChanged: (val) => _onScopeChanged(val ?? 'all'),
            decoration: InputDecoration(
              labelText: 'Pilih Cakupan',
              labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
              hintStyle: TextStyle(color: AppTheme.secondaryTextColor),
            ),
            dropdownColor: AppTheme.cardColor,
            style: TextStyle(color: AppTheme.textColor),
            iconEnabledColor: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          if (selectedScopeType == 'surah') ...[
            TextField(
              controller: surahIdController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'ID Surah (1-114)',
                labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                hintStyle: TextStyle(color: AppTheme.secondaryTextColor),
              ),
              onChanged: (_) => _onScopeChanged('surah'),
            ),
            const SizedBox(height: 16),
          ],
          if (selectedScopeType == 'juz') ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: juzStartController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Juz Awal',
                      labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                      hintStyle: TextStyle(color: AppTheme.secondaryTextColor),
                    ),
                    onChanged: (_) => _onScopeChanged('juz'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: juzEndController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Juz Akhir',
                      labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                      hintStyle: TextStyle(color: AppTheme.secondaryTextColor),
                    ),
                    onChanged: (_) => _onScopeChanged('juz'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: questionCountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah Soal',
              labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
              hintStyle: TextStyle(color: AppTheme.secondaryTextColor),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: _isLoading
                ? const Text('Membuat Soal...')
                : const Text('Mulai Kuis'),
            onPressed: _isLoading ? null : _startQuiz,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
