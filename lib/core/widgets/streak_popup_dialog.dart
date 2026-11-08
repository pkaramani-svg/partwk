import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';
import '../services/service_locator.dart';
import '../services/streak_tracker.dart';

class StreakPopupDialog extends StatefulWidget {
  final int streakCount;
  const StreakPopupDialog({Key? key, required this.streakCount}) : super(key: key);

  @override
  State<StreakPopupDialog> createState() => _StreakPopupDialogState();
}

class _StreakPopupDialogState extends State<StreakPopupDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  int _longestStreak = 0;
  bool _isTodayCompleted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
    _loadStreakStats();
  }

  Future<void> _loadStreakStats() async {
    final user = AppLocator.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final userKey = 'longest_streak_${user?.id ?? "guest"}';
    int storedLongest = prefs.getInt(userKey) ?? 0;
    if (widget.streakCount > storedLongest) {
      storedLongest = widget.streakCount;
      await prefs.setInt(userKey, storedLongest);
    }
    final metToday = await StreakTracker.isStreakMetToday();
    if (mounted) {
      setState(() {
        _longestStreak = math.max(storedLongest, widget.streakCount);
        _isTodayCompleted = metToday;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Next milestone calculation
  Map<String, dynamic> _calculateNextMilestone(int current) {
    const milestones = [3, 7, 14, 30, 50, 100];
    int next = milestones.firstWhere((m) => m > current, orElse: () => current + 10);
    int prev = 0;
    for (final m in milestones) {
      if (m < next) prev = m;
    }
    final range = (next - prev).clamp(1, 100);
    final progress = ((current - prev) / range).clamp(0.0, 1.0);
    final daysLeft = math.max(0, next - current);
    return {
      'target': next,
      'progress': progress,
      'daysLeft': daysLeft,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    final isRtl = localizations.isRtl;

    String streakTitle;
    if (widget.streakCount <= 1) {
      streakTitle = localizations.translate('streak_title_singular');
    } else {
      streakTitle = localizations.translate('streak_title_plural')
          .replaceAll('{count}', widget.streakCount.toString());
    }

    final bool startOnSunday = langCode == 'ku' || langCode == 'ar';
    final List<String> dayLabels;
    if (langCode == 'ku') {
      dayLabels = [
        localizations.translate('day_sun'),
        localizations.translate('day_mon'),
        localizations.translate('day_tue'),
        localizations.translate('day_wed'),
        localizations.translate('day_thu'),
        localizations.translate('day_fri'),
        localizations.translate('day_sat'),
      ];
    } else if (langCode == 'ar') {
      dayLabels = [
        localizations.translate('day_sun'),
        localizations.translate('day_mon'),
        localizations.translate('day_tue'),
        localizations.translate('day_wed'),
        localizations.translate('day_thu'),
        localizations.translate('day_fri'),
        localizations.translate('day_sat'),
      ];
    } else {
      dayLabels = [
        localizations.translate('day_mon'),
        localizations.translate('day_tue'),
        localizations.translate('day_wed'),
        localizations.translate('day_thu'),
        localizations.translate('day_fri'),
        localizations.translate('day_sat'),
        localizations.translate('day_sun'),
      ];
    }

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    final List<DateTime> dates = List.generate(7, (index) {
      final DateTime startDay;
      if (startOnSunday) {
        final daysToSubtract = today.weekday == 7 ? 0 : today.weekday;
        startDay = today.subtract(Duration(days: daysToSubtract));
      } else {
        startDay = today.subtract(Duration(days: today.weekday - 1));
      }
      return DateTime(startDay.year, startDay.month, startDay.day).add(Duration(days: index));
    });

    final milestone = _calculateNextMilestone(widget.streakCount);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Dialog(
            backgroundColor: theme.scaffoldBackgroundColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header Flame Badge
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400.withOpacity(0.25),
                          Colors.deepOrange.shade600.withOpacity(0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange.withOpacity(0.35), width: 1.5),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 42,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Streak Title
                  Text(
                    streakTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // 2. Metrics Row (Current Streak & Longest Streak)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.withOpacity(0.15)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${widget.streakCount}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                localizations.translate('current_streak'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.withOpacity(0.15)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '$_longestStreak',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                localizations.translate('longest_streak'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Today's Activity Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isTodayCompleted
                          ? Colors.green.withOpacity(0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isTodayCompleted
                            ? Colors.green.withOpacity(0.35)
                            : Colors.grey.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _isTodayCompleted
                                ? Colors.green.withOpacity(0.18)
                                : Colors.orange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isTodayCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            color: _isTodayCompleted ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${localizations.translate('today_activity')}: ${_isTodayCompleted ? localizations.translate('activity_completed') : localizations.translate('activity_in_progress')}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isTodayCompleted
                                    ? localizations.translate('streak_completed_desc')
                                    : localizations.translate('streak_pending_desc'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. 7-Day Visual Progress View
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final dayDate = dates[index];
                      final isToday = dayDate.isAtSameMomentAs(todayDateOnly);
                      final isPast = dayDate.isBefore(todayDateOnly);

                      // Check if within active streak window
                      final streakStart = todayDateOnly.subtract(Duration(days: math.max(0, widget.streakCount - 1)));
                      final isStreakDay = !dayDate.isBefore(streakStart) && !dayDate.isAfter(todayDateOnly);

                      final bool isActive = isStreakDay && (isPast || _isTodayCompleted);

                      final Color containerBg;
                      final Color borderCol;
                      final Color textCol;
                      final Widget iconWidget;

                      if (isActive) {
                        containerBg = theme.colorScheme.secondary.withOpacity(0.18);
                        borderCol = theme.colorScheme.secondary;
                        textCol = theme.colorScheme.secondary;
                        iconWidget = const Icon(Icons.check_rounded, color: Colors.tealAccent, size: 12);
                      } else if (isToday) {
                        containerBg = Colors.orange.withOpacity(0.12);
                        borderCol = Colors.orange;
                        textCol = Colors.orange;
                        iconWidget = const Icon(Icons.circle, color: Colors.orange, size: 6);
                      } else if (isPast) {
                        containerBg = theme.colorScheme.surface;
                        borderCol = Colors.grey.withOpacity(0.2);
                        textCol = Colors.grey;
                        iconWidget = const Icon(Icons.remove, color: Colors.grey, size: 10);
                      } else {
                        containerBg = theme.colorScheme.surface;
                        borderCol = Colors.grey.withOpacity(0.15);
                        textCol = Colors.grey.shade500;
                        iconWidget = Icon(Icons.radio_button_unchecked, color: Colors.grey.shade600, size: 8);
                      }

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: containerBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: borderCol,
                              width: isToday ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                dayLabels[index],
                                style: TextStyle(
                                  color: textCol,
                                  fontWeight: (isActive || isToday) ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              iconWidget,
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  // 5. Next Milestone Progress Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${localizations.translate('next_milestone')}: ${milestone['target']} ${localizations.translate('days_streak')}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              localizations.translate('days_left')
                                  .replaceAll('{count}', milestone['daysLeft'].toString()),
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (milestone['progress'] as double),
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        localizations.translate('save_continue'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
