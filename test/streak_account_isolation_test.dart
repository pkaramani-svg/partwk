import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/streak_tracker.dart';
import 'package:partwk/core/widgets/streak_popup_dialog.dart';
import 'package:partwk/models/user.dart';

class SwitchAuth extends MockAuthService {
  UserModel? selected;
  final Map<String, int> rewards = {};
  @override
  UserModel? get currentUser => selected;
  @override
  Future<void> recordActivity() async {
    final id = selected?.id;
    if (id != null) rewards.putIfAbsent(id, () => 1);
  }
}

void main() {
  testWidgets('popup and daily progress remain separate across accounts', (tester) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'completed_keypoints_$today': ['legacy_1','legacy_2','legacy_3','legacy_4'],
      'completed_book_$today': true,
      'last_shown_streak_popup_date': today,
    });
    final auth = SwitchAuth();
    AppLocator.auth = auth;
    final primary = UserModel.fromMap('primary-test', {});
    final family = UserModel.fromMap('family-test', {});
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [AppLocalizationsDelegate()],
      home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () => StreakTracker.checkAndShowStreakPopup(context),
        child: const Text('Open streak'),
      ))),
    ));
    await tester.pumpAndSettle();

    auth.selected = primary;
    expect(await StreakTracker.isStreakMetToday(), isFalse);
    for (var i = 0; i < 4; i++) { await StreakTracker.trackKeypointCompleted('book', i); }
    await StreakTracker.trackKeypointCompleted('book', 3);
    expect(auth.rewards['primary-test'], 1);
    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakPopupDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(StreakPopupDialog), matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakPopupDialog), findsNothing);

    auth.selected = family;
    expect(await StreakTracker.isStreakMetToday(), isFalse);
    await StreakTracker.trackBookCompleted('family-book');
    expect(auth.rewards['family-test'], 1);
    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakPopupDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(StreakPopupDialog), matching: find.byType(ElevatedButton)));
    await tester.pumpAndSettle();
    auth.selected = null;
    expect(await StreakTracker.isStreakMetToday(), isFalse);
    await StreakTracker.trackBookCompleted('signed-out');
    auth.selected = primary;
    expect(await StreakTracker.isStreakMetToday(), isTrue);
    await tester.tap(find.text('Open streak'));
    await tester.pumpAndSettle();
    expect(find.byType(StreakPopupDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('completed_keypoints_$today'), hasLength(4));
  });
}
