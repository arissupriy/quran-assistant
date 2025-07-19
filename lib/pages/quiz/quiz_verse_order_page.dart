import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_assistant/pages/quiz/quiz_summary_page.dart';
import 'package:quran_assistant/providers/quiz_provider.dart';
import 'package:quran_assistant/core/themes/app_theme.dart';

class VerseOrderQuizPage extends ConsumerStatefulWidget {
  const VerseOrderQuizPage({super.key});

  @override
  ConsumerState<VerseOrderQuizPage> createState() => _VerseOrderQuizPageState();
}

class _VerseOrderQuizPageState extends ConsumerState<VerseOrderQuizPage> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentQuestion = ref.read(currentQuizQuestionProvider);
        final userOrder = ref.read(userOrderProvider);

        if (currentQuestion != null &&
            currentQuestion.shuffledParts != null &&
            userOrder == null) {
          final initialOrder =
              currentQuestion.shuffledParts!.map((e) => currentQuestion.shuffledParts!.indexOf(e)).toList();
          ref.read(userOrderProvider.notifier).state = initialOrder;
        }
      });

      _initialized = true;
    }
  }

  void _onReorder(int oldIndex, int newIndex, List<String> userOrder, List<String> shuffledVerses) {
    final updated = List<String>.from(userOrder);
    if (newIndex > oldIndex) newIndex--;
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    final newOrderIndices = updated.map((e) => shuffledVerses.indexOf(e)).toList();
    ref.read(userOrderProvider.notifier).state = newOrderIndices;
  }

  void _onSubmit() {

    ref.read(answerCheckedProvider.notifier).state = true;
    ref.read(quizSessionControllerProvider).recordQuizAttempt();
  
    debugPrint('User order submitted: ${ref.read(userOrderProvider)}');
    debugPrint('Correct order: ${ref.read(currentQuizQuestionProvider)?.correctOrderIndices}');
    debugPrint('Shuffled verses: ${ref.read(currentQuizQuestionProvider)?.shuffledParts}');
    debugPrint('Current question index: ${ref.read(currentQuestionIndexProvider)}');
  }

  void _onNext() {
    final index = ref.read(currentQuestionIndexProvider);
    final total = ref.read(currentQuizQuestionsProvider).length;

    if (index + 1 >= total) {
      ref.read(quizSessionControllerProvider).endQuizSession();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const QuizSummaryPage()),
      );
    } else {
      // Invalidate agar state tidak bocor ke soal berikutnya
      ref.invalidate(userOrderProvider);
      ref.invalidate(answerCheckedProvider);
      ref.read(quizSessionControllerProvider).nextQuestion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = ref.watch(currentQuizQuestionProvider);
    final isAnswerChecked = ref.watch(answerCheckedProvider);
    final userOrderState = ref.watch(userOrderProvider);

    if (currentQuestion == null || currentQuestion.shuffledParts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final shuffledVerses = currentQuestion.shuffledParts!;
    final correctOrder = currentQuestion.correctOrderIndices ?? [];

    // Fallback untuk userOrder jika belum diinisialisasi (safety)
    final userOrder = userOrderState != null
        ? userOrderState.map((i) => shuffledVerses[i]).toList()
        : shuffledVerses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Urutkan Ayat'),
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.textColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                itemCount: userOrder.length,
                onReorder: (oldIndex, newIndex) =>
                    _onReorder(oldIndex, newIndex, userOrder, shuffledVerses),
                itemBuilder: (context, index) {
                  final verse = userOrder[index];

                  bool isCorrect = false;
                  if (isAnswerChecked &&
                      index < correctOrder.length &&
                      shuffledVerses.contains(verse)) {
                    final expected = correctOrder[index];
                    isCorrect = shuffledVerses.indexOf(verse) == expected;
                  }

                  return Card(
                    key: ValueKey(verse),
                    color: isAnswerChecked
                        ? (isCorrect ? Colors.green[100] : Colors.red[100])
                        : null,
                    child: ListTile(
                      title: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          verse,
                          style: const TextStyle(fontFamily: 'UthmaniHafs'),
                        ),
                      ),
                      trailing: const Icon(Icons.drag_handle),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAnswerChecked ? _onNext : _onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAnswerChecked
                      ? AppTheme.secondaryColor
                      : AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(isAnswerChecked ? 'Soal Selanjutnya' : 'Cek Jawaban'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
