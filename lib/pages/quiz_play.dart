import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/data_loader/quiz_models.dart'
    as RustModels;
import 'package:quran_assistant/providers/quiz_provider.dart';
import 'package:quran_assistant/pages/quiz/quiz_summary_page.dart';

class QuizPlay extends ConsumerStatefulWidget {
  const QuizPlay({super.key});

  @override
  ConsumerState<QuizPlay> createState() => _QuizPlayState();
}

class _QuizPlayState extends ConsumerState<QuizPlay> {
  @override
  void initState() {
    super.initState();
  }

  void _onOptionSelected(int index) {
    final isAnswerChecked = ref.read(answerCheckedProvider);
    if (isAnswerChecked) return;

    ref.read(selectedOptionIndexProvider.notifier).state = index;
  }

  void _onCheckAnswer() {
    final selectedIndex = ref.read(selectedOptionIndexProvider);
    if (selectedIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih jawaban terlebih dahulu.')),
      );
      return;
    }

    ref.read(answerCheckedProvider.notifier).state = true;
    ref.read(quizSessionControllerProvider).recordQuizAttempt();
  }

  void _onNextQuestion() {
    final quizController = ref.read(quizSessionControllerProvider);
    final currentIndex = ref.read(currentQuestionIndexProvider);
    final totalQuestions = ref.read(currentQuizQuestionsProvider).length;

    if (currentIndex + 1 >= totalQuestions) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuizSummaryPage()),
      ).then((_) {
        ref.read(quizSessionControllerProvider).endQuizSession();
      });
    } else {
      quizController.nextQuestion();
    }
  }

  Future<bool> _onWillPop() async {
    // Metode ini tidak lagi digunakan oleh PopScope
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Akhiri Sesi Kuis?'),
          content: const Text(
            'Anda akan keluar dari sesi kuis saat ini. Apakah Anda yakin?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Lanjutkan Kuis'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Akhiri Sesi'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await ref.read(quizSessionControllerProvider).endQuizSession();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = ref.watch(currentQuizQuestionProvider);
    final currentIndex = ref.watch(currentQuestionIndexProvider);
    final questions = ref.watch(currentQuizQuestionsProvider);
    final selectedIndex = ref.watch(selectedOptionIndexProvider);
    final isAnswerChecked = ref.watch(answerCheckedProvider);

    if (currentQuestion == null) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: AppBar(title: Text('Memuat Kuis...')),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      // Menggunakan PopScope untuk Flutter 3.16+
      canPop: false, // Secara default tidak mengizinkan pop
      onPopInvoked: (didPop) async {
        if (didPop) return; // Jika sistem sudah menangani pop, abaikan

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Akhiri Sesi Kuis?'),
              content: const Text(
                'Anda akan keluar dari sesi kuis saat ini. Apakah Anda yakin? Progres sesi ini akan disimpan.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Lanjutkan Kuis'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Akhiri Sesi'),
                ),
              ],
            );
          },
        );

        if (confirm == true) {
          await ref.read(quizSessionControllerProvider).endQuizSession();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kuis'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${currentIndex + 1}/${questions.length}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start, // Tetap start untuk widget lain
            children: [
              // Progres soal (tetap rata kiri)
              Text(
                'Soal ${currentIndex + 1}/${questions.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // --- TEKS PERTANYAAN (RATA KANAN) ---
              // Menggunakan Directionality untuk memastikan teks Arab rata kanan
              Directionality(
                textDirection: TextDirection.rtl, // Penting untuk teks Arab
                child: Text(
                  '${currentQuestion.questionTextPart1} _____ ${currentQuestion.questionTextPart2}',
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.5,
                  ), // Perbesar ukuran font agar lebih jelas
                  textAlign: TextAlign.right, // Rata kanan
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView.builder(
                  itemCount: currentQuestion.options.length,
                  itemBuilder: (context, index) {
                    final option = currentQuestion.options[index];
                    final isSelected = index == selectedIndex;
                    final isCorrect =
                        (index == currentQuestion.correctAnswerIndex);

                    Color color = Colors.grey[200]!;
                    if (isAnswerChecked) {
                      if (isCorrect) {
                        color = Colors.green[300]!;
                      } else if (isSelected) {
                        color = Colors.red[300]!;
                      }
                    } else if (isSelected) {
                      color = Colors.blue[200]!;
                    }

                    return GestureDetector(
                      onTap: () => _onOptionSelected(index),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        // --- TEKS OPSI (RATA KANAN) ---
                        // Menggunakan Directionality untuk memastikan teks Arab rata kanan
                        child: Directionality(
                          textDirection:
                              TextDirection.rtl, // Penting untuk teks Arab
                          child: Text(
                            option.text,
                            style: const TextStyle(
                              fontSize: 18,
                            ), // Perbesar ukuran font
                            textAlign: TextAlign.right, // Rata kanan
                          ),
                        ),
                        // --- AKHIR TEKS OPSI ---
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: !isAnswerChecked
                    ? ElevatedButton(
                        onPressed: selectedIndex == null
                            ? null
                            : _onCheckAnswer,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cek Jawaban'),
                      )
                    : ElevatedButton(
                        onPressed: _onNextQuestion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          currentIndex + 1 < questions.length
                              ? 'Soal Selanjutnya'
                              : 'Selesai',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
