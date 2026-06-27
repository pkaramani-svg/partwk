import 'dart:io';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../widgets/custom_button.dart';
import '../../services/download_service.dart';

class NetworkGuard {
  static bool? mockConnectionStatus;

  /// Checks if there is an active internet connection by attempting a lookup
  static Future<bool> hasConnection() async {
    if (mockConnectionStatus != null) {
      return mockConnectionStatus!;
    }
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows a beautiful, stylized dialog indicating that internet connection is required
  static void showOfflineDialog(BuildContext context, {String? message}) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lang = localizations.locale.languageCode;

    String title = lang == 'ku' ? 'پێویستت بە ئینتەرنێتە' :
                   lang == 'ar' ? 'مطلوب اتصال بالإنترنت' :
                   'Internet Connection Required';

    String desc = message ?? (
      lang == 'ku' ? 'ئەم تایبەتمەندییە پێویستی بە ئینتەرنێتە. تکایە هێڵەکەت چالاک بکە و دووبارە هەوڵ بدەرەوە.' :
      lang == 'ar' ? 'هذه الميزة تتطلب اتصالاً بالإنترنت. يرجى الاتصال وإعادة المحاولة.' :
      'This feature requires an active internet connection. Please connect and try again.'
    );

    String btnText = lang == 'ku' ? 'باشە' :
                     lang == 'ar' ? 'حسناً' :
                     'OK';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stylized Wi-Fi Off Icon with glassmorphism/gradient feel
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  desc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.65),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: btnText,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Intercepts book details view taps when offline, allowing downloaded books to open
  static Future<void> guardBookNavigation(BuildContext context, String bookId, VoidCallback onGranted) async {
    final hasInternet = await hasConnection();
    if (hasInternet) {
      onGranted();
      return;
    }

    final isDownloaded = DownloadService.isBookDownloadedSync(bookId);
    if (isDownloaded) {
      onGranted();
      return;
    }

    // Show custom offline block warning
    final localizations = AppLocalizations.of(context)!;
    final lang = localizations.locale.languageCode;
    
    final msg = lang == 'ku' ? 'ئەم پەڕتووکە دانەگیراوە بۆ خوێندنەوەی بێ هێڵ. تکایە پەیوەست بە بە ئینتەرنێتەوە بۆ بینینی.' :
                lang == 'ar' ? 'هذا الكتاب غير محمل للقراءة بدون اتصال. يرجى الاتصال بالإنترنت لعرضه.' :
                'This book is not downloaded for offline reading. Please connect to the internet to view it.';
    
    if (context.mounted) {
      showOfflineDialog(context, message: msg);
    }
  }
}
