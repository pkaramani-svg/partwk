import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/flashcard.dart';
import '../../models/book.dart';

class FlashcardsScreen extends StatefulWidget {
  final String bookId;
  const FlashcardsScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  bool _showFront = true;
  int _currentIndex = 0;

  List<Flashcard>? _flashcards;
  Book? _book;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_flashcards == null && _isLoading) {
      _loadFlashcards();
    }
  }

  void _loadFlashcards() async {
    final langCode = AppLocalizations.of(context)!.locale.languageCode;
    final cards = await AppLocator.db.fetchFlashcardsForBook(widget.bookId, langCode);
    Book? book;
    try {
      book = AppLocator.db.books.firstWhere((b) => b.id == widget.bookId);
    } catch (_) {}

    if (mounted) {
      setState(() {
        _flashcards = cards;
        _book = book;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_showFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  void _nextCard() {
    if (_flashcards == null) return;
    if (_currentIndex < _flashcards!.length - 1) {
      setState(() {
        _currentIndex++;
        _showFront = true;
      });
      _flipController.reset();
    } else {
      // Completed session
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(localizations.translate('session_completed')),
          content: Text(localizations.translate('flashcards_completed_desc')),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dialog
                Navigator.of(context).pop(); // Screen
              },
              child: Text(localizations.translate('awesome')),
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
      return Scaffold(
        appBar: AppBar(title: Text(localizations.translate('flashcards'))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_flashcards == null || _flashcards!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.translate('flashcards'))),
        body: Center(child: Text(localizations.translate('no_flashcards'))),
      );
    }

    final card = _flashcards![_currentIndex];

    final frontText = card.front;
    final backText = card.back;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('flashcards')),
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
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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
                // Progress Bar
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _flashcards!.length,
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                ).animate().fade(duration: 400.ms),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('card_progress')
                      .replaceAll('{current}', '${_currentIndex + 1}')
                      .replaceAll('{total}', '${_flashcards!.length}'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ).animate().fade(duration: 400.ms),
                const Spacer(),
            
            // Flippable Card Area
            GestureDetector(
              onTap: _flipCard,
              child: AnimatedBuilder(
                animation: _flipController,
                builder: (context, child) {
                  final transformAngle = _flipController.value * pi;
                  final isBack = transformAngle > (pi / 2);

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..rotateY(transformAngle),
                    alignment: Alignment.center,
                    child: Container(
                      height: 340,
                      decoration: BoxDecoration(
                        color: isBack ? theme.colorScheme.secondary.withOpacity(0.1) : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Transform(
                        // Counter-rotate text so it doesn't display mirrored
                        transform: isBack ? Matrix4.rotationY(pi) : Matrix4.identity(),
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isBack ? Icons.psychology : Icons.help_outline,
                                color: theme.colorScheme.secondary,
                                size: 48,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                isBack 
                                    ? localizations.translate('flashcard_answer').toUpperCase() 
                                    : localizations.translate('flashcard_question').toUpperCase(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 12),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Text(
                                        isBack ? backText : frontText,
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ).animate(key: ValueKey(_currentIndex))
                 .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
                 .fadeIn(duration: 400.ms),
                
                const Spacer(),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _flipCard,
                      icon: const Icon(Icons.flip),
                      label: Text(localizations.translate('flip_card')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _nextCard,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_currentIndex < _flashcards!.length - 1 
                          ? localizations.translate('next') 
                          : localizations.translate('completed')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ).animate().slideY(begin: 0.5, end: 0, duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 500.ms),
                const SizedBox(height: 16),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }
}
