import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:partwk/main.dart' as app;
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/features/auth/onboarding_screen.dart';
import 'package:partwk/features/auth/login_register_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual welcome and authentication branding screens', (tester) async {
    await tester.runAsync(app.main);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(app.navigatorKey.currentState, isNotNull);
    await tester.runAsync(binding.convertFlutterSurfaceToImage);
    Future<void> capture(String name) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        final bytes = await binding.takeScreenshot(name);
        final dir = await getExternalStorageDirectory();
        await File('${dir!.path}/$name.png').writeAsBytes(bytes);
      });
      debugPrint('BRANDING_CAPTURE $name');
    }

    app.navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await capture('welcome_en');
    app.navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const LoginRegisterScreen()));
    await tester.pumpAndSettle();
    await capture('login_en');
    await tester.scrollUntilVisible(find.text('Sign Up'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await capture('registration_en');
    for (final language in ['ku', 'ar']) {
      Provider.of<AppLanguageState>(app.navigatorKey.currentContext!, listen: false).setLanguage(language);
      await tester.pumpAndSettle();
      await capture('registration_$language');
    }
    debugPrint('BRANDING_CAPTURES_READY');
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 45)));
  });
}
