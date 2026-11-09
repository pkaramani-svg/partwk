import 'package:flutter/material.dart';
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
import 'package:partwk/models/book.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/features/home/new_releases_carousel.dart';
import 'package:partwk/features/auth/login_register_screen.dart';
import 'package:partwk/features/profile/settings_screen.dart';
import 'package:partwk/features/profile/profile_screen.dart';

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

Book createMockBook(String id, String title) {
  return Book(
    id: id,
    title: {'en': '$title (EN)', 'ku': '$title (KU)', 'ar': '$title (AR)'},
    author: {'en': 'Author (EN)', 'ku': 'Author (KU)', 'ar': 'Author (AR)'},
    coverImageUrl: '',
    categoryIds: const ['cat_1'],
    tags: const [],
    description: {'en': 'Desc (EN)', 'ku': 'Desc (KU)', 'ar': 'Desc (AR)'},
    fiveMinuteSummary: const {},
    fifteenMinuteSummary: const {},
    chapterSummaries: const {},
    keyIdeas: const {},
    keyQuotes: const {},
    actionPoints: const {},
    audioUrl: const {},
    duration: 900,
    isPremium: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    hiddenLanguages: const [],
  );
}

UserModel createTestUser({
  required String id,
  required String name,
  required String email,
  String langCode = 'en',
}) {
  return UserModel(
    id: id,
    name: name,
    email: email,
    selectedLanguage: langCode,
    interests: const ['productivity'],
    learningGoals: const ['15_mins'],
    subscriptionStatus: 'free',
    hasFamilyPremium: false,
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

Widget wrapWithApp({
  required Widget child,
  required Locale locale,
  bool disableAnimations = false,
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: (locale.languageCode == 'ku' || locale.languageCode == 'ar')
            ? 'Vazirmatn'
            : 'Roboto',
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
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuth;
  late TestAudioService mockAudio;
  late TestFamilyService mockFamily;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthService();
    mockAudio = TestAudioService();
    mockFamily = TestFamilyService();

    AppLocator.auth = mockAuth;
    AppLocator.audio = mockAudio;
    AppLocator.family = mockFamily;
  });

  group('1. New Releases Gentle Automatic Carousel Tests', () {
    testWidgets('Starts only after 3s idle delay and moves smoothly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final carouselKey = GlobalKey<NewReleasesCarouselState>();
      final books = List.generate(12, (i) => createMockBook('b_$i', 'Book $i'));

      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          child: NewReleasesCarousel(
            key: carouselKey,
            books: books,
            langCode: 'en',
            theme: ThemeData.light(),
          ),
        ),
      );
      await tester.pump();

      final state = carouselKey.currentState!;
      expect(state.scrollController.offset, 0.0);
      expect(state.isAutoScrolling, false);

      // Advance 2 seconds - should still be idle
      await tester.pump(const Duration(seconds: 2));
      expect(state.scrollController.offset, 0.0);
      expect(state.isAutoScrolling, false);

      // Advance past 3 seconds - auto scroll should start
      await tester.pump(const Duration(milliseconds: 1100));
      expect(state.isAutoScrolling, true);

      // Allow animation to progress
      await tester.pump(const Duration(seconds: 1));
      expect(state.scrollController.offset, greaterThan(0.0));
    });

    testWidgets('Pauses immediately on user touch and resumes after 4-5s inactivity', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final carouselKey = GlobalKey<NewReleasesCarouselState>();
      final books = List.generate(12, (i) => createMockBook('b_$i', 'Book $i'));

      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          child: NewReleasesCarousel(
            key: carouselKey,
            books: books,
            langCode: 'en',
            theme: ThemeData.light(),
          ),
        ),
      );
      await tester.pump();

      // Trigger start after 3s
      await tester.pump(const Duration(seconds: 3, milliseconds: 100));
      expect(carouselKey.currentState!.isAutoScrolling, true);

      await tester.pump(const Duration(seconds: 1));
      final offsetBeforeTouch = carouselKey.currentState!.scrollController.offset;
      expect(offsetBeforeTouch, greaterThan(0.0));

      // User touches down
      final gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
      await tester.pump();

      expect(carouselKey.currentState!.isAutoScrolling, false);
      expect(carouselKey.currentState!.isUserInteracting, true);

      // Release finger
      await gesture.up();
      await tester.pump();
      expect(carouselKey.currentState!.isUserInteracting, false);

      // Wait 2 seconds (less than 4.5s resume delay) -> should NOT resume yet
      await tester.pump(const Duration(seconds: 2));
      expect(carouselKey.currentState!.isAutoScrolling, false);

      // Wait remaining delay to exceed 4.5s
      await tester.pump(const Duration(seconds: 3));
      expect(carouselKey.currentState!.isAutoScrolling, true);

      // Resumes from current position, never jumps back to 0
      expect(carouselKey.currentState!.scrollController.offset, greaterThanOrEqualTo(offsetBeforeTouch - 1.0));
    });

    testWidgets('Reduced motion disables auto-scroll completely while keeping row scrollable', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final carouselKey = GlobalKey<NewReleasesCarouselState>();
      final books = List.generate(12, (i) => createMockBook('b_$i', 'Book $i'));

      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          disableAnimations: true,
          child: NewReleasesCarousel(
            key: carouselKey,
            books: books,
            langCode: 'en',
            theme: ThemeData.light(),
          ),
        ),
      );
      await tester.pump();

      // Wait 5 seconds
      await tester.pump(const Duration(seconds: 5));
      expect(carouselKey.currentState!.isAutoScrolling, false);
      expect(carouselKey.currentState!.scrollController.offset, 0.0);
    });

    testWidgets('Does nothing cleanly if too few covers to scroll', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final carouselKey = GlobalKey<NewReleasesCarouselState>();
      final books = [createMockBook('b_1', 'Single Book')];

      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          child: NewReleasesCarousel(
            key: carouselKey,
            books: books,
            langCode: 'en',
            theme: ThemeData.light(),
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(seconds: 4));
      expect(carouselKey.currentState!.isAutoScrolling, false);
      expect(carouselKey.currentState!.scrollController.offset, 0.0);
    });

    testWidgets('Disposes safely without timers continuing in background', (tester) async {
      final carouselKey = GlobalKey<NewReleasesCarouselState>();
      final books = List.generate(10, (i) => createMockBook('b_$i', 'Book $i'));

      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          child: NewReleasesCarousel(
            key: carouselKey,
            books: books,
            langCode: 'en',
            theme: ThemeData.light(),
          ),
        ),
      );
      await tester.pump();

      // Start scrolling
      await tester.pump(const Duration(seconds: 3, milliseconds: 200));

      // Unmount widget
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      // Should not throw timer leaks or exceptions
    });
  });

  group('2. Login Screen Subtitle Localisation Tests', () {
    testWidgets('English subtitle is exact: Premium summaries and fast learning in 15 minutes', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          child: const LoginRegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Premium summaries and fast learning in 15 minutes'),
        findsOneWidget,
      );
    });

    testWidgets('Kurdish Sorani subtitle is exact: پوختەی پڕیمیۆم و فێربوونی خێرا لە ١٥ خولەکدا', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('ku'),
          child: const LoginRegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('پوختەی پڕیمیۆم و فێربوونی خێرا لە ١٥ خولەکدا'),
        findsOneWidget,
      );
    });

    testWidgets('Arabic subtitle is exact: ملخصات مميزة وتعلم سريع في 15 دقيقة', (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('ar'),
          child: const LoginRegisterScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('ملخصات مميزة وتعلم سريع في 15 دقيقة'),
        findsOneWidget,
      );
    });
  });

  group('3. Kurdish Logout Wording Tests in Settings and Profile', () {
    testWidgets('Kurdish logout subtitle in Settings and Profile is exactly: چوونەدەرەوە لە پرۆفایلەکەت', (tester) async {
      final user = createTestUser(
        id: 'u_kurdish',
        name: 'Peshraw',
        email: 'peshraw@example.com',
        langCode: 'ku',
      );
      mockAuth.setUserForTesting(user);

      // Verify SettingsScreen
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('ku'),
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('چوونەدەرەوە لە پرۆفایلەکەت'), findsOneWidget);
      expect(find.text('چوونەدەرەوە لە دانیشتنی پرۆفایلەکەت'), findsNothing);

      // Verify ProfileScreen
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('ku'),
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('چوونەدەرەوە لە پرۆفایلەکەت'), findsOneWidget);
      expect(find.text('چوونەدەرەوە لە دانیشتنی پرۆفایلەکەت'), findsNothing);
    });

    testWidgets('English and Arabic logout subtitles remain unchanged', (tester) async {
      final user = createTestUser(
        id: 'u_test',
        name: 'User',
        email: 'user@example.com',
      );
      mockAuth.setUserForTesting(user);

      // English Settings
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('en'),
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Log out of your profile session'), findsOneWidget);

      // Arabic Settings
      await tester.pumpWidget(
        wrapWithApp(
          locale: const Locale('ar'),
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تسجيل الخروج من جلسة ملفك الشخصي'), findsOneWidget);
    });
  });
}
