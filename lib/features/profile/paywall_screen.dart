import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/custom_button.dart';
import '../auth/login_register_screen.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({Key? key}) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedPlanIndex = 0;
  bool _isLoading = false;
  bool _isRestoring = false;

  void _showGuestWarning(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final localizations = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            localizations.translate('register_required_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(localizations.translate('register_required_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(localizations.translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close paywall screen
                
                // Stop any running guest audio
                AppLocator.audio.stop();
                
                // Sign out of the guest account
                await AppLocator.auth.signOut();
                
                // Navigate to Login/Register Screen, clearing history
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(localizations.translate('register_now')),
            ),
          ],
        );
      },
    );
  }

  void _subscribe() async {
    if (AppLocator.auth.isGuest) {
      _showGuestWarning(context);
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    await AppLocator.auth.upgradeToPremium();
    if (mounted) {
      setState(() => _isLoading = false);
      final localizations = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.translate('welcome_premium')),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _restorePurchases() async {
    if (AppLocator.auth.isGuest) {
      _showGuestWarning(context);
      return;
    }
    setState(() => _isRestoring = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    await AppLocator.auth.upgradeToPremium();
    if (mounted) {
      setState(() => _isRestoring = false);
      final localizations = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.translate('restore_success')),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    final List<Map<String, String>> plans = [
      {
        'title': localizations.translate('annual_plan'),
        'price': localizations.translate('annual_price_desc'),
        'saving': '',
        'trial': localizations.translate('annual_trial_desc'),
      },
    ];

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient decoration
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary.withOpacity(0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Header title
                  const Center(
                    child: Icon(Icons.workspace_premium, color: Colors.amber, size: 72),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.translate('go_premium'),
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.translate('go_premium_desc'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Key Features Checklist
                  _buildFeatureRow(context, localizations.translate('paywall_feat_1')),
                  _buildFeatureRow(context, localizations.translate('paywall_feat_2')),
                  _buildFeatureRow(context, localizations.translate('paywall_feat_3')),
                  _buildFeatureRow(context, localizations.translate('paywall_feat_4')),
                  _buildFeatureRow(context, localizations.translate('paywall_feat_5')),
                  _buildFeatureRow(context, localizations.translate('paywall_feat_6')),
                  
                  const SizedBox(height: 36),

                  // Plans selector
                  ...List.generate(plans.length, (index) {
                    final plan = plans[index];
                    final isSelected = _selectedPlanIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPlanIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Colors.white.withOpacity(0.15) 
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.amber : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        plan['title']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (plan['saving']!.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            plan['saving']!,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9,
                                            ),
                                          ),
                                        )
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan['trial']!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              plan['price']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Subscribe trigger button
                  CustomButton(
                    text: localizations.translate('subscribe_now'),
                    isLoading: _isLoading,
                    onPressed: _subscribe,
                  ),
                  
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _isRestoring ? null : _restorePurchases,
                    child: _isRestoring
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                          )
                        : Text(
                            localizations.translate('restore_purchases'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          )
        ],
      ),
    );
  }
}
