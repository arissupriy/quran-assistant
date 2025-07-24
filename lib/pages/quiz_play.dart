import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/src/rust/data_loader/quiz_models.dart' as RustModels;
import 'package:quran_assistant/providers/quiz_provider.dart';
import 'package:quran_assistant/pages/quiz/quiz_summary_page.dart';
import 'package:quran_assistant/pages/quiz/quiz_verse_order_page.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';
import 'package:quran_assistant/utils/quiz_uitls.dart';

class QuizPlay extends ConsumerStatefulWidget {
  const QuizPlay({super.key});

  @override
  ConsumerState<QuizPlay> createState() => _QuizPlayState();
}

class _QuizPlayState extends ConsumerState<QuizPlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeInitializeVerseOrderUserOrder();
    });
  }

  void _maybeInitializeVerseOrderUserOrder() {
    final quizType = ref.read(quizSessionControllerProvider).quizType;
    final currentQuestion = ref.read(currentQuizQuestionProvider);
    final userOrder = ref.read(userOrderProvider);

    if (quizType == 'verse_order' &&
        currentQuestion != null &&
        currentQuestion.shuffledParts != null &&
        userOrder == null) {
      final indices = List<int>.generate(currentQuestion.shuffledParts!.length, (i) => i);
      ref.read(userOrderProvider.notifier).state = indices;
    }
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
        SnackBar(
          content: Text(
            'Silakan pilih jawaban terlebih dahulu.',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
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

    ref.invalidate(answerCheckedProvider);
    ref.invalidate(selectedOptionIndexProvider);
    ref.invalidate(userOrderProvider);

    if (currentIndex + 1 >= totalQuestions) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuizSummaryPage()),
      );
    } else {
      quizController.nextQuestion();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeInitializeVerseOrderUserOrder();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = ref.watch(currentQuizQuestionProvider);
    final currentIndex = ref.watch(currentQuestionIndexProvider);
    final questions = ref.watch(currentQuizQuestionsProvider);
    final selectedIndex = ref.watch(selectedOptionIndexProvider);
    final isAnswerChecked = ref.watch(answerCheckedProvider);
    final quizType = ref.watch(quizSessionControllerProvider).quizType;

    if (currentQuestion == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    final titleAppbar = quizType == 'verse_order'
        ? 'Urutkan Ayat'
        : quizType == 'verse_previous'
            ? 'Isi Bagian Ayat'
            : quizType == 'verse_completion'
                ? 'Lanjutkan Ayat'
                : quizType == 'fragment_completion'
                    ? 'Lengkapi Fragmen'
                    : 'Kuis';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: AppTheme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Akhiri Sesi Kuis?', style: TextStyle(color: AppTheme.textColor)),
              content: Text(
                'Anda akan keluar dari sesi kuis saat ini. Apakah Anda yakin? Progres sesi ini akan disimpan.',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Lanjutkan Kuis', style: TextStyle(color: AppTheme.primaryColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Akhiri Sesi', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(titleAppbar, style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: AppTheme.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.iconColor),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${currentIndex + 1}/${questions.length}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                ),
              ),
            ),
          ],
        ),
        body: Builder(
          builder: (_) {
            if (quizType == 'verse_order') {
              return const VerseOrderQuizPage();
            }
            return _buildStandardQuizView(
              context,
              currentQuestion,
              currentIndex,
              questions,
              selectedIndex,
              isAnswerChecked,
              quizType!,
            );
          },
        ),
      ),
    );
  }

  Widget _buildStandardQuizView(
    BuildContext context,
    RustModels.QuizQuestion currentQuestion,
    int currentIndex,
    List<RustModels.QuizQuestion> questions,
    int? selectedIndex,
    bool isAnswerChecked,
    String quizType,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Card(
                      color: AppTheme.backgroundColor,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2), width: 1),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            quizType == 'verse_previous'
                                ? '${removeArabicNumbers(currentQuestion.questionTextPart1)} ...'
                                : '${removeArabicNumbers(currentQuestion.questionTextPart1)} ______ ${removeArabicNumbers(currentQuestion.questionTextPart2)}',
                            style: TextStyle(
                              fontSize: 20,
                              height: 2,
                              fontFamily: 'UthmaniHafs',
                              color: AppTheme.textColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...currentQuestion.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;

                    final isSelected = index == selectedIndex;
                    final isCorrect = index == currentQuestion.correctAnswerIndex;

                    Color cardColor = AppTheme.cardColor;
                    Color textColor = AppTheme.textColor;
                    Color borderColor = Colors.grey.shade300;

                    if (isAnswerChecked) {
                      if (isCorrect) {
                        cardColor = Colors.green.shade100;
                        textColor = Colors.green.shade800;
                        borderColor = Colors.green.shade500;
                      } else if (isSelected) {
                        cardColor = Colors.red.shade100;
                        textColor = Colors.red.shade800;
                        borderColor = Colors.red.shade500;
                      }
                    } else if (isSelected) {
                      cardColor = AppTheme.primaryColor.withOpacity(0.1);
                      textColor = AppTheme.primaryColor;
                      borderColor = AppTheme.primaryColor;
                    }

                    return Align(
                      alignment: Alignment.centerRight,
                      child: Card(
                        color: cardColor,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor, width: 2),
                        ),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _onOptionSelected(index),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                removeArabicNumbers(option.text),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'UthmaniHafs',
                                  height: 1.6,
                                  color: textColor,
                                  fontWeight: isSelected && !isAnswerChecked
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: !isAnswerChecked
                ? ElevatedButton(
                    onPressed: selectedIndex == null ? null : _onCheckAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cek Jawaban'),
                  )
                : ElevatedButton(
                    onPressed: _onNextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      currentIndex + 1 < questions.length ? 'Soal Selanjutnya' : 'Selesai',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
