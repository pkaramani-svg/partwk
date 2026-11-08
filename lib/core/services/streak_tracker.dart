import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/streak_popup_dialog.dart';
import './service_locator.dart';

class StreakTracker {
  // Legacy keys had no account owner. Leave them untouched and never copy
  // their contents into an account: their ownership cannot be established.
  static String _dailyKey(String kind, String uid, String date) =>
      'streak_v2_${uid}_${kind}_$date';

  static Future<void> trackKeypointCompleted(String bookId, int chapterIndex) async {
    final accountId = AppLocator.auth.currentUser?.id;
    if (accountId == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    
    final key = _dailyKey('completed_keypoints', accountId, today);
    final List<String> list = prefs.getStringList(key) ?? [];
    final item = '${bookId}_$chapterIndex';
    if (!list.contains(item)) {
      list.add(item);
      await prefs.setStringList(key, list);
      debugPrint("StreakTracker: Completed keypoint $item. Total today: ${list.length}");
    }
    
    if (list.length >= 4 && AppLocator.auth.currentUser?.id == accountId) {
      debugPrint("StreakTracker: 4 keypoints completed today! Recording streak activity...");
      await AppLocator.auth.recordActivity();
    }
  }

  static Future<void> trackBookCompleted(String bookId) async {
    final accountId = AppLocator.auth.currentUser?.id;
    if (accountId == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyKey('completed_book', accountId, today), true);
    debugPrint("StreakTracker: Book $bookId fully completed today! Recording streak activity...");
    if (AppLocator.auth.currentUser?.id == accountId) await AppLocator.auth.recordActivity();
  }
  
  static Future<bool> isStreakMetToday() async {
    final accountId = AppLocator.auth.currentUser?.id;
    if (accountId == null) return false;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_dailyKey('completed_keypoints', accountId, today)) ?? [];
    final completedBook = prefs.getBool(_dailyKey('completed_book', accountId, today)) ?? false;
    return AppLocator.auth.currentUser?.id == accountId && (list.length >= 4 || completedBook);
  }

  static Future<void> checkAndShowStreakPopup(BuildContext context) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return;
    
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    
    final popupKey = _dailyKey('popup_shown', user.id, today);
    final lastShownDate = prefs.getString(popupKey);
    if (lastShownDate == today) {
      debugPrint("StreakTracker: Streak popup already shown today.");
      return; 
    }
    
    final metToday = await isStreakMetToday();
    if (metToday) {
      debugPrint("StreakTracker: Streak target met! Launching streak popup dialog...");
      if (context.mounted && AppLocator.auth.currentUser?.id == user.id) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => StreakPopupDialog(streakCount: user.streakCount),
        );
        await prefs.setString(popupKey, today);
      }
    } else {
      debugPrint("StreakTracker: Streak target not yet met today.");
    }
  }
}
