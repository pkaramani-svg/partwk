import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_locator.dart';
import 'analytics_service.dart';
import '../../models/admin_popup.dart';
import '../widgets/admin_popup_modal.dart';

class PopupService {
  static const String currentVersion = '2.0';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches active popups from Firestore, checks targeting rules, scheduling bounds, 
  /// and local frequency limitations to show the next eligible popup.
  static Future<void> checkAndShowPopups(BuildContext context) async {
    try {
      if (Firebase.apps.isEmpty) return;
      // 1. Emergency Killswitch Guard
      final globalDoc = await _firestore.collection('settings').doc('global').get();
      if (globalDoc.exists) {
        final data = globalDoc.data();
        if (data != null && data['disableAllPopups'] == true) {
          debugPrint("PopupService: Emergency master switch is active. Blocking all popups.");
          return;
        }
      }

      // 2. Fetch Active Campaigns
      final querySnapshot = await _firestore
          .collection('popups')
          .where('status', isEqualTo: 'active')
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint("PopupService: No active popup campaigns found.");
        return;
      }

      final List<AdminPopup> activePopups = querySnapshot.docs
          .map((doc) => AdminPopup.fromMap(doc.id, doc.data()))
          .toList();

      // Sort by priority (urgent -> important -> normal)
      activePopups.sort((a, b) {
        final priorityOrder = {'urgent': 3, 'important': 2, 'normal': 1};
        final priorityA = priorityOrder[a.priority] ?? 1;
        final priorityB = priorityOrder[b.priority] ?? 1;
        return priorityB.compareTo(priorityA); // Descending order
      });

      final user = AppLocator.auth.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Resolve country code from locale (e.g. en_US -> US, ar_IQ -> IQ)
      String deviceCountry = '';
      try {
        final localeName = Platform.localeName;
        if (localeName.contains('_')) {
          deviceCountry = localeName.split('_').last.toUpperCase();
        } else if (localeName.contains('-')) {
          deviceCountry = localeName.split('-').last.toUpperCase();
        }
      } catch (_) {}

      // Get current UI language code
      final langCode = Localizations.localeOf(context).languageCode;

      for (final popup in activePopups) {
        // A. Scheduling Checks
        if (popup.scheduling.startDate != null && popup.scheduling.startDate!.isNotEmpty) {
          try {
            final start = DateTime.parse(popup.scheduling.startDate!);
            if (now.isBefore(start)) continue; // Not started yet
          } catch (_) {}
        }
        if (popup.scheduling.endDate != null && popup.scheduling.endDate!.isNotEmpty) {
          try {
            final end = DateTime.parse(popup.scheduling.endDate!);
            if (now.isAfter(end)) continue; // Expired
          } catch (_) {}
        }

        // B. Targeting Rules Checks
        final target = popup.targeting;

        // B1. Language targeting
        if (target.languages.isNotEmpty && !target.languages.contains(langCode)) {
          continue;
        }

        // B2. Specific User ID / Email (Higher precedence testing checks)
        if (target.emails.isNotEmpty || target.userIds.isNotEmpty) {
          if (user == null) continue; // specific targeting requires authenticated user
          final emailMatch = target.emails.map((e) => e.trim().toLowerCase()).contains(user.email.trim().toLowerCase());
          final uidMatch = target.userIds.contains(user.id);
          if (!emailMatch && !uidMatch) {
            continue; // targeted to other users
          }
        }

        // B3. Subscription Plans targeting
        if (target.userTypes.isNotEmpty) {
          final String planType;
          if (user == null) {
            planType = 'unregistered';
          } else {
            planType = user.isPremium ? 'premium' : 'free';
          }
          if (!target.userTypes.contains(planType)) {
            continue;
          }
        }

        // B4. Platform targeting
        if (target.platforms.isNotEmpty) {
          final currentPlatform = Platform.isIOS ? 'ios' : 'android';
          if (!target.platforms.contains(currentPlatform)) {
            continue;
          }
        }

        // B5. App Version targeting
        if (target.appVersions.isNotEmpty && !target.appVersions.contains(currentVersion)) {
          continue;
        }

        // B6. Country targeting
        if (target.countries.isNotEmpty && deviceCountry.isNotEmpty && !target.countries.contains(deviceCountry)) {
          continue;
        }

        // C. Frequency Rules Checks (Local cache filters)
        final String seenKey = 'popup_seen_${popup.id}';
        final String dismissedKey = 'popup_dismissed_${popup.id}';
        final String lastShownDateKey = 'popup_last_shown_${popup.id}_date';
        final String lastShownTimeKey = 'popup_last_shown_${popup.id}_time';

        if (popup.frequency == 'once' && prefs.getBool(seenKey) == true) {
          continue;
        }

        if (popup.frequency == 'until_dismissed' && prefs.getBool(dismissedKey) == true) {
          continue;
        }

        if (popup.frequency == 'once_daily') {
          final today = now.toIso8601String().substring(0, 10);
          final lastShownDate = prefs.getString(lastShownDateKey);
          if (lastShownDate == today) continue;
        }

        if (popup.frequency == 'weekly') {
          final lastShownTime = prefs.getInt(lastShownTimeKey);
          if (lastShownTime != null) {
            final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownTime);
            final difference = now.difference(lastShown).inDays;
            if (difference < 7) continue;
          }
        }

        // D. Show the popup dialogue! (Evaluated priority candidate)
        if (context.mounted) {
          debugPrint("PopupService: Launching Popup Modal Campaign: ${popup.id} (${popup.title['en']})");
          
          // Trigger local & Firestore tracking analytics asynchronously
          trackPopupSeen(popup.id);
          
          await showDialog(
            context: context,
            barrierDismissible: popup.priority != 'urgent', // urgent alerts require explicit click dismiss
            builder: (_) => AdminPopupModal(popup: popup),
          );
          
          // Only show one popup alert at a time to prevent overlapping modals
          break;
        }
      }
    } catch (e) {
      debugPrint("PopupService error checking active popups: $e");
    }
  }

  /// Track popup displayed analytics
  static Future<void> trackPopupSeen(String popupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Save local tracking frequencies
      await prefs.setBool('popup_seen_$popupId', true);
      await prefs.setString('popup_last_shown_${popupId}_date', now.toIso8601String().substring(0, 10));
      await prefs.setInt('popup_last_shown_${popupId}_time', now.millisecondsSinceEpoch);

      AnalyticsService.trackEvent('popup_seen', parameters: {'popupId': popupId});
    } catch (e) {
      debugPrint("PopupService: failed tracking popup seen: $e");
    }
  }

  /// Track popup clicked analytics
  static Future<void> trackPopupClicked(String popupId) async {
    try {
      AnalyticsService.trackEvent('popup_clicked', parameters: {'popupId': popupId});
    } catch (e) {
      debugPrint("PopupService: failed tracking popup clicked: $e");
    }
  }

  /// Track popup dismissed analytics
  static Future<void> trackPopupDismissed(String popupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('popup_dismissed_$popupId', true);

      AnalyticsService.trackEvent('popup_dismissed', parameters: {'popupId': popupId});
    } catch (e) {
      debugPrint("PopupService: failed tracking popup dismissed: $e");
    }
  }

  /// Track popup conversion action completion analytics
  static Future<void> trackPopupConversion(String popupId) async {
    try {
      AnalyticsService.trackEvent('popup_conversion', parameters: {'popupId': popupId});
    } catch (e) {
      debugPrint("PopupService: failed tracking popup conversion: $e");
    }
  }
}
