import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/custom_button.dart';
import '../../models/category.dart';
import 'learning_goals_screen.dart';

class InterestSelectionScreen extends StatefulWidget {
  const InterestSelectionScreen({Key? key}) : super(key: key);

  @override
  State<InterestSelectionScreen> createState() => _InterestSelectionScreenState();
}

class _InterestSelectionScreenState extends State<InterestSelectionScreen> {
  final List<String> _selectedCategoryIds = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    final cats = await AppLocator.db.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  void _toggleInterest(String id) {
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        _selectedCategoryIds.add(id);
      }
    });
  }

  void _saveAndContinue() async {
    setState(() => _isLoading = true);
    await AppLocator.auth.updateInterests(_selectedCategoryIds);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LearningGoalsScreen()),
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
                localizations.translate('select_interests'),
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 26),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                localizations.translate('interests_subtitle'),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Categories Grid/List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategoryIds.contains(cat.id);

                          IconData iconData = Icons.book;
                          if (cat.iconName == 'psychology') iconData = Icons.psychology;
                          if (cat.iconName == 'stars') iconData = Icons.stars;
                          if (cat.iconName == 'account_balance') iconData = Icons.account_balance;
                          if (cat.iconName == 'lightbulb') iconData = Icons.lightbulb;

                          return GestureDetector(
                            onTap: () => _toggleInterest(cat.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    iconData,
                                    size: 36,
                                    color: isSelected 
                                        ? theme.colorScheme.secondary 
                                        : theme.textTheme.bodyMedium?.color,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    cat.getName(langCode),
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? theme.colorScheme.secondary : null,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              
              const SizedBox(height: 24),
              CustomButton(
                text: localizations.translate('save_continue'),
                onPressed: _saveAndContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
