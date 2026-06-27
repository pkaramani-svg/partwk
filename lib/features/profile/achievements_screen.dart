import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/achievement.dart';
import '../library/saved_library_screen.dart';
import '../../core/widgets/streak_popup_dialog.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<Achievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  void _loadAchievements() async {
    final achs = await AppLocator.db.fetchAchievements();
    if (mounted) {
      setState(() {
        _achievements = achs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    final user = AppLocator.auth.currentUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Calculations for stats
    final totalCompleted = user?.completedBooks.length ?? 0;
    final streak = user?.streakCount ?? 0;
    final minutesRead = totalCompleted * 15; // Simulated 15 minutes per book

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('achievements')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: localizations.translate('completed') ?? 'Summaries Complete',
                    value: '$totalCompleted',
                    icon: Icons.check_circle_outline,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SavedLibraryScreen(initialIndex: 3),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    title: localizations.translate('streak_title') ?? 'Learning Streak',
                    value: '$streak ${localizations.translate('days_streak') ?? 'days'}',
                    icon: Icons.local_fire_department,
                    color: Colors.orangeAccent,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => StreakPopupDialog(streakCount: streak),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              context,
              title: localizations.translate('total_study_time') ?? 'Total Study Time',
              value: '$minutesRead ${localizations.translate('min_read') ?? 'minutes'}',
              icon: Icons.timer_outlined,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 32),

            // Badges Header
            Text(
              localizations.translate('achievements') ?? 'Achievement Badges',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Badges Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: _achievements.length,
              itemBuilder: (context, index) {
                final ach = _achievements[index];
                final isUnlocked = (user?.unlockedAchievements.contains('${ach.id}-$langCode') ?? false) || 
                                   (user?.unlockedAchievements.contains(ach.id) ?? false);

                String badgeDesc = ach.getDescription(langCode);
                final parts = ach.id.split('-');
                if (parts.length >= 3) {
                  final type = parts[1];
                  final count = parts[2];
                  if (int.tryParse(count) != null) {
                    final template = localizations.translate('ach_${type}_desc');
                    if (template != null) {
                      badgeDesc = template.replaceAll('@count', count);
                    }
                  }
                }
                final Map<String, IconData> iconMap = {
                  'rocket_launch': Icons.rocket_launch,
                  'auto_stories': Icons.auto_stories,
                  'library_books': Icons.library_books,
                  'menu_book': Icons.menu_book,
                  'school': Icons.school,
                  'account_balance': Icons.account_balance,
                  'local_fire_department': Icons.local_fire_department,
                  'whatshot': Icons.whatshot,
                  'bolt': Icons.bolt,
                  'star': Icons.star,
                  'workspace_premium': Icons.workspace_premium,
                  'bookmark_add': Icons.bookmark_add,
                  'bookmarks': Icons.bookmarks,
                  'collections_bookmark': Icons.collections_bookmark,
                  'favorite_border': Icons.favorite_border,
                  'favorite': Icons.favorite,
                  'volunteer_activism': Icons.volunteer_activism,
                  'translate': Icons.translate,
                  'language': Icons.language,
                  'business_center': Icons.business_center,
                  'psychology': Icons.psychology,
                  'timer': Icons.timer,
                  'hourglass_bottom': Icons.hourglass_bottom,
                  'access_time_filled': Icons.access_time_filled,
                };
                
                final IconData badgeIcon = iconMap[ach.badgeIcon] ?? Icons.emoji_events;

                final Widget cardContent = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isUnlocked ? theme.colorScheme.secondary : Colors.grey.withOpacity(0.2),
                      width: isUnlocked ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUnlocked 
                              ? theme.colorScheme.secondary.withOpacity(0.12)
                              : Colors.grey.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          badgeIcon,
                          color: isUnlocked ? theme.colorScheme.secondary : Colors.grey,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ach.getTitle(langCode),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? theme.colorScheme.secondary : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badgeDesc,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );

                return isUnlocked 
                    ? cardContent 
                    : ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                        child: Opacity(
                          opacity: 0.6,
                          child: cardContent,
                        ),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );

    if (onTap != null) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
