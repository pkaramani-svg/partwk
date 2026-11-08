import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:partwk/main.dart';
import 'package:partwk/core/theme/app_theme.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/features/home/main_navigation.dart';
import 'package:partwk/features/home/home_screen.dart';
import 'package:partwk/features/explore/search_screen.dart';
import 'package:partwk/features/profile/settings_screen.dart';
import 'package:partwk/features/auth/language_selection_screen.dart';
import 'package:partwk/features/library/saved_library_screen.dart';
import 'package:partwk/features/audio/audio_player_screen.dart';
import 'package:partwk/features/book/summary_reader_screen.dart';
import 'package:partwk/core/widgets/streak_popup_dialog.dart';
import 'package:partwk/core/widgets/partwk_audio_visualizer.dart';

class FakeTestAudioService extends AudioService {
  bool _isPlaying = false;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(minutes: 15);
  String? _currentBookId;
  String? _currentLangCode;
  String? _currentBookTitle;
  String? _currentCoverUrl;
  int _currentChapterIndex = 0;
  List<Map<String, dynamic>> _chapters = [];
  Duration? _sleepTimerRemaining;

  @override
  bool get isPlaying => _isPlaying;
  @override
  double get speed => _speed;
  @override
  Duration get position => _position;
  @override
  Duration get duration => _duration;
  @override
  String? get currentBookId => _currentBookId;
  @override
  String? get currentLangCode => _currentLangCode;
  @override
  String? get currentBookTitle => _currentBookTitle;
  @override
  String? get currentCoverUrl => _currentCoverUrl;
  @override
  int get currentChapterIndex => _currentChapterIndex;
  @override
  List<Map<String, dynamic>> get chapters => _chapters;
  @override
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
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
  void play(String bookId, String langCode, String bookTitle, String coverUrl,
      String globalAudioUrl, List<Map<String, dynamic>> bookChapters,
      {int startIndex = 0, int startPosition = 0, int bookDurationSecs = 0, bool isPremium = false}) {
    _currentBookId = bookId;
    _currentLangCode = langCode;
    _currentBookTitle = bookTitle;
    _currentCoverUrl = coverUrl;
    _chapters = bookChapters;
    _currentChapterIndex = startIndex;
    _isPlaying = true;
    notifyListeners();
  }
  @override
  void pause() {
    _isPlaying = false;
    notifyListeners();
  }
  @override
  void resume() {
    _isPlaying = true;
    notifyListeners();
  }
  @override
  void stop() {
    _isPlaying = false;
    notifyListeners();
  }
  @override
  void setSpeed(double speed) {
    _speed = speed;
    notifyListeners();
  }
  @override
  void seek(Duration position) {
    _position = position;
    notifyListeners();
  }
  @override
  void nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _currentChapterIndex++;
      notifyListeners();
    }
  }
  @override
  void previousChapter() {
    if (_currentChapterIndex > 0) {
      _currentChapterIndex--;
      notifyListeners();
    }
  }
  @override
  void setSleepTimer(Duration duration) {
    _sleepTimerRemaining = duration;
    notifyListeners();
  }
  @override
  void clearSleepTimer() {
    _sleepTimerRemaining = null;
    notifyListeners();
  }
}

class ImmediateDatabaseService extends MockDatabaseService {
  @override
  Future<List<Book>> fetchBooks() async => books;
  @override
  Future<List<Category>> fetchCategories() async => categories;
  @override
  Future<List<Book>> fetchTrendingBooks(List<Book> allBooks) async => allBooks;
}

