import 'package:flutter/material.dart';
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
      _showError(e.toString());
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      _showError(e.toString());
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
      _showError(e.toString());
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _forgotPassword() async {
    String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      // Show dialog to collect email
      final controller = TextEditingController(text: email);
      final submittedEmail = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reset Password'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter your email address',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('Send'),
              ),
            ],
          );
        },
      );
      if (submittedEmail == null || submittedEmail.isEmpty || !submittedEmail.contains('@')) {
        if (submittedEmail != null) _showError('Invalid email address');
        return;
      }
      email = submittedEmail;
    }
    
    setState(() => _isLoading = true);
    try {
      await AppLocator.auth.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent! Check your inbox (and spam folder).'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Email is not registered')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Account Not Found'),
              content: const Text('This email address is not registered in our system. Please check the email or sign up for a new account.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          _showError(e.toString());
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
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
                // Premium logo header
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.primary,
                          child: const Icon(Icons.auto_stories, color: Colors.white, size: 40),
                        );
                      },
                    ),
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
                  decoration: InputDecoration(
                    labelText: localizations.translate('password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6 ? 'Password too short' : null,
                ),
                
                // Forgot Password link
                if (_isLogin)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _forgotPassword,
                        child: Text(
                          localizations.translate('forgot_password'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin 
                          ? localizations.translate('dont_have_account')
                          : localizations.translate('already_have_account'),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(
                        _isLogin ? 'Sign Up' : 'Login',
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
}
