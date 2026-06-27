import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/service_locator.dart';

class StreakPopupDialog extends StatefulWidget {
  final int streakCount;
  const StreakPopupDialog({Key? key, required this.streakCount}) : super(key: key);

  @override
  State<StreakPopupDialog> createState() => _StreakPopupDialogState();
}

class _StreakPopupDialogState extends State<StreakPopupDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    
    String streakTitle;
    if (widget.streakCount <= 1) {
      streakTitle = localizations.translate('streak_title_singular');
    } else {
      streakTitle = localizations.translate('streak_title_plural')
          .replaceAll('{count}', widget.streakCount.toString());
    }

    final List<String> days;
    final int todayIndex = DateTime.now().weekday - 1;
    if (langCode == 'ku') {
      days = ['د', 'س', 'چ', 'پ', 'هـ', 'ش', 'ی'];
    } else if (langCode == 'ar') {
      days = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    } else {
      days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    }

    final user = AppLocator.auth.currentUser;
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    DateTime lastActiveDateTime;
    if (user != null && user.lastActiveDate.isNotEmpty) {
      try {
        lastActiveDateTime = DateTime.parse(user.lastActiveDate);
      } catch (_) {
        lastActiveDateTime = todayDateOnly;
      }
    } else {
      lastActiveDateTime = todayDateOnly;
    }
    final lastActiveDateOnly = DateTime(lastActiveDateTime.year, lastActiveDateTime.month, lastActiveDateTime.day);

    final List<DateTime> dates = List.generate(7, (index) {
      final monday = today.subtract(Duration(days: today.weekday - 1));
      return DateTime(monday.year, monday.month, monday.day).add(Duration(days: index));
    });

    final isRtl = localizations.isRtl;

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Fire Streak Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_fire_department,
                      color: Colors.orange,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Congratulations text
                Text(
                  localizations.translate('streak_congrats'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                
                // Streak title
                Text(
                  streakTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // Days Row
                Directionality(
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final dayDate = dates[index];
                      final isFuture = dayDate.isAfter(todayDateOnly);
                      final isToday = dayDate.isAtSameMomentAs(todayDateOnly);

                      // Check if within the streak range
                      final streakStart = lastActiveDateOnly.subtract(Duration(days: widget.streakCount - 1));
                      final isStreakActive = !dayDate.isBefore(streakStart) && !dayDate.isAfter(lastActiveDateOnly);

                      final String status;
                      if (isStreakActive) {
                        status = 'active';
                      } else if (isFuture || isToday) {
                        status = 'future';
                      } else {
                        status = 'missed';
                      }

                      final Color containerBg;
                      final Color borderCol;
                      final Color textCol;
                      final Widget? indicatorWidget;

                      if (status == 'active') {
                        containerBg = theme.colorScheme.secondary;
                        borderCol = theme.colorScheme.secondary;
                        textCol = Colors.white;
                        indicatorWidget = const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.local_fire_department, color: Colors.amber, size: 12),
                        );
                      } else if (status == 'missed') {
                        containerBg = Colors.red.withOpacity(0.08);
                        borderCol = Colors.red.withOpacity(0.3);
                        textCol = Colors.red;
                        indicatorWidget = const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.close, color: Colors.red, size: 10),
                        );
                      } else {
                        containerBg = theme.colorScheme.surface;
                        borderCol = Colors.grey.withOpacity(0.2);
                        textCol = Colors.grey;
                        indicatorWidget = const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 8),
                        );
                      }

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.0),
                          height: 52,
                          decoration: BoxDecoration(
                            color: containerBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderCol,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                days[index],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textCol,
                                  fontWeight: (status == 'active') ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                              if (indicatorWidget != null) indicatorWidget,
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Description warning info message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Text(
                    localizations.translate('streak_message'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      localizations.translate('save_continue'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
