import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/quiz.dart';
import '../../models/book.dart';

class QuizScreen extends StatefulWidget {
  final String bookId;
  const QuizScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Quiz? _quiz;
  Book? _book;
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  bool _hasAnswered = false;
  int _score = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_quiz == null && _isLoading) {
      _loadQuiz();
    }
  }

  void _loadQuiz() async {
    final langCode = AppLocalizations.of(context)!.locale.languageCode;
    final quiz = await AppLocator.db.fetchQuizForBook(widget.bookId, langCode);
    Book? book;
    try {
      book = AppLocator.db.books.firstWhere((b) => b.id == widget.bookId);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _quiz = quiz;
        _book = book;
        _isLoading = false;
      });
    }
  }

  void _selectOption(int index) {
    if (_hasAnswered) return;
    setState(() {
      _selectedOptionIndex = index;
    });
  }

  void _submitAnswer(int correctIndex) {
    if (_selectedOptionIndex == null || _hasAnswered) return;
    setState(() {
      _hasAnswered = true;
      if (_selectedOptionIndex == correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_quiz == null) return;
    if (_currentQuestionIndex < _quiz!.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
        _hasAnswered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() async {
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      // Reward user with activity point
      await AppLocator.auth.recordActivity();
      await AppLocator.auth.addCompletedBook(widget.bookId);
    }
    _showQuizResult();
  }

  void _showQuizResult() {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final total = _quiz?.questions.length ?? 0;
    final percent = total > 0 ? (_score / total * 100).round() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(localizations.translate('quiz_completed'), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: Colors.orangeAccent, size: 48),
              ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 16),
              Text(
                localizations.translate('your_score')
                    .replaceAll('{score}', '$_score')
                    .replaceAll('{total}', '$total'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.translate('quiz_score_desc')
                    .replaceAll('{percent}', '$percent'),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Dialog
                  Navigator.of(context).pop(); // Screen
                },
                child: Text(localizations.translate('return_to_summary')),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_quiz == null || _quiz!.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.translate('quiz'))),
        body: Center(child: Text(localizations.translate('no_quizzes'))),
      );
    }

    final question = _quiz!.questions[_currentQuestionIndex];
    final choices = question.choices;
    final correctIndex = question.correctOptionIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text('${localizations.translate('quiz')} (${_currentQuestionIndex + 1}/${_quiz!.questions.length})'),
      ),
      body: Stack(
        children: [
          // Blurred Background Cover Image
          if (_book != null && _book!.coverImageUrl.isNotEmpty) ...[
            Positioned.fill(
              child: Image.network(
                _book!.coverImageUrl,
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  color: theme.colorScheme.surface.withOpacity(0.85),
                ),
              ),
            ),
          ],
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress indicators
                LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / _quiz!.questions.length,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                ).animate().fade(duration: 400.ms),
                const SizedBox(height: 32),

                // Question Text
                Text(
                  question.questionText,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                ).animate(key: ValueKey('q_$_currentQuestionIndex'))
                 .slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
                 .fadeIn(duration: 400.ms),
                const SizedBox(height: 24),

                // Choices list
                Expanded(
                  child: ListView.builder(
                itemCount: choices.length,
                itemBuilder: (context, idx) {
                  final choice = choices[idx];
                  final isSelected = _selectedOptionIndex == idx;
                  
                  Color cardBg = theme.cardTheme.color!;
                  Color borderCol = Colors.grey.withOpacity(0.2);

                  if (_hasAnswered) {
                    if (idx == correctIndex) {
                      cardBg = Colors.green.withOpacity(0.12);
                      borderCol = Colors.green;
                    } else if (isSelected && idx != correctIndex) {
                      cardBg = Colors.red.withOpacity(0.12);
                      borderCol = Colors.red;
                    }
                  } else if (isSelected) {
                    borderCol = theme.colorScheme.secondary;
                    cardBg = theme.colorScheme.secondary.withOpacity(0.05);
                  }

                  Widget choiceWidget = GestureDetector(
                    onTap: () => _selectOption(idx),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol, width: isSelected || _hasAnswered ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              choice,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected || (_hasAnswered && idx == correctIndex)
                                    ? theme.colorScheme.secondary
                                    : null,
                              ),
                            ),
                          ),
                          if (_hasAnswered) ...[
                            if (idx == correctIndex)
                              const Icon(Icons.check_circle, color: Colors.green)
                            else if (isSelected && idx != correctIndex)
                              const Icon(Icons.cancel, color: Colors.red),
                          ],
                        ],
                      ),
                    ),
                  );

                  Widget animatedChoice = choiceWidget;
                  if (_hasAnswered && isSelected && idx != correctIndex) {
                    animatedChoice = animatedChoice.animate(key: ValueKey('wrong_$_currentQuestionIndex\_$idx')).shakeX(amount: 5, duration: 400.ms);
                  }
                  
                  return animatedChoice.animate(key: ValueKey('c_$_currentQuestionIndex\_$idx'))
                      .slideX(begin: 0.2, end: 0, delay: (idx * 100).ms, duration: 300.ms, curve: Curves.easeOutCubic)
                      .fadeIn(delay: (idx * 100).ms, duration: 300.ms);
                },
              ),
            ),

            // Bottom Buttons
            if (!_hasAnswered)
              ElevatedButton(
                onPressed: _selectedOptionIndex == null ? null : () => _submitAnswer(correctIndex),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(localizations.translate('submit_answer'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  _currentQuestionIndex < _quiz!.questions.length - 1 
                      ? localizations.translate('next_question') 
                      : localizations.translate('view_results'), 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutBack).fadeIn(duration: 300.ms),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }
}
