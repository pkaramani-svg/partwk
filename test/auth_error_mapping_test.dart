import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;

import 'package:partwk/main.dart';
import 'package:partwk/core/theme/app_theme.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/widgets/custom_button.dart';
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

class TestAuthService extends MockAuthService {
  dynamic errorToThrowOnLogin;
  dynamic errorToThrowOnRegister;
  dynamic errorToThrowOnSocial;

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    if (errorToThrowOnLogin != null) {
      throw errorToThrowOnLogin;
    }
  }

  @override
  Future<void> registerWithEmailAndPassword(String name, String email, String password) async {
    if (errorToThrowOnRegister != null) {
      throw errorToThrowOnRegister;
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    if (errorToThrowOnSocial != null) {
      throw errorToThrowOnSocial;
    }
  }

  @override
  Future<void> signInWithApple() async {
    if (errorToThrowOnSocial != null) {
      throw errorToThrowOnSocial;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestAuthService mockAuth;
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
    mockAuth = TestAuthService();
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
      child: Consumer<AppLanguageState>(
        builder: (context, lang, _) {
          return MaterialApp(
            locale: lang.locale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('ku', ''),
              Locale('ar', ''),
            ],
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
          );
        },
      ),
    );
  }

  group('Authentication Error Mapping Tests', () {
    testWidgets('Shows enumeration-safe message in EN on raw invalid-credential error', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = FirebaseAuthException(
        code: 'invalid-credential',
        message: 'The supplied auth credential is incorrect, malformed or has expired.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      // Verify the technical string is NEVER shown
      expect(find.textContaining('invalid-credential'), findsNothing);
      expect(find.textContaining('firebase_auth'), findsNothing);

      // Verify enumeration-safe message is shown
      expect(
        find.text('We couldn’t sign you in. Check your email and password, or register a new account.'),
        findsOneWidget,
      );
    });

    testWidgets('Shows enumeration-safe message in Kurdish Sorani with RTL alignment', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = FirebaseAuthException(
        code: 'user-not-found',
        message: 'There is no user record corresponding to this identifier.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('ku'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      // Verify Kurdish safe message
      const kuMsg = 'نەمانتوانی بچینە ژوورەوە. ئیمەیڵ و وشەی نهێنیت بپشکنە، یاخود هەژمارێکی نوێ دروست بکە.';
      expect(find.text(kuMsg), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text(kuMsg));
      expect(textWidget.textDirection, TextDirection.rtl);
      expect(textWidget.textAlign, TextAlign.right);
    });

    testWidgets('Shows enumeration-safe message in Arabic with RTL alignment', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = FirebaseAuthException(
        code: 'wrong-password',
        message: 'The password is invalid or the user does not have a password.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'user@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      // Verify Arabic safe message
      const arMsg = 'تعذر تسجيل الدخول. تحقق من بريدك الإلكتروني وكلمة المرور، أو سجل حساباً جديداً.';
      expect(find.text(arMsg), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text(arMsg));
      expect(textWidget.textDirection, TextDirection.rtl);
      expect(textWidget.textAlign, TextAlign.right);
    });

    testWidgets('Maps user-disabled error to friendly message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = FirebaseAuthException(
        code: 'user-disabled',
        message: 'The user account has been disabled by an administrator.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'disabled@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('This account has been disabled. Please contact support.'), findsOneWidget);
    });

    testWidgets('Maps too-many-requests error to friendly message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Access to this account has been temporarily disabled due to many failed login attempts.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'locked@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Too many unsuccessful attempts. Please try again later.'), findsOneWidget);
    });

    testWidgets('Maps network failure to friendly message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = FirebaseAuthException(
        code: 'network-request-failed',
        message: 'A network error (such as timeout, interrupted connection or unreachable host) has occurred.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'offline@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Network error. Please check your internet connection and try again.'), findsOneWidget);
    });

    testWidgets('Registration: maps email-already-in-use to friendly message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnRegister = FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use by another account.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Switch to Register mode
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Enter full name, email, password
      await tester.enterText(find.byType(TextFormField).at(0), 'Existing User');
      await tester.enterText(find.byType(TextFormField).at(1), 'existing@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('An account with this email already exists. Please sign in instead.'), findsOneWidget);
    });

    testWidgets('Registration: maps weak-password to friendly message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnRegister = FirebaseAuthException(
        code: 'weak-password',
        message: 'The password must be 6 characters long or more.',
      );

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'New User');
      await tester.enterText(find.byType(TextFormField).at(1), 'new@test.com');
      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      expect(find.text('Password is too weak. Please use at least 6 characters.'), findsOneWidget);
    });

    testWidgets('Social login cancellation is dismissed silently without error banner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnSocial = Exception('User canceled Google Sign In');

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Verify no SnackBar is displayed
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Unrecognized technical exception maps to generic friendly message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockAuth.errorToThrowOnLogin = Exception('CRITICAL_INTERNAL_DB_CORRUPTION_0x899');

      await tester.pumpWidget(wrapWithApp(
        child: const LoginRegisterScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'test@test.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.byType(CustomButton));
      await tester.pumpAndSettle();

      // Technical string must not leak
      expect(find.textContaining('CRITICAL_INTERNAL_DB_CORRUPTION'), findsNothing);
      expect(find.text('An unexpected error occurred. Please try again later.'), findsOneWidget);
    });
  });
}
