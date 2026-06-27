import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/custom_button.dart';
import '../home/main_navigation.dart';

class LearningGoalsScreen extends StatefulWidget {
  const LearningGoalsScreen({Key? key}) : super(key: key);

  @override
  State<LearningGoalsScreen> createState() => _LearningGoalsScreenState();
}

class _LearningGoalsScreenState extends State<LearningGoalsScreen> {
  final List<String> _selectedGoals = [];
  bool _isLoading = false;

  final Map<String, Map<String, String>> _goalChoices = {
    'goal-15m': {
      'en': 'Read/listen 15 minutes daily',
      'ku': 'خوێندنەوە/گوێگرتن بۆ ١٥ خولەک ڕۆژانە',
      'ar': 'القراءة/الاستماع لمدة 15 دقيقة يومياً'
    },
    'goal-one-idea': {
      'en': 'Study "One Idea Per Day"',
      'ku': 'خوێندنی "یەک بیرۆکە لە ڕۆژێکدا"',
      'ar': 'دراسة "فكرة واحدة في اليوم"'
    },
    'goal-book-week': {
      'en': 'Complete 1 book summary weekly',
      'ku': 'تەواوکردنی ١ کورتە کتێب لە هەفتەیەکدا',
      'ar': 'إكمال ملخص كتاب واحد أسبوعياً'
    },
    'goal-career': {
      'en': 'Boost career & leadership skills',
      'ku': 'بەرزکردنەوەی تواناکانی کار و سەرکردایەتی',
      'ar': 'تعزيز مهارات العمل والقيادة'
    },
    'goal-heritage': {
      'en': 'Explore regional history & wisdom',
      'ku': 'گەڕان بەدوای مێژوو و دانایی ناوچەکەدا',
      'ar': 'استكشاف تاريخ وحكمة المنطقة'
    }
  };

  void _toggleGoal(String key) {
    setState(() {
      if (_selectedGoals.contains(key)) {
        _selectedGoals.remove(key);
      } else {
        _selectedGoals.add(key);
      }
    });
  }

  void _finish() async {
    setState(() => _isLoading = true);
    await AppLocator.auth.updateGoals(_selectedGoals);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                localizations.translate('select_goals'),
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                localizations.translate('goals_subtitle'),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Goal Checkboxes
              Expanded(
                child: ListView(
                  children: _goalChoices.entries.map((entry) {
                    final key = entry.key;
                    final text = entry.value[langCode] ?? entry.value['en']!;
                    final isSelected = _selectedGoals.contains(key);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? theme.colorScheme.secondary.withOpacity(0.05) 
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected 
                              ? theme.colorScheme.secondary 
                              : Colors.grey.withOpacity(0.2),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) => _toggleGoal(key),
                        title: Text(
                          text,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? theme.colorScheme.secondary : null,
                          ),
                        ),
                        activeColor: theme.colorScheme.secondary,
                        checkboxShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 24),
              CustomButton(
                text: localizations.translate('save_continue'),
                isLoading: _isLoading,
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
