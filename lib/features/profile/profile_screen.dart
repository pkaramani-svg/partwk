import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../auth/login_register_screen.dart';
import 'settings_screen.dart';
import 'achievements_screen.dart';
import 'paywall_screen.dart';
import '../learning/notes_highlights_screen.dart';
import '../auth/language_selection_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  void _signOut(BuildContext context) async {
    await AppLocator.audio.clearState();
    await AppLocator.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final user = AppLocator.auth.currentUser;

    final isPremium = user?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Header Profile Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.secondary,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                        style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Guest User',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          Text(
                            user?.email ?? 'guest@partwk.com',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          
                          // Premium badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPremium 
                                  ? theme.colorScheme.tertiary.withOpacity(0.15) 
                                  : Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPremium ? 'PREMIUM MEMBER' : 'FREE PLAN',
                              style: TextStyle(
                                color: isPremium ? theme.colorScheme.tertiary : Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Profile List Tiles
            Text(
              localizations.translate('my_learning_hub') ?? 'My Learning Hub',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildListTile(
              context,
              title: localizations.translate('achievements'),
              subtitle: 'View statistics and claim badges',
              icon: Icons.emoji_events_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                );
              },
            ),
            _buildListTile(
              context,
              title: localizations.translate('notes_highlights'),
              subtitle: 'Review personal notes and quotes',
              icon: Icons.edit_note_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotesAndHighlightsScreen()),
                );
              },
            ),
            
            // Subscriptions Paywall Trigger
            if (!isPremium)
              _buildListTile(
                context,
                title: localizations.translate('premium_subscription'),
                subtitle: 'Unlock AI coach & narrator voice',
                icon: Icons.workspace_premium,
                iconColor: Colors.amber,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                },
              ),

            const Divider(height: 32),
            Text(
              localizations.translate('system_settings') ?? 'System Settings',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Language
            _buildListTile(
              context,
              title: localizations.translate('select_language') ?? 'Language',
              subtitle: 'Change app interface and content language',
              icon: Icons.language,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(isFromSettings: true)),
                );
              },
            ),

            // Logout
            _buildListTile(
              context,
              title: localizations.translate('sign_out') ?? 'Sign Out',
              subtitle: 'Log out of your profile session',
              icon: Icons.logout,
              iconColor: Colors.redAccent,
              onTap: () => _signOut(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? theme.colorScheme.secondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
