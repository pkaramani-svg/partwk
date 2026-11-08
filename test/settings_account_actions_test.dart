import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
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
import 'package:partwk/core/services/family_service.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/features/profile/settings_screen.dart';
import 'package:partwk/features/auth/login_register_screen.dart';

class TestAudioService extends AudioService {
  bool clearStateCalled = false;

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
  @override Future<void> clearState() async {
    clearStateCalled = true;
  }
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestFamilyService extends FamilyService {
  @override
  Future<Map<String, dynamic>> status() async {
    return {
      'membership': null,
      'family': null,
      'entitlement': null,
    };
  }
}

UserModel createTestUser({
  required String id,
  required String name,
  required String email,
  required String langCode,
  String subscriptionStatus = 'free',
  bool hasFamilyPremium = false,
}) {
  return UserModel(
    id: id,
    name: name,
    email: email,
    selectedLanguage: langCode,
    interests: const ['productivity'],
    learningGoals: const ['15_mins'],
    subscriptionStatus: subscriptionStatus,
    hasFamilyPremium: hasFamilyPremium,
    familyMembers: const [],
    savedBooks: const [],
    completedBooks: const [],
    likedBooks: const [],
    listeningProgress: const {},
    readingProgress: const {},
    streakCount: 3,
    lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
    createdAt: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const outDir = '/Users/peshrawkaramani/.gemini/antigravity-ide/brain/b515dc6d-e05e-4d23-9220-75020f850eaf';

  late MockAuthService mockAuth;
  late TestAudioService mockAudio;
  late TestFamilyService mockFamily;

  setUpAll(() async {
    try {
      final fontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (fontFile.existsSync()) {
        final fontBytes = await fontFile.readAsBytes();
        for (final family in [
          'Roboto',
          'Vazirmatn',
          'Outfit',
          'Plus Jakarta Sans',
        ]) {
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
    mockFamily = TestFamilyService();

    AppLocator.auth = mockAuth;
    AppLocator.audio = mockAudio;
    AppLocator.family = mockFamily;
  });

  Future<void> saveScreenshot(WidgetTester tester, GlobalKey repaintKey, String filename) async {
    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('$outDir/$filename');
      await file.writeAsBytes(bytes);
      print('Saved test screenshot: $filename (${bytes.length} bytes)');
    });
  }

  Widget wrapWithApp({
    required Widget child,
    required Locale locale,
    required GlobalKey repaintKey,
  }) {
    final langState = AppLanguageState();
    langState.setLanguage(locale.languageCode);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLanguageState>.value(value: langState),
        ChangeNotifierProvider<AppThemeProvider>(create: (_) => AppThemeProvider()),
        ChangeNotifierProvider<AudioService>.value(value: AppLocator.audio),
      ],
      child: MaterialApp(
        key: ValueKey('test_app_${locale.languageCode}_${repaintKey.hashCode}'),
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
        builder: (context, materialChild) => RepaintBoundary(
          key: repaintKey,
          child: materialChild ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
  }

  group('Partwk Settings Account Actions', () {
    testWidgets('Logout row stops playback and signs out when confirmed', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testUser = createTestUser(id: 'u_test_1', email: 'test@example.com', name: 'Test User', langCode: 'en');
      mockAuth.setUserForTesting(testUser);

      final key = GlobalKey();
      await tester.pumpWidget(wrapWithApp(child: const SettingsScreen(), locale: const Locale('en'), repaintKey: key));
      await tester.pumpAndSettle();

      final logoutTile = find.widgetWithText(ListTile, 'Log out');
      expect(logoutTile, findsOneWidget);
      await tester.ensureVisible(logoutTile);
      await tester.pumpAndSettle();

      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      expect(find.text('Sign Out'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);

      // Safe default: Test Cancel first
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(mockAudio.clearStateCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      // Tap Logout again and confirm
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Sign Out');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockAudio.clearStateCalled, true);
      expect(mockAuth.currentUser, isNull);
      expect(find.byType(LoginRegisterScreen), findsOneWidget);
    });

    testWidgets('Cancellation and failed re-authentication do not delete account', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testUser = createTestUser(id: 'u_test_2', email: 'delete_test@example.com', name: 'Delete User', langCode: 'en');
      mockAuth.setUserForTesting(testUser);

      final key = GlobalKey();
      await tester.pumpWidget(wrapWithApp(child: const SettingsScreen(), locale: const Locale('en'), repaintKey: key));
      await tester.pumpAndSettle();

      final deleteTile = find.widgetWithText(ListTile, 'Delete account');
      expect(deleteTile, findsOneWidget);
      await tester.ensureVisible(deleteTile);
      await tester.pumpAndSettle();

      // 1. Initial Confirmation Dialog: Cancel
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      expect(find.text('Delete Account Permanently?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mockAuth.deleteAccountCalled, false);

      // 2. Initial Confirmation Dialog: Confirm -> Re-auth Dialog: Cancel
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Your Password'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mockAuth.deleteAccountCalled, false);

      // 3. Re-auth Dialog with WRONG password
      mockAuth.shouldFailReauth = true;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'wrongpass');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Authentication failed. Incorrect password or credentials. Your account was not deleted.'), findsOneWidget);
      expect(mockAuth.currentUser, isNotNull);
    });

    testWidgets('Google sign-in user re-authentication: no password field, cancel safety, cancellation and success handling', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final googleUser = createTestUser(id: 'u_google_1', email: 'user@gmail.com', name: 'Google User', langCode: 'en');
      mockAuth.setUserForTesting(googleUser);
      mockAuth.mockProvider = 'google.com';

      final key = GlobalKey();
      await tester.pumpWidget(wrapWithApp(child: const SettingsScreen(), locale: const Locale('en'), repaintKey: key));
      await tester.pumpAndSettle();

      final deleteTile = find.widgetWithText(ListTile, 'Delete account');
      await tester.ensureVisible(deleteTile);
      await tester.pumpAndSettle();

      // 1. Initial Confirmation Dialog -> Confirm
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      // Verify Google Re-auth dialog appears with NO password TextField
      expect(find.text('Re-authenticate with Google'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Verify Cancel as safe default
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mockAuth.deleteAccountCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      // 2. Google Re-auth cancelled by user in picker
      mockAuth.shouldCancelReauth = true;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Re-authentication was canceled. Your account was not deleted.'), findsOneWidget);
      expect(mockAuth.deleteAccountCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 3. Google Re-auth fails with mismatch
      mockAuth.shouldCancelReauth = false;
      mockAuth.shouldFailReauth = true;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Authentication failed. Incorrect password or credentials. Your account was not deleted.'), findsOneWidget);
      expect(mockAuth.deleteAccountCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 4. Google Re-auth succeeds
      mockAuth.shouldFailReauth = false;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(mockAuth.deleteAccountCalled, true);
      expect(mockAuth.currentUser, isNull);
      expect(find.byType(LoginRegisterScreen), findsOneWidget);
    });

    testWidgets('Apple sign-in user re-authentication: no password field, cancel safety, cancellation and success handling', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appleUser = createTestUser(id: 'u_apple_1', email: 'user@icloud.com', name: 'Apple User', langCode: 'en');
      mockAuth.setUserForTesting(appleUser);
      mockAuth.mockProvider = 'apple.com';

      final key = GlobalKey();
      await tester.pumpWidget(wrapWithApp(child: const SettingsScreen(), locale: const Locale('en'), repaintKey: key));
      await tester.pumpAndSettle();

      final deleteTile = find.widgetWithText(ListTile, 'Delete account');
      await tester.ensureVisible(deleteTile);
      await tester.pumpAndSettle();

      // 1. Initial Confirmation Dialog -> Confirm
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      // Verify Apple Re-auth dialog appears with NO password TextField
      expect(find.text('Re-authenticate with Apple'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Verify Cancel as safe default
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(mockAuth.deleteAccountCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      // 2. Apple Re-auth cancelled by user in authorization sheet
      mockAuth.shouldCancelReauth = true;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Apple'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Re-authentication was canceled. Your account was not deleted.'), findsOneWidget);
      expect(mockAuth.deleteAccountCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 3. Apple Re-auth fails with invalid credential
      mockAuth.shouldCancelReauth = false;
      mockAuth.shouldFailReauth = true;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Apple'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Authentication failed. Incorrect password or credentials. Your account was not deleted.'), findsOneWidget);
      expect(mockAuth.deleteAccountCalled, false);
      expect(mockAuth.currentUser, isNotNull);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // 4. Apple Re-auth succeeds
      mockAuth.shouldFailReauth = false;
      await tester.tap(deleteTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Continue with Apple'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(mockAuth.deleteAccountCalled, true);
      expect(mockAuth.currentUser, isNull);
      expect(find.byType(LoginRegisterScreen), findsOneWidget);
    });

    testWidgets('Successful account deletion completes flow and signs out', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testUser = createTestUser(id: 'u_test_3', email: 'success_del@example.com', name: 'Success User', langCode: 'en');
      mockAuth.setUserForTesting(testUser);
      mockAuth.mockProvider = 'password';

      final key = GlobalKey();
      await tester.pumpWidget(wrapWithApp(child: const SettingsScreen(), locale: const Locale('en'), repaintKey: key));
      await tester.pumpAndSettle();

      final deleteTile = find.widgetWithText(ListTile, 'Delete account');
      await tester.ensureVisible(deleteTile);
      await tester.pumpAndSettle();

      await tester.tap(deleteTile);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'correct_password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(mockAuth.deleteAccountCalled, true);
      expect(mockAuth.lastDeletePassword, 'correct_password');
      expect(mockAuth.currentUser, isNull);
      expect(find.byType(LoginRegisterScreen), findsOneWidget);
    });

    testWidgets('Visual Layout and RTL Verification in EN, KU, AR with screenshots', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(1200, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final languages = [
        {
          'locale': const Locale('en'),
          'code': 'en',
          'logout': 'Log out',
          'delete': 'Delete account',
          'deleteBtn': 'Delete Account',
          'account': 'Account',
          'googleBtn': 'Continue with Google',
          'appleBtn': 'Continue with Apple',
        },
        {
          'locale': const Locale('ku'),
          'code': 'ku',
          'logout': 'چوونەدەرەوە',
          'delete': 'سڕینەوەی ئەژمار',
          'deleteBtn': 'سڕینەوەی ئەژمار',
          'account': 'ئەژمار',
          'googleBtn': 'بەردەوامبوون لەگەڵ گووگڵ',
          'appleBtn': 'بەردەوامبوون لەگەڵ ئەپڵ',
        },
        {
          'locale': const Locale('ar'),
          'code': 'ar',
          'logout': 'تسجيل الخروج',
          'delete': 'حذف الحساب',
          'deleteBtn': 'حذف الحساب',
          'account': 'الحساب',
          'googleBtn': 'المتابعة باستخدام Google',
          'appleBtn': 'المتابعة باستخدام Apple',
        },
      ];

      for (final lang in languages) {
        final loc = lang['locale'] as Locale;
        final code = lang['code'] as String;
        final user = createTestUser(
          id: 'u_lang_$code',
          email: 'user_$code@example.com',
          name: 'User $code',
          langCode: code,
        );
        mockAuth.setUserForTesting(user);
        mockAuth.mockProvider = 'password';

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(child: const SettingsScreen(), locale: loc, repaintKey: repaintKey));
        await tester.pumpAndSettle();

        final logoutFinder = find.text(lang['logout'] as String);
        expect(logoutFinder, findsOneWidget);

        final deleteFinder = find.text(lang['delete'] as String);
        await tester.ensureVisible(deleteFinder);
        await tester.pumpAndSettle();

        expect(find.text(lang['account'] as String), findsOneWidget);
        expect(deleteFinder, findsOneWidget);

        // Capture settings view
        await saveScreenshot(tester, repaintKey, 'settings_account_${code}.png');

        // Open Delete Account dialog
        await tester.tap(deleteFinder);
        await tester.pumpAndSettle();
        await saveScreenshot(tester, repaintKey, 'dialog_confirm_${code}.png');

        // Tap Confirm button in dialog to show password re-auth dialog
        final confirmBtn = find.widgetWithText(ElevatedButton, lang['deleteBtn'] as String);
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();
        await saveScreenshot(tester, repaintKey, 'dialog_reauth_password_${code}.png');

        // Cancel dialog
        await tester.tap(find.byType(TextButton).first);
        await tester.pumpAndSettle();

        // Now test and capture Google reauth dialog
        mockAuth.mockProvider = 'google.com';
        await tester.tap(deleteFinder);
        await tester.pumpAndSettle();
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text(lang['googleBtn'] as String), findsOneWidget);
        await saveScreenshot(tester, repaintKey, 'dialog_reauth_google_${code}.png');
        await tester.tap(find.byType(TextButton).first);
        await tester.pumpAndSettle();

        // Now test and capture Apple reauth dialog
        mockAuth.mockProvider = 'apple.com';
        await tester.tap(deleteFinder);
        await tester.pumpAndSettle();
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text(lang['appleBtn'] as String), findsOneWidget);
        await saveScreenshot(tester, repaintKey, 'dialog_reauth_apple_${code}.png');
        await tester.tap(find.byType(TextButton).first);
        await tester.pumpAndSettle();
      }
    });
  });
}
