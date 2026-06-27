import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/global_audio_bar_wrapper.dart';
import '../auth/language_selection_screen.dart';
import '../../core/widgets/policy_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _familyEmailController = TextEditingController();
  bool _notificationsEnabled = true;

  @override
  void dispose() {
    _familyEmailController.dispose();
    super.dispose();
  }

  void _addFamilyMember() async {
    final email = _familyEmailController.text.trim();
    final localizations = AppLocalizations.of(context)!;
    if (email.isEmpty || !email.contains('@')) {
      _showToast(localizations.translate('family_invalid_email'));
      return;
    }

    await AppLocator.auth.linkFamilyMember(email);
    _familyEmailController.clear();
    setState(() {});
    _showToast(localizations.translate('family_linked_toast').replaceFirst('{email}', email));
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final themeState = Provider.of<AppThemeProvider>(context);
    final user = AppLocator.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('settings')),
      ),
      body: GlobalAudioBarWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Theme Setting
              Card(
                child: SwitchListTile(
                  value: themeState.isDarkMode,
                  onChanged: (_) => themeState.toggleTheme(),
                title: Text(
                  themeState.isDarkMode
                      ? localizations.translate('settings_dark_mode')
                      : localizations.translate('settings_light_mode'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                secondary: Icon(
                  themeState.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Language Selection
            Card(
              child: ListTile(
                leading: Icon(Icons.language, color: theme.colorScheme.secondary),
                title: Text(
                  localizations.translate('select_language'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(isFromSettings: true)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Notifications switch
            Card(
              child: SwitchListTile(
                value: _notificationsEnabled,
                onChanged: (val) {
                  setState(() {
                    _notificationsEnabled = val;
                  });
                },
                title: Text(
                  localizations.translate('settings_notifications'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                secondary: Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            const Divider(height: 48),

            // Family Sharing Account (Only for main Premium owners, not sharees)
            if (user != null && (user.subscriptionStatus == 'premium' || user.subscriptionStatus == 'pro')) ...[
              Text(
                localizations.translate('settings_family'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.translate('family_plan_desc'),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              user.familyMembers.isNotEmpty == true
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.translate('family_plan_active'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            localizations.translate('family_plan_limit_desc'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _familyEmailController,
                            decoration: InputDecoration(
                              hintText: localizations.translate('family_member_email_hint'),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _addFamilyMember,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          child: Text(localizations.translate('family_link_btn')),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),

              // Family Member List
              if (user.familyMembers.isNotEmpty == true) ...[
                Text(
                  localizations.translate('family_linked_members'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...user.familyMembers.map((email) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.person_outline, size: 20),
                      title: Text(email, style: const TextStyle(fontSize: 14)),
                      trailing: const Icon(Icons.check_circle_outline, color: Colors.teal),
                    ),
                  );
                }).toList(),
              ],
            ],
            const Divider(height: 48),

            // Legal & Policies Section
            Text(
              localizations.locale.languageCode == 'ku' ? 'یاسایی و ڕێساکان' : (localizations.locale.languageCode == 'ar' ? 'الشؤون القانونية والسياسات' : 'Legal & Policies'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.secondary),
                    title: Text(
                      localizations.locale.languageCode == 'ku' ? 'سیاسەتی تایبەتمەندی' : (localizations.locale.languageCode == 'ar' ? 'سياسة الخصوصية' : 'Privacy Policy'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showPolicyDialog(context, 'privacy'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.gavel_outlined, color: theme.colorScheme.secondary),
                    title: Text(
                      localizations.locale.languageCode == 'ku' ? 'مەرج و یاساکان' : (localizations.locale.languageCode == 'ar' ? 'الشروط والأحكام' : 'Terms & Conditions'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showPolicyDialog(context, 'terms'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.description_outlined, color: theme.colorScheme.secondary),
                    title: Text(
                      localizations.locale.languageCode == 'ku' ? 'ڕێککەوتننامەی بەکارهێنەر' : (localizations.locale.languageCode == 'ar' ? 'اتفاقية ترخيص المستخدم النهائي' : 'End User License Agreement (EULA)'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showPolicyDialog(context, 'eula'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Version 2.0',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
