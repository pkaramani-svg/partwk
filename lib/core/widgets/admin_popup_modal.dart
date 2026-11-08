import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../localization/app_localizations.dart';
import '../services/popup_service.dart';
import '../../models/admin_popup.dart';
import '../../features/profile/paywall_screen.dart';
import '../../features/book/book_details_screen.dart';

class AdminPopupModal extends StatefulWidget {
  final AdminPopup popup;
  const AdminPopupModal({Key? key, required this.popup}) : super(key: key);

  @override
  State<AdminPopupModal> createState() => _AdminPopupModalState();
}

class _AdminPopupModalState extends State<AdminPopupModal> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleActionClick(BuildContext context) async {
    final url = widget.popup.actionUrl;
    if (url == null || url.isEmpty) return;

    // Track conversion click statistics
    PopupService.trackPopupConversion(widget.popup.id);
    PopupService.trackPopupClicked(widget.popup.id);

    // Dismiss the modal overlay first
    Navigator.of(context).pop();

    // Check for in-app deep linking
    if (url.startsWith('partwk://')) {
      if (url == 'partwk://paywall') {
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaywallScreen()),
          );
        }
      } else if (url.startsWith('partwk://book/')) {
        final bookId = url.replaceFirst('partwk://book/', '');
        if (bookId.isNotEmpty && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BookDetailsScreen(bookId: bookId)),
          );
        }
      }
    } else {
      // Open external web URLs
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint("Error launching external popup action URL: $e");
      }
    }
  }

  void _handleDismiss(BuildContext context) {
    PopupService.trackPopupDismissed(widget.popup.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final langCode = localizations?.locale.languageCode ?? 'en';
    final isRtl = localizations?.isRtl ?? false;

    final titleText = widget.popup.getLocalizedTitle(langCode);
    final bodyText = widget.popup.getLocalizedBody(langCode);
    final actionText = widget.popup.getLocalizedActionText(langCode);

    // Priority Styling Config
    Color priorityColor;
    IconData priorityIcon;
    List<BoxShadow> glowShadows = [];

    switch (widget.popup.priority) {
      case 'urgent':
        priorityColor = Colors.redAccent;
        priorityIcon = Icons.shield_outlined;
        glowShadows = [
          BoxShadow(
            color: Colors.red.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
          )
        ];
        break;
      case 'important':
        priorityColor = Colors.orangeAccent;
        priorityIcon = Icons.warning_amber_rounded;
        glowShadows = [
          BoxShadow(
            color: Colors.orange.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: 1,
          )
        ];
        break;
      default: // normal
        priorityColor = theme.colorScheme.secondary;
        priorityIcon = Icons.info_outline;
        glowShadows = [
          BoxShadow(
            color: theme.colorScheme.secondary.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 0,
          )
        ];
    }

    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: priorityColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  // Glowing Priority Icon Indicator
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      boxShadow: glowShadows,
                    ),
                    child: Center(
                      child: Icon(
                        priorityIcon,
                        color: priorityColor,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Localized Title
                  Text(
                    titleText,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Image banner inside modal if present
                  if (widget.popup.imageUrl != null && widget.popup.imageUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.popup.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Localized body descriptions
                  Text(
                    bodyText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade400,
                      height: 1.45,
                      fontSize: 13.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Dual buttons action rows
                  Column(
                    children: [
                      if (widget.popup.actionUrl != null && widget.popup.actionUrl!.isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: priorityColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => _handleActionClick(context),
                            child: Text(
                              actionText,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.white.withOpacity(0.06)),
                            ),
                          ),
                          onPressed: () => _handleDismiss(context),
                          child: Text(
                            langCode == 'ku'
                                ? 'داخستن'
                                : langCode == 'ar'
                                    ? 'إغلاق'
                                    : 'Close',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      ),
    );
  }
}
