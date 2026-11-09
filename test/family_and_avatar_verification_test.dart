import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:partwk/features/profile/profile_screen.dart';

class FakeTestAudioService extends AudioService {
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

class MockFamilyServiceTest extends FamilyService {
  MockFamilyServiceTest({
    this.statusResult,
    this.statusError,
  });

  Map<String, dynamic>? statusResult;
  Object? statusError;
  bool inviteCalled = false;
  String? invitedEmail;
  bool cancelCalled = false;
  bool removeCalled = false;
  bool leaveCalled = false;
  bool acceptCalled = false;

  @override
  Future<Map<String, dynamic>> status() async {
    if (statusError != null) throw statusError!;
    return statusResult ?? {};
  }

  @override
  Future<Map<String, dynamic>> invite(String email, {String? language}) async {
    inviteCalled = true;
    invitedEmail = email;
    return {'message': 'Invitation sent'};
  }

  @override
  Future<Map<String, dynamic>> cancel() async {
    cancelCalled = true;
    return {'status': 'cancelled'};
  }

  @override
  Future<Map<String, dynamic>> remove() async {
    removeCalled = true;
    return {'status': 'removed'};
  }

  @override
  Future<Map<String, dynamic>> leave() async {
    leaveCalled = true;
    return {'status': 'left'};
  }

