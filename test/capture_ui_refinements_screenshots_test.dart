import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/main.dart';
import 'package:partwk/core/theme/app_theme.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/services/download_service.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/features/explore/search_screen.dart';
import 'package:partwk/features/profile/settings_screen.dart';
import 'package:partwk/features/library/saved_library_screen.dart';
import 'package:partwk/features/audio/audio_player_screen.dart';
import 'package:partwk/features/book/summary_reader_screen.dart';

class ScreenshotAudioService extends AudioService {
  @override
  bool get isPlaying => true;
  @override
  double get speed => 1.0;
  @override
  Duration get position => const Duration(minutes: 3, seconds: 45);
  @override
  Duration get duration => const Duration(minutes: 18, seconds: 30);
  @override
  String? get currentBookId => 'book-focus';
  @override
  String? get currentLangCode => 'en';
  @override
  String? get currentBookTitle => 'The Art of Relentless Focus';
  @override
  String? get currentCoverUrl => '';
  @override
  int get currentChapterIndex => 0;
  @override
  List<Map<String, dynamic>> get chapters => [
    {'title': 'Introduction & Foundations', 'duration': 240},
    {'title': 'Deep Cognitive Flow', 'duration': 480},
    {'title': 'Eliminating Digital Noise', 'duration': 390},
  ];
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
  Future<void> stop() async {}
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
  late ScreenshotAudioService mockAudio;

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
        for (final family in ['Roboto', 'Vazirmatn', 'Plus Jakarta Sans', 'Outfit']) {
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
    final tempDir = await Directory.systemTemp.createTemp('partwk_refinements_test_');
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall call) async {
      return tempDir.path;
    });

    mockAuth = MockAuthService();
    mockDb = ScreenshotDatabaseService();
    mockAudio = ScreenshotAudioService();

    SharedPreferences.setMockInitialValues({
      'seen_book_ids': mockDb.books.map((b) => b.id).toList(),
      'last_shown_expiry_date': DateTime.now().toIso8601String(),
      'notifications_enabled': true,
    });

    NetworkGuard.mockConnectionStatus = true;
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
      streakCount: 7,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    mockAuth.setUserForTesting(testUser);

    await DownloadService.init();

    // Cache 2 downloaded editions for quota display
    if (mockDb.books.isNotEmpty) {
      await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[0], 'en', userId: testUser.id);
      await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[0], 'ku', userId: testUser.id);
      await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[0], 'ar', userId: testUser.id);
      if (mockDb.books.length > 1) {
        await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[1], 'en', userId: testUser.id);
        await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[1], 'ku', userId: testUser.id);
        await OfflineAvailabilityRepository.cacheEditionMetadata(mockDb.books[1], 'ar', userId: testUser.id);
      }
    }
  });

  tearDown(() {
    NetworkGuard.mockConnectionStatus = null;
  });

  Future<void> saveScreenshot(WidgetTester tester, GlobalKey repaintKey, String filename) async {
    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        print('FAILED TO FIND BOUNDARY FOR $filename');
        return;
      }
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
    bool isDark = false,
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
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: (locale.languageCode == 'ku' || locale.languageCode == 'ar') ? 'Vazirmatn' : 'Roboto',
          scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF97316),
            brightness: isDark ? Brightness.dark : Brightness.light,
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

  testWidgets('Capture 15 UI Refinements Screenshots across EN, KU, AR', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(800, 1600); // 400 x 800 logical phone viewport
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

      // ==========================================
      // 1. My Library Screen with Downloaded Books tab selected
      // ==========================================
      final libKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const Scaffold(body: SavedLibraryScreen(initialIndex: 4)),
        locale: locale,
        repaintKey: libKey,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, libKey, 'ui_refinement_${code}_1_library_downloaded_tab.png');

      // ==========================================
      // 2. Search Page without hashtags (Categories, Trending, New Releases, Popular This Week)
      // ==========================================
      final searchKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const SearchScreen(),
        locale: locale,
        repaintKey: searchKey,
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, searchKey, 'ui_refinement_${code}_2_search_page.png');

      // ==========================================
      // 3. Settings Screen with Notifications switch
      // ==========================================
      final settingsKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: const SettingsScreen(),
        locale: locale,
        repaintKey: settingsKey,
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      await saveScreenshot(tester, settingsKey, 'ui_refinement_${code}_3_settings_notifications.png');

      // ==========================================
      // 4. Redesigned Audio Player Toolbar
      // ==========================================
      final audioKey = GlobalKey();
      final sampleBook = mockDb.books.first;
      await tester.pumpWidget(wrapWithApp(
        child: AudioPlayerScreen(
          bookId: sampleBook.id,
          langCode: code,
          bookTitle: sampleBook.getTitle(code),
          coverUrl: sampleBook.coverImageUrl,
          globalAudioUrl: '',
          chapters: [
            {'title': 'Introduction & Foundations', 'duration': 240},
            {'title': 'Deep Cognitive Flow', 'duration': 480},
          ],
        ),
        locale: locale,
        repaintKey: audioKey,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, audioKey, 'ui_refinement_${code}_4_audio_player_toolbar.png');

      // ==========================================
      // 5. Redesigned Reader Toolbar
      // ==========================================
      final readerKey = GlobalKey();
      await tester.pumpWidget(wrapWithApp(
        child: SummaryReaderScreen(
          bookId: sampleBook.id,
          languageCode: code,
          initialChapterIndex: 0,
        ),
        locale: locale,
        repaintKey: readerKey,
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await saveScreenshot(tester, readerKey, 'ui_refinement_${code}_5_reader_toolbar.png');
    }
  });
}
