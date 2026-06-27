import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/streak_popup_dialog.dart';
import './service_locator.dart';

class StreakTracker {
  static Future<void> trackKeypointCompleted(String bookId, int chapterIndex) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    
    final key = 'completed_keypoints_$today';
    final List<String> list = prefs.getStringList(key) ?? [];
    final item = '${bookId}_$chapterIndex';
    if (!list.contains(item)) {
      list.add(item);
      await prefs.setStringList(key, list);
      debugPrint("StreakTracker: Completed keypoint $item. Total today: ${list.length}");
    }
    
    if (list.length >= 4) {
      debugPrint("StreakTracker: 4 keypoints completed today! Recording streak activity...");
      await AppLocator.auth.recordActivity();
    }
  }

  static Future<void> trackBookCompleted(String bookId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_book_$today', true);
    debugPrint("StreakTracker: Book $bookId fully completed today! Recording streak activity...");
    await AppLocator.auth.recordActivity();
  }
  
  static Future<bool> isStreakMetToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList('completed_keypoints_$today') ?? [];
    final completedBook = prefs.getBool('completed_book_$today') ?? false;
    return list.length >= 4 || completedBook;
  }

  static Future<void> checkAndShowStreakPopup(BuildContext context) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return;
    
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    
    final lastShownDate = prefs.getString('last_shown_streak_popup_date');
    if (lastShownDate == today) {
      debugPrint("StreakTracker: Streak popup already shown today.");
      return; 
    }
    
    final metToday = await isStreakMetToday();
    if (metToday) {
      debugPrint("StreakTracker: Streak target met! Launching streak popup dialog...");
      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => StreakPopupDialog(streakCount: user.streakCount),
        );
        await prefs.setString('last_shown_streak_popup_date', today);
      }
    } else {
      debugPrint("StreakTracker: Streak target not yet met today.");
    }
  }
}
