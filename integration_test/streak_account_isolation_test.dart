import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/streak_tracker.dart';
import 'package:partwk/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('daily streaks and rewards stay with their account', (tester) async {
    await tester.runAsync(app.main);
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      // These old keys are intentionally ownerless and must not be adopted.
      await prefs.setStringList('completed_keypoints_$today', ['legacy_0','legacy_1','legacy_2','legacy_3']);
      await prefs.setBool('completed_book_$today', true);
      await prefs.setString('last_shown_streak_popup_date', today);
      await AppLocator.auth.signOut();
      expect(await StreakTracker.isStreakMetToday(), isFalse);
      await StreakTracker.trackBookCompleted('signed-out');

      await AppLocator.auth.signInWithEmailAndPassword('primary@test.invalid', 'Test-only-123!');
      expect(await StreakTracker.isStreakMetToday(), isFalse);
      Future<Map<String, dynamic>> profile(String id) async =>
          (await FirebaseFirestore.instance.doc('users/$id').get(const GetOptions(source: Source.server))).data()!;
      await AppLocator.auth.addLearningTime(40);
      await AppLocator.auth.signOut();
      await AppLocator.auth.signInWithEmailAndPassword('family@test.invalid', 'Test-only-123!');
      await AppLocator.auth.addLearningTime(40);
      // The primary's 40 seconds must not combine with the family's 40.
      expect((await profile('workflow-family'))['streakCount'], 2);
      await AppLocator.auth.signOut();
      await AppLocator.auth.signInWithEmailAndPassword('primary@test.invalid', 'Test-only-123!');
      await AppLocator.auth.addLearningTime(20);
      expect((await profile('workflow-primary'))['streakCount'], 3);
      for (var i = 0; i < 4; i++) {
        await StreakTracker.trackKeypointCompleted('primary-book', i);
      }
      expect(await StreakTracker.isStreakMetToday(), isTrue);
      final primaryAfter = await profile('workflow-primary');
      await StreakTracker.trackKeypointCompleted('primary-book', 3);
      await StreakTracker.trackBookCompleted('primary-book');
      final primaryRepeated = await profile('workflow-primary');
      expect(primaryAfter['streakCount'], 3);
      expect((primaryAfter['unlockedAchievements'] as List).where((id) => id == 'ach-streak-3-en'), hasLength(1));
      expect((primaryRepeated['unlockedAchievements'] as List).where((id) => id == 'ach-streak-3-en'), hasLength(1));
      expect(primaryRepeated['streakCount'], primaryAfter['streakCount']);
      expect(primaryRepeated['lastActiveDate'], primaryAfter['lastActiveDate']);

      await AppLocator.auth.signOut();
      await AppLocator.auth.signInWithEmailAndPassword('family@test.invalid', 'Test-only-123!');
      expect(await StreakTracker.isStreakMetToday(), isFalse);
      await StreakTracker.trackKeypointCompleted('family-book', 0);
      expect(await StreakTracker.isStreakMetToday(), isFalse);
      await StreakTracker.trackBookCompleted('family-book');
      expect(await StreakTracker.isStreakMetToday(), isTrue);
      final familyAfter = await profile('workflow-family');
      await StreakTracker.trackBookCompleted('family-book');
      final familyRepeated = await profile('workflow-family');
      expect(familyAfter['streakCount'], 3);
      expect((familyAfter['unlockedAchievements'] as List).where((id) => id == 'ach-streak-3-en'), hasLength(1));
      expect((familyRepeated['unlockedAchievements'] as List).where((id) => id == 'ach-streak-3-en'), hasLength(1));
      expect(familyRepeated['streakCount'], familyAfter['streakCount']);
      expect(familyRepeated['lastActiveDate'], familyAfter['lastActiveDate']);

      await AppLocator.auth.signOut();
      expect(await StreakTracker.isStreakMetToday(), isFalse);
      await StreakTracker.trackBookCompleted('signed-out');
      await AppLocator.auth.signInWithEmailAndPassword('primary@test.invalid', 'Test-only-123!');
      expect(await StreakTracker.isStreakMetToday(), isTrue);
      final primaryReturn = await profile('workflow-primary');
      expect(primaryReturn['streakCount'], primaryAfter['streakCount']);
      expect(primaryReturn['lastActiveDate'], primaryAfter['lastActiveDate']);
      expect(prefs.getStringList('completed_keypoints_$today'), hasLength(4));
      await AppLocator.auth.signOut();
    });
  });
}
