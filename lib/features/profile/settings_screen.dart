import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/global_audio_bar_wrapper.dart';
import '../auth/language_selection_screen.dart';
import '../../core/widgets/policy_dialog.dart';
import '../../services/notification_service.dart';
import '../auth/login_register_screen.dart';
import 'paywall_screen.dart';
import '../../models/user.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final TextEditingController _familyEmailController = TextEditingController();
  bool _notificationsEnabled = true;
  Future<Map<String, dynamic>>? _familyStatusFuture;
  bool _isFamilyBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _familyEmailController.addListener(_onEmailChanged);
    _checkNotificationState();
    _refreshFamilyStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshFamilyStatus();
    }
  }

  void _onEmailChanged() {
    if (mounted) setState(() {});
  }

  void _refreshFamilyStatus() {
    setState(() {
      _familyStatusFuture = AppLocator.family.status();
    });
  }

  void _checkNotificationState() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _familyEmailController.removeListener(_onEmailChanged);
    _familyEmailController.dispose();
    super.dispose();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

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

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            localizations.translate('delete_account_confirm_title'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          content: Text(
            localizations.translate('delete_account_confirm_desc'),
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
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
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    child: Text(
                      localizations.translate('delete_account_btn'),
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

    if (confirmed != true) return;

    final provider = AppLocator.auth.signInProvider;
    String? password;

    if (provider == 'google.com') {
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (reauthCtx) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text(
              localizations.translate('reauth_google_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              localizations.translate('reauth_google_desc'),
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(reauthCtx).pop(false),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(reauthCtx).pop(true),
                      child: Text(
                        localizations.translate('reauth_google_btn'),
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
      if (proceed != true) return;
    } else if (provider == 'apple.com') {
      final proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (reauthCtx) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text(
              localizations.translate('reauth_apple_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              localizations.translate('reauth_apple_desc'),
              style: const TextStyle(height: 1.4),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(reauthCtx).pop(false),
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
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.of(reauthCtx).pop(true),
                      child: Text(
                        localizations.translate('reauth_apple_btn'),
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
      if (proceed != true) return;
    } else {
      final passwordController = TextEditingController();
      bool obscurePassword = true;
      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (reauthCtx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: Text(
                  localizations.translate('reauth_required_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.translate('reauth_required_desc'),
                      style: const TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: localizations.translate('password_hint'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          ),
                          onPressed: () {
                            setDialogState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
                actions: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(reauthCtx).pop(null),
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
                          onPressed: () {
                            final pass = passwordController.text;
                            Navigator.of(reauthCtx).pop(pass);
                          },
                          child: Text(
                            localizations.translate('delete_account_btn'),
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
        },
      );

      if (password == null || password.isEmpty) {
        return;
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AppLocator.auth.deleteAccount(password: password);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.translate('delete_account_success'))),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('canceled') || errStr.contains('cancelled')) {
          _showToast(localizations.translate('reauth_canceled_msg'));
        } else if (errStr.contains('wrong-password') ||
            errStr.contains('invalid-credential') ||
            errStr.contains('user-mismatch')) {
          _showToast(localizations.translate('reauth_failed_msg'));
        } else {
          _showToast(localizations.translate('delete_account_error'));
        }
      }
    }
  }

  Future<void> _addFamilyMember() async {
    final email = _familyEmailController.text.trim();
    final localizations = AppLocalizations.of(context)!;
    final user = AppLocator.auth.currentUser;

    if (email.isEmpty) {
      _showToast(localizations.translate('family_error_empty_email'));
      return;
    }

    final isValidFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!isValidFormat) {
      _showToast(localizations.translate('family_invalid_email'));
      return;
    }

    if (user != null && user.email.isNotEmpty && email.toLowerCase() == user.email.toLowerCase()) {
      _showToast(localizations.translate('family_error_own_account'));
      return;
    }

    setState(() => _isFamilyBusy = true);
    try {
      await AppLocator.family.invite(email, language: localizations.locale.languageCode);
      _familyEmailController.clear();
      _showToast(localizations.translate('family_invite_success').replaceAll('{email}', email));
      _refreshFamilyStatus();
    } catch (e) {
      final msg = e.toString().toLowerCase();
      String err = localizations.translate('family_status_error_desc');
      if (msg.contains('own account')) {
        err = localizations.translate('family_error_own_account');
      } else if (msg.contains('already in a family')) {
        err = localizations.translate('family_error_already_in_family');
      } else if (msg.contains('paid access') || msg.contains('independently paid')) {
        err = localizations.translate('family_error_paid_account');
      } else if (msg.contains('reserved or active') || msg.contains('already in use') || msg.contains('slot is already')) {
        err = localizations.translate('family_error_slot_reserved');
      } else if (msg.contains('primary premium') || msg.contains('active primary')) {
        err = localizations.translate('family_error_not_primary');
      } else if (msg.contains('valid email')) {
        err = localizations.translate('family_invalid_email');
      }
      _showToast(err);
    } finally {
      if (mounted) setState(() => _isFamilyBusy = false);
    }
  }

  Future<void> _cancelInvitation(String email) async {
    final localizations = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.translate('family_cancel_invite_title')),
        content: Text(localizations.translate('family_cancel_invite_confirm').replaceAll('{email}', email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.translate('keep_btn')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.translate('confirm_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isFamilyBusy = true);
      try {
        await AppLocator.family.cancel();
        _showToast(localizations.translate('family_cancel_success'));
        _refreshFamilyStatus();
      } catch (e) {
        _showToast(localizations.translate('family_status_error_desc'));
      } finally {
        if (mounted) setState(() => _isFamilyBusy = false);
      }
    }
  }

  Future<void> _removeFamilyMember(String email) async {
    final localizations = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.translate('family_remove_member_title')),
        content: Text(localizations.translate('family_remove_member_confirm').replaceAll('{email}', email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.translate('keep_btn')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.translate('confirm_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isFamilyBusy = true);
      try {
        await AppLocator.family.remove();
        _showToast(localizations.translate('family_remove_success'));
        _refreshFamilyStatus();
      } catch (e) {
        _showToast(localizations.translate('family_status_error_desc'));
      } finally {
        if (mounted) setState(() => _isFamilyBusy = false);
      }
    }
  }

  Future<void> _leaveFamilyPlan() async {
    final localizations = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.translate('family_leave_plan_title')),
        content: Text(localizations.translate('family_leave_plan_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(localizations.translate('keep_btn')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.translate('confirm_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isFamilyBusy = true);
      try {
        await AppLocator.family.leave();
        _showToast(localizations.translate('family_leave_success'));
        _refreshFamilyStatus();
      } catch (e) {
        _showToast(localizations.translate('family_status_error_desc'));
      } finally {
        if (mounted) setState(() => _isFamilyBusy = false);
      }
    }
  }

  Future<void> _acceptInvitation() async {
    setState(() => _isFamilyBusy = true);
    final localizations = AppLocalizations.of(context)!;
    try {
      await AppLocator.family.accept();
      _showToast(localizations.translate('family_premium_member_badge'));
      _refreshFamilyStatus();
    } catch (e) {
      _showToast(localizations.translate('family_status_error_desc'));
    } finally {
      if (mounted) setState(() => _isFamilyBusy = false);
    }
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
                  title: Text(
                    localizations.translate('settings_notifications'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    localizations.translate('settings_notifications_desc'),
                    style: theme.textTheme.bodySmall,
                  ),
                  secondary: Icon(
                    _notificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                    color: theme.colorScheme.secondary,
                  ),
                  onChanged: (val) async {
                    setState(() => _notificationsEnabled = val);
                    final granted = await NotificationService().setNotificationsEnabled(val);
                    if (mounted && granted != _notificationsEnabled) {
                      setState(() => _notificationsEnabled = granted);
                    }
                  },
                ),
              ),
              const Divider(height: 48),

              // Family relationships are server-owned. This screen never writes a
              // profile's familyMembers array or another user's entitlement directly.
              if (user != null && !AppLocator.auth.isGuest) ...[
                _buildFamilySection(theme, localizations, user),
                const SizedBox(height: 16),
              ],

              // Logout row after Family Sharing and before Legal & Policies
              if (user != null && !AppLocator.auth.isGuest) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: Text(
                      localizations.translate('log_out'),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                    subtitle: Text(
                      localizations.translate('logout_subtitle'),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _signOut(context),
                  ),
                ),
                const SizedBox(height: 16),
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

              // Account Section (at the very bottom of Settings, after Legal & Policies)
              if (user != null && !AppLocator.auth.isGuest) ...[
                const Divider(height: 48),
                Text(
                  localizations.translate('settings_account_title'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.error.withOpacity(0.35)),
                  ),
                  color: theme.colorScheme.error.withOpacity(0.06),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_remove_rounded, color: theme.colorScheme.error, size: 24),
                    ),
                    title: Text(
                      localizations.translate('delete_account_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        localizations.translate('delete_account_explanation'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
                          height: 1.35,
                        ),
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: theme.colorScheme.error),
                    onTap: () => _handleDeleteAccount(context),
                  ),
                ),
              ],
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

  Widget _buildFamilySection(ThemeData theme, AppLocalizations localizations, UserModel user) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _familyStatusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.error.withOpacity(0.4)),
            ),
            color: theme.colorScheme.error.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: theme.colorScheme.error, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.translate('family_status_error_title'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.translate('family_status_error_desc'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _refreshFamilyStatus,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(localizations.translate('family_retry_btn')),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final membership = data['membership'] as Map?;
        final family = data['family'] as Map?;
        final entitlement = data['entitlement'] as Map?;

        final isLinkedMember = entitlement?['source'] == 'family' ||
            user.hasFamilyPremium ||
            (membership?['state'] == 'active' && membership?['ownerUid'] != user.id);

        final hasReceivedInvite = membership?['state'] == 'pending' && membership?['ownerUid'] != user.id;

        final isPrimary = (user.isPremium && !isLinkedMember) ||
            (entitlement?['status'] == 'active' && entitlement?['source'] != 'family');

        // 1. Linked Family Member (receiving Premium from another user)
        if (isLinkedMember) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            color: theme.colorScheme.primary.withOpacity(0.06),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.verified_user_rounded, color: theme.colorScheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.translate('family_premium_member_badge'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.translate('family_premium_member_desc'),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isFamilyBusy ? null : _leaveFamilyPlan,
                    icon: const Icon(Icons.exit_to_app, size: 18),
                    label: Text(localizations.translate('family_leave_plan_btn')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. Pending received invitation
        if (hasReceivedInvite) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.amber.withOpacity(0.4)),
            ),
            color: Colors.amber.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, color: Colors.amber, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.translate('family_received_invite_title'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.translate('family_received_invite_desc'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isFamilyBusy ? null : _acceptInvitation,
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(localizations.translate('family_accept_invite_btn')),
                  ),
                ],
              ),
            ),
          );
        }

        // 3. Free User (non-subscriber, cannot manage or invite)
        if (!isPrimary) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.family_restroom, color: theme.colorScheme.secondary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.translate('family_premium_sharing_title'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.translate('family_free_tier_desc'),
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen()),
                      );
                    },
                    icon: const Icon(Icons.star, size: 18),
                    label: Text(localizations.translate('family_upgrade_plan_btn')),
                  ),
                ],
              ),
            ),
          );
        }

        // 4. Primary Premium Subscriber
        final hasActiveMember = family?['memberUid'] != null;
        final hasPendingInvite = family?['invitation'] != null;

        // Sub-state A: Accepted Member
        if (hasActiveMember) {
          final memberEmail = family?['memberEmail'] ?? 'family-member@partwk.com';

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.green.withOpacity(0.3)),
            ),
            color: Colors.green.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.family_restroom, color: theme.colorScheme.secondary, size: 24),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                localizations.translate('family_premium_sharing_title'),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.4)),
                        ),
                        child: Text(
                          localizations.translate('family_slot_active_badge'),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.translate('family_slot_in_use_desc'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            memberEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isFamilyBusy ? null : () => _removeFamilyMember(memberEmail),
                    icon: const Icon(Icons.person_remove_outlined, size: 18),
                    label: Text(localizations.translate('family_remove_member_btn')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Sub-state B: Pending Invite
        if (hasPendingInvite) {
          final invitedEmail = family?['invitation']?['recipientEmail'] ?? 'family-invite@partwk.com';

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.orange.withOpacity(0.3)),
            ),
            color: Colors.orange.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.family_restroom, color: theme.colorScheme.secondary, size: 24),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                localizations.translate('family_premium_sharing_title'),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.withOpacity(0.4)),
                        ),
                        child: Text(
                          localizations.translate('family_slot_reserved_badge'),
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.translate('family_invitation_pending_title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.translate('family_invitation_pending_desc'),
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mail_outline, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            invitedEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isFamilyBusy ? null : () => _cancelInvitation(invitedEmail),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: Text(localizations.translate('family_cancel_invite_btn')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error.withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Sub-state C: No member and no invite pending (Available to invite)
        final emailText = _familyEmailController.text.trim();
        final isOwnEmail = user.email.isNotEmpty && emailText.toLowerCase() == user.email.toLowerCase();
        final isValidEmailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailText);
        final canInvite = isValidEmailFormat && !isOwnEmail && !_isFamilyBusy;

        String? inlineError;
        if (emailText.isNotEmpty) {
          if (isOwnEmail) {
            inlineError = localizations.translate('family_error_own_account');
          } else if (!isValidEmailFormat && (emailText.contains('@') || emailText.length > 5)) {
            inlineError = localizations.translate('family_invalid_email');
          }
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.family_restroom, color: theme.colorScheme.secondary, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      localizations.translate('family_premium_sharing_title'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('family_share_plan_desc'),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.translate('family_email_input_label'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _familyEmailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !_isFamilyBusy,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: localizations.translate('family_email_input_hint'),
                      hintTextDirection: TextDirection.ltr,
                      prefixIcon: const Icon(Icons.alternate_email, size: 20, color: Color(0xFFFF7B00)),
                      filled: true,
                      fillColor: theme.brightness == Brightness.dark
                          ? const Color(0xFF1E293B).withOpacity(0.6)
                          : Colors.grey.withOpacity(0.08),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFF7B00), width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
                      ),
                      errorText: inlineError,
                    ),
                    onSubmitted: (_) {
                      if (canInvite) _addFamilyMember();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canInvite ? _addFamilyMember : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7B00),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFFF7B00).withOpacity(0.32),
                      disabledForegroundColor: Colors.white.withOpacity(0.45),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: canInvite ? 1 : 0,
                    ),
                    child: _isFamilyBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_add_alt_1, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                localizations.translate('family_invite_btn'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
