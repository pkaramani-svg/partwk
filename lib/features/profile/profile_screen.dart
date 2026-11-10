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
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            localizations.translate('logout_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(localizations.translate('logout_desc')),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(
                      localizations.translate('cancel_btn'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(
                      localizations.translate('logout_btn'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await AppLocator.audio.clearState();
      await AppLocator.auth.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
          (route) => false,
        );
      }
    }
  }


  void _showAvatarPicker(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final currentAvatarUrl = AppLocator.auth.currentUser?.profilePictureUrl;

    final List<String> maleAvatars = List.generate(10, (i) => 'assets/avatars/male_$i.png');
    final List<String> femaleAvatars = List.generate(10, (i) => 'assets/avatars/female_$i.png');
    final List<String> animalAvatars = List.generate(10, (i) => 'assets/avatars/animal_$i.png');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7B00).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF7B00).withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/partwk_emblem.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('choose_avatar_title'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          localizations.translate('choose_avatar_desc'),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: localizations.translate('close_dialog'),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Male Avatars
              _buildAvatarCategory(
                sheetContext: sheetContext,
                parentContext: context,
                title: localizations.translate('male_avatars'),
                avatars: maleAvatars,
                accessibilityPrefix: 'male_avatar_accessibility',
                currentAvatarUrl: currentAvatarUrl,
                theme: theme,
                localizations: localizations,
              ),
              const SizedBox(height: 16),

              // Female Avatars
              _buildAvatarCategory(
                sheetContext: sheetContext,
                parentContext: context,
                title: localizations.translate('female_avatars'),
                avatars: femaleAvatars,
                accessibilityPrefix: 'female_avatar_accessibility',
                currentAvatarUrl: currentAvatarUrl,
                theme: theme,
                localizations: localizations,
              ),
              const SizedBox(height: 16),

              // Animal Avatars
              _buildAvatarCategory(
                sheetContext: sheetContext,
                parentContext: context,
                title: localizations.translate('animal_avatars'),
                avatars: animalAvatars,
                accessibilityPrefix: 'animal_avatar_accessibility',
                currentAvatarUrl: currentAvatarUrl,
                theme: theme,
                localizations: localizations,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarCategory({
    required BuildContext sheetContext,
    required BuildContext parentContext,
    required String title,
    required List<String> avatars,
    required String accessibilityPrefix,
    required String? currentAvatarUrl,
    required ThemeData theme,
    required AppLocalizations localizations,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: avatars.length,
            itemBuilder: (context, index) {
              final url = avatars[index];
              final isSelected = currentAvatarUrl == url;
              final labelText = localizations.translate(accessibilityPrefix).replaceAll('{number}', '${index + 1}') +
                  (isSelected ? ', ${localizations.translate('selected_avatar')}' : '');

              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 10.0),
                child: Semantics(
                  label: labelText,
                  button: true,
                  selected: isSelected,
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        await AppLocator.auth.updateProfilePicture(url);
                        if (sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(localizations.translate('avatar_updated_toast')),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text(localizations.translate('avatar_update_error')),
                              backgroundColor: theme.colorScheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundImage: AssetImage(url),
                            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                          ),
                        ),
                        if (isSelected)
                          PositionedDirectional(
                            bottom: 2,
                            end: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.cardColor, width: 1.5),
                              ),
                              child: const Icon(Icons.check, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocator.auth,
      builder: (context, _) {
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
                        Semantics(
                          button: true,
                          label: localizations.translate('avatar_change_btn'),
                          child: GestureDetector(
                            onTap: () => _showAvatarPicker(context),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: theme.colorScheme.secondary,
                                  backgroundImage: user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty
                                      ? (user.profilePictureUrl!.startsWith('assets/')
                                          ? AssetImage(user.profilePictureUrl!) as ImageProvider
                                          : NetworkImage(user.profilePictureUrl!))
                                      : null,
                                  child: user?.profilePictureUrl == null || user!.profilePictureUrl!.isEmpty
                                      ? Text(
                                          user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                                          style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                PositionedDirectional(
                                  bottom: 0,
                                  end: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.cardColor, width: 1.5),
                                    ),
                                    child: const Icon(Icons.edit, size: 10, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
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
                              if (isPremium && user?.subscriptionExpiryDate != null && user!.subscriptionExpiryDate!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Builder(
                                  builder: (context) {
                                    String expiryDate = user.subscriptionExpiryDate!;
                                    if (expiryDate.contains('T')) {
                                      expiryDate = expiryDate.split('T').first;
                                    } else if (expiryDate.contains(' ')) {
                                      expiryDate = expiryDate.split(' ').first;
                                    }
                                    return Text(
                                      '${localizations.translate('expiry_date')}: $expiryDate',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 12,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  }
                                ),
                              ],
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
                  localizations.translate('my_learning_hub'),
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
                  localizations.translate('system_settings'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Language
                _buildListTile(
                  context,
                  title: localizations.translate('select_language'),
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
                  title: localizations.translate('sign_out'),
                  subtitle: localizations.translate('logout_subtitle'),
                  icon: Icons.logout,
                  iconColor: Colors.redAccent,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        );
      },
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
