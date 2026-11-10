import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/custom_button.dart';
import 'interest_selection_screen.dart';
import '../home/main_navigation.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({Key? key}) : super(key: key);

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await AppLocator.auth.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        await AppLocator.audio.init();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      } else {
        await AppLocator.auth.registerWithEmailAndPassword(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const InterestSelectionScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        final errorMsg = _mapAuthErrorToMessage(e, localizations, isLogin: _isLogin);
        if (errorMsg != null) {
          _showError(errorMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _socialLogin(String type) async {
    setState(() => _isLoading = true);
    try {
      if (type == 'google') {
        await AppLocator.auth.signInWithGoogle();
      } else {
        await AppLocator.auth.signInWithApple();
      }
      await AppLocator.audio.init();
      if (mounted) {
        if (AppLocator.auth.isAuthenticated) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        final errorMsg = _mapAuthErrorToMessage(e, localizations, isLogin: true, isSocial: true);
        if (errorMsg != null) {
          _showError(errorMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _guestMode() async {
    setState(() => _isLoading = true);
    try {
      await AppLocator.auth.signInAsGuest();
      await AppLocator.audio.init();
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        final errorMsg = _mapAuthErrorToMessage(e, localizations, isLogin: true);
        if (errorMsg != null) {
          _showError(errorMsg);
        }
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    final localizations = AppLocalizations.of(context)!;
    String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      // Show dialog to collect email
      final controller = TextEditingController(text: email);
      final submittedEmail = await showDialog<String>(
        context: context,
        builder: (context) {
          return Directionality(
            textDirection: localizations.textDirection,
            child: AlertDialog(
              title: Text(
                localizations.translate('reset_password_title'),
                textAlign: localizations.isRtl ? TextAlign.right : TextAlign.left,
              ),
              content: TextField(
                controller: controller,
                textAlign: localizations.isRtl ? TextAlign.right : TextAlign.left,
                textDirection: localizations.textDirection,
                decoration: InputDecoration(
                  hintText: localizations.translate('reset_password_email_hint'),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.translate('cancel_btn')),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: Text(localizations.translate('send_btn')),
                ),
              ],
            ),
          );
        },
      );
      if (submittedEmail == null) return;
      if (submittedEmail.isEmpty || !submittedEmail.contains('@')) {
        _showError(localizations.translate('invalid_email_error'));
        return;
      }
      email = submittedEmail;
    }
    
    setState(() => _isLoading = true);
    try {
      await AppLocator.auth.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                localizations.translate('reset_password_success'),
                textAlign: localizations.isRtl ? TextAlign.right : TextAlign.left,
                textDirection: localizations.textDirection,
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('[Auth] Forgot password error: ${e.runtimeType} -> $e');
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('too-many-requests')) {
          _showError(localizations.translate('reset_password_rate_limited'));
        } else if (errStr.contains('network') || errStr.contains('unavailable') || errStr.contains('socket')) {
          _showError(localizations.translate('reset_password_network_error'));
        } else if (errStr.contains('invalid-email')) {
          _showError(localizations.translate('invalid_email_error'));
        } else {
          _showError(localizations.translate('reset_password_generic_error'));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _mapAuthErrorToMessage(
    dynamic error,
    AppLocalizations localizations, {
    required bool isLogin,
    bool isSocial = false,
  }) {
    if (error == null) return null;

    // Developer logging: Log full technical error details without sensitive data like passwords
    debugPrint('[Auth] Operation error (isLogin: $isLogin, isSocial: $isSocial): ${error.runtimeType} -> $error');

    String code = '';
    final rawText = error.toString().toLowerCase();

    if (error is FirebaseAuthException) {
      code = error.code.toLowerCase();
    } else {
      try {
        final dynamic dyn = error;
        if (dyn.code != null) {
          code = dyn.code.toString().toLowerCase();
        }
      } catch (_) {}
    }

    if (code.isEmpty) {
      final bracketMatch = RegExp(r'\[(?:firebase_auth/)?([a-zA-Z0-9_-]+)\]').firstMatch(rawText);
      if (bracketMatch != null) {
        code = bracketMatch.group(1)!.toLowerCase();
      }
    }

    // Social login cancellation check (Google or Apple dismissed/cancelled by user)
    if (isSocial) {
      if (code == 'canceled' ||
          code == 'sign_in_canceled' ||
          code == 'popup_closed_by_user' ||
          (code == 'unknown' && rawText.contains('canceled')) ||
          rawText.contains('sign_in_canceled') ||
          rawText.contains('user canceled') ||
          rawText.contains('user cancelled') ||
          rawText.contains('popup_closed_by_user') ||
          rawText.contains('canceled') ||
          rawText.contains('cancelled')) {
        return null;
      }
    }

    // 1. Account-enumeration-safe login error:
    // For invalid-credential, user-not-found, wrong-password, malformed/expired credential and deleted-account login attempts
    if (isLogin && (
        code == 'invalid-credential' ||
        code == 'user-not-found' ||
        code == 'wrong-password' ||
        code == 'user-deleted' ||
        code == 'account-deleted' ||
        rawText.contains('invalid-credential') ||
        rawText.contains('user-not-found') ||
        rawText.contains('wrong-password') ||
        rawText.contains('user-deleted') ||
        rawText.contains('account-deleted') ||
        rawText.contains('malformed') ||
        rawText.contains('expired') ||
        rawText.contains('credential is incorrect') ||
        rawText.contains('auth credential is incorrect')
    )) {
      return localizations.translate('auth_error_invalid_credentials');
    }

    // 2. Email already registered during sign-up
    if (code == 'email-already-in-use' ||
        code == 'account-exists-with-different-credential' ||
        rawText.contains('email-already-in-use') ||
        rawText.contains('email already in use') ||
        rawText.contains('account-exists-with-different-credential')) {
      return localizations.translate('auth_error_email_already_in_use');
    }

    // 3. Invalid email address
    if (code == 'invalid-email' ||
        rawText.contains('invalid-email') ||
        rawText.contains('badly formatted')) {
      return localizations.translate('auth_error_invalid_email');
    }

    // 4. Disabled account
    if (code == 'user-disabled' || rawText.contains('user-disabled')) {
      return localizations.translate('auth_error_user_disabled');
    }

    // 5. Too many login attempts
    if (code == 'too-many-requests' || rawText.contains('too-many-requests')) {
      return localizations.translate('auth_error_too_many_requests');
    }

    // 6. Weak password / Password too short
    if (code == 'weak-password' ||
        rawText.contains('weak-password') ||
        rawText.contains('weak password') ||
        rawText.contains('password must be') ||
        rawText.contains('password should be') ||
        rawText.contains('password is too short') ||
        rawText.contains('password too short') ||
        rawText.contains('at least 6')) {
      return localizations.translate('password_too_short');
    }

    // 7. Network / offline problem
    if (code == 'network-request-failed' ||
        code == 'network_error' ||
        code == 'unavailable' ||
        rawText.contains('network-request-failed') ||
        rawText.contains('network') ||
        rawText.contains('unavailable') ||
        rawText.contains('socketexception') ||
        rawText.contains('offline')) {
      return localizations.translate('auth_error_network');
    }

    // Safety check for login: never reveal account existence
    if (isLogin && (
        code.contains('credential') ||
        rawText.contains('credential') ||
        rawText.contains('password') ||
        rawText.contains('user')
    )) {
      return localizations.translate('auth_error_invalid_credentials');
    }

    // 8. Generic unexpected sign-in failure
    return localizations.translate('auth_error_generic');
  }

  void _showError(String msg) {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final isRtl = localizations?.isRtl ?? false;
    final textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = isRtl ? TextAlign.right : TextAlign.left;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            textAlign: textAlign,
            textDirection: textDirection,
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                // Brand logo header
                Center(
                  child: Image.asset(
                    'assets/images/partwk_emblem.png',
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.auto_stories, color: Colors.white, size: 40),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isLogin 
                      ? localizations.translate('login') 
                      : localizations.translate('register'),
                  style: theme.textTheme.displayLarge?.copyWith(fontSize: 28),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  localizations.translate('tagline'),
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                _buildLanguageSelector(context, theme),
                
                // Form Fields
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: localizations.translate('fullname'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@') ? 'Invalid email' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  textAlign: localizations.isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: localizations.textDirection,
                  decoration: InputDecoration(
                    labelText: localizations.translate('password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorMaxLines: 2,
                  ),
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6
                      ? localizations.translate('password_too_short')
                      : null,
                ),
                
                // Forgot Password link
                if (_isLogin)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: Text(
                        localizations.translate('forgot_password'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Primary Action Button
                CustomButton(
                  text: _isLogin 
                      ? localizations.translate('login') 
                      : localizations.translate('register'),
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
                
                const SizedBox(height: 24),
                
                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Google Sign In
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _socialLogin('google'),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(localizations.translate('login_with_google')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Apple Sign In
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _socialLogin('apple'),
                  icon: const Icon(Icons.apple, size: 24),
                  label: Text(localizations.translate('login_with_apple')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Guest Login
                TextButton(
                  onPressed: _isLoading ? null : _guestMode,
                  child: Text(
                    localizations.translate('continue_as_guest'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Switch between Login and Register
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      _isLogin 
                          ? localizations.translate('dont_have_account')
                          : localizations.translate('already_have_account'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(
                        _isLogin 
                            ? localizations.translate('register') 
                            : localizations.translate('login'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.secondary,
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
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, ThemeData theme) {
    final languageState = Provider.of<AppLanguageState>(context);
    final currentLang = languageState.locale.languageCode;

    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageTab(context, 'English', 'en', currentLang, theme, languageState),
              _buildLanguageTab(context, 'کوردی', 'ku', currentLang, theme, languageState),
              _buildLanguageTab(context, 'العربية', 'ar', currentLang, theme, languageState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTab(BuildContext context, String label, String code, String currentLang, ThemeData theme, AppLanguageState languageState) {
    final isSelected = currentLang == code;
    return GestureDetector(
      onTap: () {
        languageState.setLanguage(code);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
