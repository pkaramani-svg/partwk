import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import 'login_register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    final List<Map<String, String>> onboardingData = [
      {
        'title': localizations.translate('onboarding_title_1'),
        'desc': localizations.translate('onboarding_desc_1'),
        'icon': 'auto_stories',
      },
      {
        'title': localizations.translate('onboarding_title_2'),
        'desc': localizations.translate('onboarding_desc_2'),
        'icon': 'schedule',
      },
      {
        'title': localizations.translate('onboarding_title_3'),
        'desc': localizations.translate('onboarding_desc_3'),
        'icon': 'psychology',
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _goToLogin,
                    child: Text(
                      localizations.translate('skip'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Sliding Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: onboardingData.length,
                itemBuilder: (context, index) {
                  final data = onboardingData[index];
                  IconData slideIcon = Icons.auto_stories;
                  if (data['icon'] == 'schedule') slideIcon = Icons.schedule;
                  if (data['icon'] == 'psychology') slideIcon = Icons.psychology;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Giant circle icon
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(
                            slideIcon,
                            size: 80,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          data['title']!,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data['desc']!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Bottom Section: Indicators and Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Row(
                    children: List.generate(
                      onboardingData.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.secondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                  // Next / Finish Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < onboardingData.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _goToLogin();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _currentPage == onboardingData.length - 1
                          ? localizations.translate('get_started')
                          : localizations.translate('next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
    );
  }
}
