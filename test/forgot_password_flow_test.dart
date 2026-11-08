import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/main.dart';
import 'package:partwk/core/theme/app_theme.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/features/auth/login_register_screen.dart';

class TestAudioService extends AudioService {
  @override bool get isPlaying => false;
  @override double get speed => 1.0;
  @override Duration get position => Duration.zero;
  @override Duration get duration => const Duration(minutes: 15);
  @override String? get currentBookId => null;
  @override String? get currentLangCode => 'en';
  @override String? get currentBookTitle => null;
  @override String? get currentCoverUrl => null;
  @override int get currentChapterIndex => 0;
  @override List<Map<String, dynamic>> get chapters => [];
  @override Duration? get sleepTimerRemaining => null;
  @override bool get isCurrentBookPremium => false;
  @override bool get isGuestRestricted => false;
  @override void clearGuestRestriction() {}
  @override Future<void> init() async {}
  @override Future<void> clearState() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuth;
  late TestAudioService mockAudio;

  setUpAll(() async {
    try {
      final fontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (fontFile.existsSync()) {
        final fontBytes = await fontFile.readAsBytes();
        for (final family in ['Roboto', 'Vazirmatn', 'Outfit', 'Plus Jakarta Sans']) {
          final loader = FontLoader(family);
          loader.addFont(Future.value(ByteData.sublistView(fontBytes)));
          await loader.load();
        }
      }
      final iconFile = File('/Users/peshrawkaramani/Flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final iconBytes = await iconFile.readAsBytes();
        final iconLoader = FontLoader('MaterialIcons');
        iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
        await iconLoader.load();
      }
    } catch (_) {}
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthService();
    mockAudio = TestAudioService();
    AppLocator.auth = mockAuth;
    AppLocator.audio = mockAudio;
  });

  Widget wrapWithApp({required Widget child, required Locale locale}) {
    final langState = AppLanguageState();
    langState.setLanguage(locale.languageCode);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLanguageState>.value(value: langState),
        ChangeNotifierProvider<AppThemeProvider>(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider<AudioService>.value(value: AppLocator.audio),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: (locale.languageCode == 'ku' || locale.languageCode == 'ar') ? 'Vazirmatn' : 'Roboto',
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF97316),
            brightness: Brightness.dark,
          ),
        ),
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ku'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          FallbackMaterialLocalizationDelegate(),
          FallbackCupertinoLocalizationDelegate(),
          FallbackWidgetsLocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
  }

  group('Forgot Password Flow & Trilingual Localization', () {
    testWidgets('Shows email input dialog when email field is empty in EN', (tester) async {
      await tester.pumpWidget(wrapWithApp(child: const LoginRegisterScreen(), locale: const Locale('en')));
      await tester.pumpAndSettle();

      final forgotFinder = find.text('Forgot Password?');
      expect(forgotFinder, findsOneWidget);
      await tester.tap(forgotFinder);
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);

      // Cancel dismisses dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mockAuth.lastResetEmail, isNull);
    });

    testWidgets('Validates invalid email input in Kurdish (KU)', (tester) async {
      await tester.pumpWidget(wrapWithApp(child: const LoginRegisterScreen(), locale: const Locale('ku')));
      await tester.pumpAndSettle();

      final forgotFinder = find.text('وشەی نهێنیت لەبیر چووە؟');
      expect(forgotFinder, findsOneWidget);
      await tester.tap(forgotFinder);
      await tester.pumpAndSettle();

      expect(find.text('وشەی نهێنی نوێ بکەرەوە'), findsOneWidget);

      // Submit invalid email
      await tester.enterText(find.byType(TextField).last, 'invalidemail');
      await tester.tap(find.text('بنێرە'));
      await tester.pumpAndSettle();

      expect(find.text('تکایە ناونیشانی ئیمەیڵێکی دروست بنووسە'), findsOneWidget);
      expect(mockAuth.lastResetEmail, isNull);
    });

    testWidgets('Sends reset email and shows generic success message without account enumeration in Arabic (AR)', (tester) async {
      await tester.pumpWidget(wrapWithApp(child: const LoginRegisterScreen(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      final forgotFinder = find.text('هل نسيت كلمة المرور؟');
      expect(forgotFinder, findsOneWidget);
      await tester.tap(forgotFinder);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'reader@partwk.com');
      await tester.tap(find.text('إرسال'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(mockAuth.lastResetEmail, 'reader@partwk.com');
      expect(find.text('إذا كان هذا البريد الإلكتروني مسجلاً، فقد تم إرسال رابط إعادة تعيين كلمة المرور. يرجى التحقق من بريدك الوارد.'), findsOneWidget);
      expect(find.text('Account Not Found'), findsNothing);
    });

    testWidgets('Handles rate limiting error gracefully with localized message', (tester) async {
      mockAuth.shouldFailResetPassword = true;
      mockAuth.resetPasswordFailureType = 'rate-limit';

      await tester.pumpWidget(wrapWithApp(child: const LoginRegisterScreen(), locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'user@example.com');
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Too many requests. Please try again later.'), findsOneWidget);
    });

    testWidgets('Handles network/offline error gracefully with localized message', (tester) async {
      mockAuth.shouldFailResetPassword = true;
      mockAuth.resetPasswordFailureType = 'network';

      await tester.pumpWidget(wrapWithApp(child: const LoginRegisterScreen(), locale: const Locale('en')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'user@example.com');
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Network error. Please check your internet connection and try again.'), findsOneWidget);
    });
  });
}
