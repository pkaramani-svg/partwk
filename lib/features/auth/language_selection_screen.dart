import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import 'onboarding_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  final bool isFromSettings;
  const LanguageSelectionScreen({Key? key, this.isFromSettings = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languageState = Provider.of<AppLanguageState>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon representation
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.translate,
                    size: 36,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Your Language',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred language for book summaries and narrator voices. You can change this anytime in settings.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Language Cards
              _buildLanguageCard(
                context,
                title: 'English',
                code: 'en',
                isSelected: languageState.locale.languageCode == 'en',
                onTap: () => languageState.setLanguage('en'),
              ),
              const SizedBox(height: 16),
              _buildLanguageCard(
                context,
                title: 'کوردی (سۆرانی)',
                code: 'ku',
                isSelected: languageState.locale.languageCode == 'ku',
                onTap: () => languageState.setLanguage('ku'),
              ),
              const SizedBox(height: 16),
              _buildLanguageCard(
                context,
                title: 'العربية',
                code: 'ar',
                isSelected: languageState.locale.languageCode == 'ar',
                onTap: () => languageState.setLanguage('ar'),
              ),
              
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  if (isFromSettings) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    );
                  }
                },
                child: Text(isFromSettings ? 'Save & Return' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context, {
    required String title,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.secondary.withOpacity(0.08) 
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.secondary 
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.secondary : null,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.secondary,
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.withOpacity(0.4), width: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
