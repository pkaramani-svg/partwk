import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/analytics_service.dart';
import '../../models/book.dart';

void showCompletionCelebrationPopup(BuildContext context, Book book) {
  // Check if accessibility options prefer reduced motion
  final mediaQuery = MediaQuery.of(context);
  final isReducedMotion = mediaQuery.accessibleNavigation || mediaQuery.disableAnimations;
  final double animationTarget = isReducedMotion ? 0.0 : 1.0;

  // Track the popup being displayed
  AnalyticsService.trackEvent('completion_popup_shown', parameters: {
    'bookId': book.id,
    'bookTitle': book.getTitle('en'),
  });

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      final theme = Theme.of(context);
      final localizations = AppLocalizations.of(context)!;
      final lang = localizations.locale.languageCode;

      final title = lang == 'ku' ? 'خوێندنەوەت تەواو کرد!' :
                    lang == 'ar' ? 'أكملت القراءة!' :
                    'Summary Completed!';

      final message = lang == 'ku' ? 'پیرۆزە! کورتەکراوەی "${book.getTitle(lang)}" بە سەرکەوتوویی تەواو کرا.' :
                      lang == 'ar' ? 'تهانينا! لقد أكملت ملخص "${book.getTitle(lang)}" بنجاح.' :
                      'Congratulations! You have successfully completed the summary of "${book.getTitle(lang)}".';

      final user = AppLocator.auth.currentUser;
      final streak = user?.streakCount ?? 0;
      final totalCompleted = user?.completedBooks.length ?? 0;

      return Dialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 24,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration checkmark circle with custom bounce animation
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    size: 64,
                    color: Colors.green,
                  ),
                ).animate(target: animationTarget).scale(
                      delay: 100.ms,
                      duration: 500.ms,
                      curve: Curves.bounceOut,
                    ),

                const SizedBox(height: 24),

                // Title
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Description message
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Stats Dashboard (Streak + Total Completed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.01),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Streak Count
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              '$streak',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang == 'ku' ? 'ڕێڕەوی ڕۆژانە' : lang == 'ar' ? 'سلسلة الأيام' : 'Days Streak',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Vertical Divider
                      Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.2)),
                      
                      // Total Completed Summaries
                      Expanded(
                        child: Column(
                          children: [
                            const Icon(Icons.bookmark_added, color: Colors.blueAccent, size: 24),
                            const SizedBox(height: 6),
                            Text(
                              '$totalCompleted',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang == 'ku' ? 'تەواوکراو' : lang == 'ar' ? 'مكتمل' : 'Completed',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Continue & Library Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        AnalyticsService.trackEvent('completion_popup_action_continue', parameters: {
                          'bookId': book.id,
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        lang == 'ku' ? 'بەردەوامبە' : lang == 'ar' ? 'استمرار' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        AnalyticsService.trackEvent('completion_popup_action_next_summary', parameters: {
                          'bookId': book.id,
                        });
                        Navigator.of(context).pop();
                        // Pop everything back to return to the library screen (which sits at root)
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Text(
                        lang == 'ku' ? 'بڕۆ بۆ کتێبخانە' : lang == 'ar' ? 'الذهاب للمكتبة' : 'View Library',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
