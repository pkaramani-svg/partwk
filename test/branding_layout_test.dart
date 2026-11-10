import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/features/auth/login_register_screen.dart';
import 'package:partwk/features/auth/onboarding_screen.dart';
import 'package:partwk/main.dart' as app;

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final lang in ['en', 'ku', 'ar']) {
      testWidgets('branding layouts $lang ${size.width}x${size.height}', (tester) async {
        SharedPreferences.setMockInitialValues({'language_code': lang});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Widget screen(Widget child) => ChangeNotifierProvider(
          create: (_) => AppLanguageState(),
          child: MaterialApp(
            locale: Locale(lang),
            supportedLocales: const [Locale('en'), Locale('ku'), Locale('ar')],
            localizationsDelegates: const [
              AppLocalizationsDelegate(), app.FallbackMaterialLocalizationDelegate(),
              app.FallbackCupertinoLocalizationDelegate(), app.FallbackWidgetsLocalizationDelegate(),
              GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: child,
          ),
        );
        await tester.pumpWidget(screen(const OnboardingScreen()));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(screen(const LoginRegisterScreen()));
        await tester.pumpAndSettle();
        final toggleText = lang == 'ku' ? 'تۆمارکردن' : (lang == 'ar' ? 'إنشاء حساب' : 'Create Account');
        await tester.scrollUntilVisible(find.text(toggleText), 250, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text(toggleText));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