  @override
  Future<Map<String, dynamic>> accept() async {
    acceptCalled = true;
    return {'status': 'active'};
  }
}

UserModel createTestUser({
  required String id,
  required String name,
  required String email,
  required String langCode,
  String subscriptionStatus = 'premium',
  bool hasFamilyPremium = false,
  String? profilePictureUrl,
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
    profilePictureUrl: profilePictureUrl,
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
  late MockFamilyServiceTest mockFamily;
  late FakeTestAudioService mockAudio;

  setUpAll(() async {
    try {
      final fontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (fontFile.existsSync()) {
        final fontBytes = await fontFile.readAsBytes();

        for (final family in [
          'Roboto',
          'Roboto-Regular',
          'Roboto-Bold',
          'Roboto-Medium',
          'Vazirmatn',
          'Vazirmatn-Regular',
          'Vazirmatn-Bold',
          'Vazirmatn-SemiBold',
          'Vazirmatn-Medium',
          'Outfit',
          'Outfit-Regular',
          'Outfit-Bold',
          'Outfit-SemiBold',
          'Outfit-Medium',
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
    } catch (e) {
      print('Font load notice: $e');
    }
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('partwk_test_');
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall call) async => tempDir.path);

    SharedPreferences.setMockInitialValues({});

    mockAuth = MockAuthService();
    mockFamily = MockFamilyServiceTest();
    mockAudio = FakeTestAudioService();

    AppLocator.auth = mockAuth;
    AppLocator.family = mockFamily;
    AppLocator.audio = mockAudio;
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
      print('Captured: $filename (${bytes.length} bytes)');
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

  testWidgets('1. Profile Avatar Selection: Localised and Accessible across EN, KU, AR', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(800, 1600); // 400x800 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final languages = [
      {'code': 'en', 'title': 'Choose Profile Avatar', 'male': 'Male Avatars'},
      {'code': 'ku', 'title': 'وێنۆچکەی پرۆفایل هەڵبژێرە', 'male': 'وێنۆچکەی پیاوان'},
      {'code': 'ar', 'title': 'اختر الصورة الرمزية للملف الشخصي', 'male': 'صور رمزية للرجال'},
    ];

    for (final lang in languages) {
      final code = lang['code']!;
      final locale = Locale(code);

      final user = createTestUser(
        id: 'user_avatar_test',
        name: 'Tester',
        email: 'test@partwk.com',
        langCode: code,
        subscriptionStatus: 'premium',
        profilePictureUrl: 'assets/avatars/male_0.png',
      );
      mockAuth.setUserForTesting(user);

      final repaintKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const ProfileScreen(),
        locale: locale,
        repaintKey: repaintKey,
      ));
      await tester.pumpAndSettle();

      // Tap on avatar to open avatar bottom sheet picker
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();

      // Verify title is localized
      expect(find.text(lang['title']!), findsOneWidget);
      expect(find.text(lang['male']!), findsOneWidget);

      // Verify Semantics
      expect(find.byType(Semantics), findsWidgets);

      // Capture screenshot of Avatar Selection Dialog
      await saveScreenshot(tester, repaintKey, 'avatar_picker_${code}.png');

      // Close bottom sheet
      final closeBtn = find.byIcon(Icons.close);
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('2. Family Sharing 6 States: Verified and Captured across EN, KU, AR', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final languages = [
      {'code': 'en', 'prefix': 'EN'},
      {'code': 'ku', 'prefix': 'KU'},
      {'code': 'ar', 'prefix': 'AR'},
    ];

    for (final lang in languages) {
      final code = lang['code']!;
      final locale = Locale(code);

      // --- STATE 1: Primary Premium with NO member & NO invite ---
      {
        final user = createTestUser(
          id: 'primary_owner_1',
          name: 'Primary User',
          email: 'primary@partwk.com',
          langCode: code,
          subscriptionStatus: 'premium',
          hasFamilyPremium: false,
        );
        mockAuth.setUserForTesting(user);
        mockFamily.statusResult = {
          'membership': null,
          'family': {'ownerUid': user.id},
          'entitlement': {'status': 'active', 'source': 'store'},
        };
        mockFamily.statusError = null;

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          child: const SettingsScreen(),
          locale: locale,
          repaintKey: repaintKey,
        ));
        await tester.pumpAndSettle();

        // Must show email field and invite button
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);

        // Verify localized label above the field is displayed
        final expectedLabels = {
          'en': "Family member's email address",
          'ku': 'ناونیشانی ئیمەیڵی ئەندامی خێزان',
          'ar': 'عنوان البريد الإلكتروني لفرد العائلة',
        };
        expect(find.text(expectedLabels[code]!), findsOneWidget);

        // Initially, empty email means invite button is disabled
        final inviteBtnFinder = find.byType(ElevatedButton);
        ElevatedButton buttonWidget = tester.widget(inviteBtnFinder);
        expect(buttonWidget.onPressed, isNull);

        // Test invalid email format: button remains disabled
        await tester.enterText(find.byType(TextField), 'invalid-email');
        await tester.pumpAndSettle();
        buttonWidget = tester.widget(inviteBtnFinder);
        expect(buttonWidget.onPressed, isNull);

        // Test own email: button remains disabled and shows localized error
        await tester.enterText(find.byType(TextField), 'primary@partwk.com');
        await tester.pumpAndSettle();
        buttonWidget = tester.widget(inviteBtnFinder);
        expect(buttonWidget.onPressed, isNull);
        final expectedOwnErrors = {
          'en': 'You cannot invite your own account.',
          'ku': 'ناتوانیت ئەژماری خۆت بانگهێشت بکەیت.',
          'ar': 'لا يمكنك إرسال دعوة إلى حسابك الخاص.',
        };
        expect(find.text(expectedOwnErrors[code]!), findsOneWidget);

        // Test syntactically valid email: button becomes enabled
        await tester.enterText(find.byType(TextField), 'family.member@example.com');
        await tester.pumpAndSettle();
        buttonWidget = tester.widget(inviteBtnFinder);
        expect(buttonWidget.onPressed, isNotNull);

        // Must NOT show cancel or remove button
        expect(find.byIcon(Icons.cancel_outlined), findsNothing);
        expect(find.byIcon(Icons.person_remove_outlined), findsNothing);

        // Capture screenshot showing the visible email field with valid entered email and enabled Invite button
        await saveScreenshot(tester, repaintKey, 'family_state1_primary_no_member_${code}.png');
        await saveScreenshot(tester, repaintKey, 'family_invite_enabled_${code}.png');
      }

      // --- STATE 2: Primary Premium with PENDING invite ---
      {
        final user = createTestUser(
          id: 'primary_owner_2',
          name: 'Primary User',
          email: 'primary@partwk.com',
          langCode: code,
          subscriptionStatus: 'premium',
          hasFamilyPremium: false,
        );
        mockAuth.setUserForTesting(user);
        mockFamily.statusResult = {
          'membership': null,
          'family': {
            'ownerUid': user.id,
            'invitation': {
              'recipientUid': 'user_invited_77',
              'recipientEmail': 'sibling.pending@example.com',
            },
          },
          'entitlement': {'status': 'active', 'source': 'store'},
        };
        mockFamily.statusError = null;

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          child: const SettingsScreen(),
          locale: locale,
          repaintKey: repaintKey,
        ));
        await tester.pumpAndSettle();

        // Must display the invited email address
        expect(find.text('sibling.pending@example.com'), findsOneWidget);
        // Must show cancel invitation action
        expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
        // Must HIDE email input text field (slot is reserved)
        expect(find.byType(TextField), findsNothing);

        await saveScreenshot(tester, repaintKey, 'family_state2_pending_invite_${code}.png');
      }

      // --- STATE 3: Primary Premium with ACCEPTED member ---
      {
        final user = createTestUser(
          id: 'primary_owner_3',
          name: 'Primary User',
          email: 'primary@partwk.com',
          langCode: code,
          subscriptionStatus: 'premium',
          hasFamilyPremium: false,
        );
        mockAuth.setUserForTesting(user);
        mockFamily.statusResult = {
          'membership': null,
          'family': {
            'ownerUid': user.id,
            'memberUid': 'member_user_88',
            'memberEmail': 'spouse.active@example.com',
          },
          'entitlement': {'status': 'active', 'source': 'store'},
        };
        mockFamily.statusError = null;

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          child: const SettingsScreen(),
          locale: locale,
          repaintKey: repaintKey,
        ));
        await tester.pumpAndSettle();

