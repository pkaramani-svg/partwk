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
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/services/user_notification_service.dart';
import 'package:partwk/services/download_service.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/models/user_notification.dart';
import 'package:partwk/features/home/main_navigation.dart';
import 'package:partwk/features/auth/language_selection_screen.dart';
import 'package:partwk/features/notifications/notifications_screen.dart';
import 'package:partwk/features/library/saved_library_screen.dart';
import 'package:partwk/core/widgets/streak_popup_dialog.dart';

class FakeScreenshotAudioService extends AudioService {
  @override
  bool get isPlaying => false;
  @override
  double get speed => 1.0;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => const Duration(minutes: 15);
  @override
  String? get currentBookId => null;
  @override
  String? get currentLangCode => 'en';
  @override
  String? get currentBookTitle => null;
  @override
  String? get currentCoverUrl => null;
  @override
  int get currentChapterIndex => 0;
  @override
  List<Map<String, dynamic>> get chapters => [];
  @override
  Duration? get sleepTimerRemaining => null;
  @override
  bool get isCurrentBookPremium => false;
  @override
  bool get isGuestRestricted => false;
  @override
  void clearGuestRestriction() {}
  @override
  Future<void> init() async {}
  @override
  Future<void> clearState() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ScreenshotDatabaseService extends MockDatabaseService {
  @override
  Future<List<Book>> fetchBooks() async => books;
  @override
  Future<List<Category>> fetchCategories() async => categories;
  @override
  Future<List<Book>> fetchTrendingBooks(List<Book> allBooks) async => allBooks;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  const outDir = '/Users/peshrawkaramani/.gemini/antigravity-ide/brain/b515dc6d-e05e-4d23-9220-75020f850eaf';

  late MockAuthService mockAuth;
  late ScreenshotDatabaseService mockDb;
  late FakeScreenshotAudioService mockAudio;

  setUpAll(() async {
    try {
      final iconFile = File('/Users/peshrawkaramani/Flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final iconBytes = await iconFile.readAsBytes();
        final iconLoader = FontLoader('MaterialIcons');
        iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
        await iconLoader.load();
      }

      final fontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (fontFile.existsSync()) {
        final fontBytes = await fontFile.readAsBytes();
        for (final family in ['Roboto', 'Vazirmatn', 'Plus Jakarta Sans']) {
          final loader = FontLoader(family);
          loader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
          await loader.load();
        }
      }
    } catch (e) {
      print('Font load error: $e');
    }
  });

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('partwk_screen_test_');
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall call) async {
      return tempDir.path;
    });

    mockAuth = MockAuthService();
    mockDb = ScreenshotDatabaseService();
    mockAudio = FakeScreenshotAudioService();

    SharedPreferences.setMockInitialValues({
      'seen_book_ids': mockDb.books.map((b) => b.id).toList(),
      'last_shown_expiry_date': DateTime.now().toIso8601String(),
    });

    AppLocator.auth = mockAuth;
    AppLocator.db = mockDb;
    AppLocator.audio = mockAudio;

    final testUser = UserModel(
      id: 'screenshot_user_42',
      name: 'Peshraw Karamani',
      email: 'peshraw@partwk.com',
      selectedLanguage: 'en',
      interests: ['productivity'],
      learningGoals: ['15_mins'],
      savedBooks: [mockDb.books.first.id],
      completedBooks: [mockDb.books.last.id],
      likedBooks: [mockDb.books.first.id],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'premium',
      streakCount: 5,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    mockAuth.setUserForTesting(testUser);

    await UserNotificationService().init();
    await DownloadService.init();

    // Cache 2 downloaded books so Downloaded Books quota shows 2 / 3
    if (mockDb.books.isNotEmpty) {
      await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[0], 'en', userId: testUser.id);
      if (mockDb.books.length > 1) {
        await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[1], 'en', userId: testUser.id);
      }
    }
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
      print('Saved screenshot: $filename (${bytes.length} bytes)');
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
        key: ValueKey('screen_${locale.languageCode}_${repaintKey.hashCode}'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getTheme(locale.languageCode, true).copyWith(
          textTheme: Typography.material2021().white.apply(
            fontFamily: (locale.languageCode == 'ku' || locale.languageCode == 'ar') ? 'Vazirmatn' : 'Roboto',
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
        home: RepaintBoundary(
          key: repaintKey,
          child: child,
        ),
      ),
    );
  }

  testWidgets('Capture UI Improvements Screenshots across EN, KU, AR', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(800, 1600); // 400 x 800 logical phone
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'ku', 'name': 'Kurdish'},
      {'code': 'ar', 'name': 'Arabic'},
    ];

    for (final lang in languages) {
      final code = lang['code']!;
      final locale = Locale(code);

      // 1. Home Screen / Header (Settings gear beside badged notification bell)
      final homeKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const MainNavigation(),
        locale: locale,
        repaintKey: homeKey,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, homeKey, 'ui_${code}_1_home_header.png');

      // 2. Search Tab & Screen (Tap search tab in bottom navigation)
      NavigationController.selectTab(1);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, homeKey, 'ui_${code}_2_search_tab.png');

      // Reset back to tab 0 for next iterations
      NavigationController.selectTab(0);

      // 3. Language Selection Screen
      final langKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const LanguageSelectionScreen(isFromSettings: true),
        locale: locale,
        repaintKey: langKey,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, langKey, 'ui_${code}_3_language_selection.png');

      // 4. My Library Screen (Showing Downloaded Books row with quota + updated icons)
      final libKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const Scaffold(body: SavedLibraryScreen()),
        locale: locale,
        repaintKey: libKey,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, libKey, 'ui_${code}_4_my_library.png');

      // 5. Streak Popup Redesign Dialog
      final streakKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const Scaffold(
          body: Center(
            child: StreakPopupDialog(streakCount: 5),
          ),
        ),
        locale: locale,
        repaintKey: streakKey,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, streakKey, 'ui_${code}_5_streak_popup.png');

      // 6. Notifications Screen (Honest empty state)
      final notifKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const NotificationsScreen(),
        locale: locale,
        repaintKey: notifKey,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, notifKey, 'ui_${code}_6_notifications_empty.png');
    }
  });
}
