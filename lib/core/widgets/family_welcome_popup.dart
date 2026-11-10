import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import '../localization/app_localizations.dart';

class FamilyWelcomePopup {
  static const String _prefPrefix = 'family_welcome_popup_shown_';

  /// Shows the one-time welcome popup to a newly activated Family Premium recipient.
  /// Strictly checks:
  /// 1. Entitlement is active and sourced from family (never shown to primary paid subscribers).
  /// 2. Has never been shown on this device for this user ID.
  /// 3. Marks as seen only after it is actually displayed.
  static Future<bool> showIfNeeded(
    BuildContext context,
    UserModel user, {
    Map<String, dynamic>? entitlement,
    bool force = false,
  }) async {
    // 1. Guard against primary subscribers: Never show to primary paid subscribers
    final isFamilyRecipient = (entitlement != null &&
            entitlement['source'] == 'family' &&
            entitlement['status'] == 'active') ||
        (user.hasFamilyPremium && user.subscriptionStatus != 'premium');

    if (!isFamilyRecipient && !force) {
      return false;
    }

    // 2. Check if already displayed
    final prefs = await SharedPreferences.getInstance();
    final prefKey = '$_prefPrefix${user.id}';
    if (!force && (prefs.getBool(prefKey) ?? false)) {
      return false;
    }

    if (!context.mounted) return false;

    // 3. Mark as shown now that we are presenting it
    await prefs.setBool(prefKey, true);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => buildDialogWidget(dialogContext),
    );

    return true;
  }

  /// Builds the dialog widget directly (useful for tests and previews)
  static Widget buildDialogWidget(BuildContext context, {VoidCallback? onDismiss}) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRtl = localizations?.isRtl ?? false;

    final title = localizations?.translate('family_welcome_popup_title') ??
        'Welcome to Partwk Premium';
    final body = localizations?.translate('family_welcome_popup_body') ??
        'You now have Premium access through Family Sharing. You can read, listen and download eligible book summaries. If your access does not appear after a short moment, please log out and sign back in.';
    final btnText = localizations?.translate('family_welcome_popup_btn') ?? 'Got it';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Partwk Brand Logo / Emblem
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7B00).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF7B00).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Image.asset(
                      'assets/images/partwk_emblem.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.family_restroom,
                        color: Color(0xFFFF7B00),
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),

              // Family Sharing Subtitle / Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7B00).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 14,
                      color: Color(0xFFFF7B00),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        localizations?.translate('family_premium_member_badge') ??
                            'Premium through Family Sharing',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF7B00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Informational Body
              Text(
                body,
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.55,
                  fontSize: 14,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 24),

              // Confirmation Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDismiss ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7B00),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    btnText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
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