Widget buildTestApp({
  required Widget child,
  Locale locale = const Locale('en'),
  AppLanguageState? langState,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageState>(
        create: (_) => langState ?? AppLanguageState(),
      ),
      ChangeNotifierProvider<AppThemeProvider>(
        create: (_) => AppThemeProvider(),
      ),
      ChangeNotifierProvider<AudioService>.value(
        value: AppLocator.audio,
      ),
    ],
    child: MaterialApp(
      key: ValueKey('test_app_${locale.languageCode}'),
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ku'),
        Locale('ar'),
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
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthService mockAuth;
  late ImmediateDatabaseService mockDb;
  late FakeTestAudioService mockAudio;

  setUp(() async {
    mockAuth = MockAuthService();
    mockDb = ImmediateDatabaseService();
    mockAudio = FakeTestAudioService();

    SharedPreferences.setMockInitialValues({
      'seen_book_ids': mockDb.books.map((b) => b.id).toList(),
      'last_shown_expiry_date': DateTime.now().toIso8601String(),
    });

    AppLocator.auth = mockAuth;
    AppLocator.db = mockDb;
    AppLocator.audio = mockAudio;

    NetworkGuard.mockConnectionStatus = true;
    final testUser = UserModel(
      id: 'test_user_42',
      name: 'Test Reader',
      email: 'reader@test.com',
      selectedLanguage: 'en',
      interests: ['productivity'],
      learningGoals: ['15_mins'],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'premium',
      streakCount: 3,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    mockAuth.setUserForTesting(testUser);
  });

  tearDown(() {
    NetworkGuard.mockConnectionStatus = null;
  });

  group('UI Improvements Verification Tests', () {
    testWidgets('1. Bottom Navigation: Search tab label and icon in EN, KU, AR', (tester) async {
      // English
      await tester.pumpWidget(buildTestApp(
        child: const MainNavigation(),
        locale: const Locale('en'),
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(Icons.search_outlined), findsOneWidget);

      // Kurdish Sorani
      await tester.pumpWidget(buildTestApp(
        child: const MainNavigation(),
        locale: const Locale('ku'),
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('گەڕان'), findsOneWidget);

      // Arabic
      await tester.pumpWidget(buildTestApp(
        child: const MainNavigation(),
        locale: const Locale('ar'),
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('بحث'), findsOneWidget);

      // Tap on Search tab switches to SearchScreen
      await tester.tap(find.text('بحث'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('2. Search Page: Hashtags removed, dynamic New Releases and Popular This Week present', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const SearchScreen(),
        locale: const Locale('en'),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Popular Searches hashtags should be completely absent
      expect(find.text('Popular Searches'), findsNothing);
      expect(find.text('#Productivity'), findsNothing);
      expect(find.text('#Focus'), findsNothing);

      // Search bar, Categories, and Trending Books exist
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Trending'), findsOneWidget);

      // New Releases and Popular This Week dynamic sections exist
      expect(find.text('New Releases'), findsOneWidget);
      expect(find.text('Popular This Week'), findsOneWidget);
    });

    testWidgets('3. Notifications: Bell removed from Home header, Notifications switch in Settings', (tester) async {
      SharedPreferences.setMockInitialValues({'notifications_enabled': true});

      // 1. Home Header: No notification bell
      await tester.pumpWidget(buildTestApp(
        child: const HomeScreen(),
        locale: const Locale('en'),
      ));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsNothing);
      expect(find.byIcon(Icons.notifications), findsNothing);

      // Settings gear remains
      final settingsFinder = find.byIcon(Icons.settings_outlined);
      expect(settingsFinder, findsOneWidget);

      // 2. Open SettingsScreen
      await tester.tap(settingsFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Notifications switch tile
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Receive updates on new books and reading reminders'), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsAtLeastNWidgets(1));

      // Toggle switch
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
    });

    testWidgets('4. Language Selection Screen: Localized header, description, and RTL support', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const LanguageSelectionScreen(isFromSettings: true),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // English Header
      expect(find.text('Select Your Language'), findsOneWidget);
      expect(find.text('Save & Return'), findsOneWidget);

      // Switch to Kurdish
      await tester.tap(find.text('کوردی (سۆرانی)'));
      await tester.pumpAndSettle();

      expect(find.text('زمانەکەت هەڵبژێرە'), findsOneWidget);
      expect(find.text('پاشەکەوتکردن و گەڕانەوە'), findsOneWidget);

      // Verify Directionality is RTL for Kurdish inside LanguageSelectionScreen
      final kurdishDirectionalityFinder = find.descendant(
        of: find.byType(LanguageSelectionScreen),
        matching: find.byType(Directionality),
      ).first;
      final Directionality directionality = tester.widget(kurdishDirectionalityFinder);
      expect(directionality.textDirection, TextDirection.rtl);

      // Switch to Arabic
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(find.text('اختر لغتك المفضلة'), findsOneWidget);
      expect(find.text('حفظ والرجوع'), findsOneWidget);
      final arabicDirectionalityFinder = find.descendant(
        of: find.byType(LanguageSelectionScreen),
        matching: find.byType(Directionality),
      ).first;
      final Directionality arDirectionality = tester.widget(arabicDirectionalityFinder);
      expect(arDirectionality.textDirection, TextDirection.rtl);
    });

    testWidgets('5. My Library: Downloaded Books tab in tab row without top standalone card', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        child: const SavedLibraryScreen(),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // 5 tabs exist in TabBar row: Continue Reading, Liked, Saved Summaries, Notes, Downloaded Books
      expect(find.text('Continue Reading'), findsOneWidget);
      expect(find.text('Liked'), findsOneWidget);
      expect(find.text('Saved Summaries'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Downloaded Books'), findsOneWidget);

      // Top standalone card should NOT exist
      expect(find.text('Offline Books • Tap to manage'), findsNothing);

      // Select Downloaded Books tab
      await tester.tap(find.text('Downloaded Books'));
      await tester.pumpAndSettle();

      // Content area displays offline storage badge and quota
      expect(find.textContaining('downloads used'), findsOneWidget);
      expect(find.byIcon(Icons.offline_pin), findsOneWidget);
    });

    testWidgets('6. Streak Popup Dialog: Redesigned with current streak, longest streak, today status & milestone', (tester) async {
      await tester.pumpWidget(buildTestApp(
        child: const StreakPopupDialog(streakCount: 3),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Current Streak & Longest Streak
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Longest Streak'), findsOneWidget);
      expect(find.text('3'), findsAtLeastNWidgets(1));

      // Today's Activity status
      expect(find.textContaining("Today's Activity"), findsOneWidget);

      // 7-day progress view
      expect(find.byIcon(Icons.check_rounded), findsWidgets);

      // Next Milestone
      expect(find.textContaining('Next Milestone'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Dismiss button
      expect(find.text('Save and Continue'), findsOneWidget);
      await tester.tap(find.text('Save and Continue'));
      await tester.pumpAndSettle();
    });

    testWidgets('7. Redesigned Audio Player Toolbar: Visible primary controls (Read, Chapters, Timer) and waveform visualizer', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        child: const AudioPlayerScreen(
          bookId: 'test_book_1',
          langCode: 'en',
          bookTitle: 'Atomic Habits: An Easy & Proven Way to Build Good Habits',
          coverUrl: '',
          globalAudioUrl: '',
          chapters: [
            {'title': 'Introduction', 'duration': 300},
            {'title': 'Chapter 1', 'duration': 600},
          ],
        ),
        locale: const Locale('en'),
      ));
      await tester.pumpAndSettle();

      // Flexible book title and waveform visualizer rendered in AppBar
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Atomic Habits: An Easy & Proven Way to Build Good Habits')), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(PartwkAudioVisualizer)), findsOneWidget);
      expect(find.text('Listen to Audio'), findsNothing);

      // The 3 primary controls always visible in the header:
      // 1. Back button
      expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.keyboard_arrow_down_rounded)), findsOneWidget);
      // 2. Read Summary button
      expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.menu_book_rounded)), findsOneWidget);
      // 3. Chapters jump list button
      expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.format_list_bulleted_rounded)), findsOneWidget);
      // 4. Sleep Timer button
      expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.bedtime_outlined)), findsOneWidget);

      // Overflow menu and settings gear removed from header
      expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.more_horiz_rounded)), findsNothing);
      expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.settings_outlined)), findsNothing);

      // Tapping Sleep Timer directly opens the dialog without overflow menu
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.bedtime_outlined)));
      await tester.pumpAndSettle();

      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.text('5 Minutes'), findsOneWidget);
    });

    testWidgets('8. Redesigned Reader Toolbar: Rounded buttons, flexible title, listen, settings and overflow menu', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(
        child: SummaryReaderScreen(
          bookId: mockDb.books.first.id,
          initialChapterIndex: 0,
        ),
        locale: const Locale('en'),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Toolbar elements
      expect(find.descendant(of: find.byType(AppBar), matching: find.byType(Row)), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
      expect(find.byIcon(Icons.text_format_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

      // Open overflow menu
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Take Quiz'), findsOneWidget);
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Add Note'), findsOneWidget);
    });
  });
}