        // Must display the member email address
        expect(find.text('spouse.active@example.com'), findsOneWidget);
        // Must show remove member action
        expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
        // Must HIDE email input text field (slot in use)
        expect(find.byType(TextField), findsNothing);

        await saveScreenshot(tester, repaintKey, 'family_state3_accepted_member_${code}.png');
      }

      // --- STATE 4: LINKED family member ---
      {
        final user = createTestUser(
          id: 'linked_member_4',
          name: 'Family Member',
          email: 'member@partwk.com',
          langCode: code,
          subscriptionStatus: 'premium',
          hasFamilyPremium: true,
        );
        mockAuth.setUserForTesting(user);
        mockFamily.statusResult = {
          'membership': {
            'ownerUid': 'primary_owner_99',
            'memberUid': user.id,
            'state': 'active',
          },
          'family': null,
          'entitlement': {'status': 'active', 'source': 'family'},
        };
        mockFamily.statusError = null;

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          child: const SettingsScreen(),
          locale: locale,
          repaintKey: repaintKey,
        ));
        await tester.pumpAndSettle();

        // Must show safe Leave button
        expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
        // Must NEVER show email input or invite button
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
        expect(find.byIcon(Icons.cancel_outlined), findsNothing);

        await saveScreenshot(tester, repaintKey, 'family_state4_linked_member_${code}.png');
      }

      // --- STATE 5: FREE user ---
      {
        final user = createTestUser(
          id: 'free_user_5',
          name: 'Free User',
          email: 'free@partwk.com',
          langCode: code,
          subscriptionStatus: 'free',
          hasFamilyPremium: false,
        );
        mockAuth.setUserForTesting(user);
        mockFamily.statusResult = {
          'membership': null,
          'family': null,
          'entitlement': {'status': 'inactive', 'source': 'none'},
        };
        mockFamily.statusError = null;

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          child: const SettingsScreen(),
          locale: locale,
          repaintKey: repaintKey,
        ));
        await tester.pumpAndSettle();

        // Must show upgrade star button
        expect(find.byIcon(Icons.star), findsOneWidget);
        // Must NEVER show email input or invite button
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.cancel_outlined), findsNothing);
        expect(find.byIcon(Icons.person_remove_outlined), findsNothing);

        await saveScreenshot(tester, repaintKey, 'family_state5_free_user_${code}.png');
      }

      // --- STATE 6: OFFLINE / LOAD ERROR state ---
      {
        final user = createTestUser(
          id: 'primary_owner_6',
          name: 'Primary User',
          email: 'primary@partwk.com',
          langCode: code,
          subscriptionStatus: 'premium',
          hasFamilyPremium: false,
        );
        mockAuth.setUserForTesting(user);
        mockFamily.statusResult = null;
        mockFamily.statusError = Exception('Simulated offline failure');

        final repaintKey = GlobalKey();
        await tester.pumpWidget(wrapWithApp(
          child: const SettingsScreen(),
          locale: locale,
          repaintKey: repaintKey,
        ));
        await tester.pumpAndSettle();

        // Must show offline wifi off icon
        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        // Must show retry button
        expect(find.byIcon(Icons.refresh), findsOneWidget);

        // Verify that NO English fallback leaks in KU or AR
        if (code == 'ku' || code == 'ar') {
          expect(find.text('Family status is unavailable. Connect to the internet and try again.'), findsNothing);
          expect(find.text('Unable to Load Family Status'), findsNothing);
        }

        await saveScreenshot(tester, repaintKey, 'family_state6_offline_error_${code}.png');
      }
    }
  });
}
