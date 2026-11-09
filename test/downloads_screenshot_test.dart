import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/services/download_service.dart';
import 'package:partwk/features/library/downloads_screen.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/main.dart' as app;

class MockScreenshotAuthService extends AuthService {
  UserModel? _currentUser;
  @override
  UserModel? get currentUser => _currentUser;
  @override
  bool get isAuthenticated => _currentUser != null;
  @override
  bool get isGuest => false;

  String mockProvider = 'password';
  @override
  String get signInProvider => mockProvider;

  @override
  Future<void> deleteAccount({String? password}) async {
    _currentUser = null;
    notifyListeners();
  }

  void setUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {}
  @override
  Future<void> registerWithEmailAndPassword(String name, String email, String password) async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> signInAsGuest() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> updateSelectedLanguage(String langCode) async {}
  @override
  Future<void> updateProfilePicture(String url) async {}
  @override
  Future<void> updateInterests(List<String> interests) async {}
  @override
  Future<void> updateGoals(List<String> goals) async {}
  @override
  Future<void> addSavedBook(String bookId) async {}
  @override
  Future<void> removeSavedBook(String bookId) async {}
  @override
  Future<void> addLikedBook(String bookId) async {}
  @override
  Future<void> removeLikedBook(String bookId) async {}
  @override
  Future<void> addCompletedBook(String bookId, {String source = 'automatic', DateTime? completedAt}) async {}
  @override
  Future<void> removeCompletedBook(String bookId) async {}
  @override
  Future<void> updateReadingProgress(String bookId, double progress) async {}
  @override
  Future<void> updateListeningProgress(String bookId, String languageCode, int chapterIndex, int positionSeconds, {int accumulatedSecondHalfSeconds = 0, bool localOnly = false, String? expectedUserId}) async {}
  @override
  Future<void> updatePresence({required String screen, String? bookTitle, String? bookId, String? activityType}) async {}
  @override
  Future<void> checkAndUnlockAchievements() async {}
  @override
  Future<void> addLearningTime(int seconds) async {}
  @override
  Future<void> linkFamilyMember(String email) async {}
  @override
  Future<void> recordActivity() async {}
  @override
  Future<void> setOnlineStatus(bool isOnline) async {}
  @override
  Future<void> upgradeToPremium() async {}
}

class MockScreenshotDownloadService implements DownloadService {
  @override
  Future<List<DownloadedEdition>> getDownloadedEditions({bool validateExpiry = true}) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return [];
    return OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
  }

  @override
  Future<List<Book>> getDownloadedBooks({bool validateExpiry = true}) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return [];
    return OfflineAvailabilityRepository.getCachedBooksMetadata(userId: user.id);
  }

  @override
  Future<bool> downloadBook(Book book, String languageCode, Function(double) onProgress) async => true;

  @override
  Future<bool> isBookDownloaded(String bookId, {String? languageCode}) async => false;

  @override
  Future<bool> isEditionDownloaded(String bookId, String languageCode) async => false;

  @override
  Future<String?> getLocalCoverUri(String bookId, [String? languageCode]) async => null;

  @override
  Future<String?> getLocalAudioUri(String bookId, String languageCode) async => null;

  @override
  Future<void> removeDownload(String bookId, {String? languageCode}) async {}
}

// 1x1 transparent PNG bytes
final Uint8List kTransparentPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MockScreenshotAuthService mockAuth;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('partwk_screen_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    SharedPreferences.setMockInitialValues({});
    mockAuth = MockScreenshotAuthService();
    AppLocator.auth = mockAuth;
    DownloadService.mock = MockScreenshotDownloadService();
    await DownloadService.init();
  });

  tearDown(() async {
    DownloadService.mock = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('Generate Downloads Screen Screenshots for 3/3 and 2/3 Slots', (WidgetTester tester) async {
    final user = UserModel(
      id: 'screenshot_user',
      name: 'Premium Member',
      email: 'premium@partwk.com',
      selectedLanguage: 'en',
      interests: [],
      learningGoals: [],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'premium',
      subscriptionExpiryDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      streakCount: 5,
      lastActiveDate: '2026-11-06',
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    mockAuth.setUser(user);

    // Create local cover image files so no network requests are attempted
    for (final b in [
      {'id': 'atomic_habits', 'lang': 'en'},
      {'id': 'atomic_habits', 'lang': 'ku'},
      {'id': 'sapiens', 'lang': 'ar'},
    ]) {
      final coverDir = Directory('${tempDir.path}/users/${user.id}/books/${b['id']}/${b['lang']}');
      coverDir.createSync(recursive: true);
      File('${coverDir.path}/cover.jpg').writeAsBytesSync(kTransparentPng);
      File('${coverDir.path}/download.complete').createSync();
    }

    final atomicHabits = Book(
      id: 'atomic_habits',
      title: {'en': 'Atomic Habits', 'ku': 'خووە بنەڕەتییەکان', 'ar': 'العادات الذرية'},
      author: {'en': 'James Clear', 'ku': 'جەیمس کلیر', 'ar': 'جيمس كلير'},
      coverImageUrl: '',
      categoryIds: ['cat-productivity'],
      tags: [],
      description: {'en': 'An Easy & Proven Way to Build Good Habits & Break Bad Ones'},
      fiveMinuteSummary: {},
      fifteenMinuteSummary: {},
      chapterSummaries: {},
      keyIdeas: {},
      keyQuotes: {},
      actionPoints: {},
      audioUrl: {},
      duration: 900,
      isPremium: true,
      isPublished: true,
      hiddenLanguages: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final sapiens = Book(
      id: 'sapiens',
      title: {'en': 'Sapiens', 'ar': 'العاقل: تاريخ مختصر للنوع البشري', 'ku': 'مرۆڤی ژیر'},
      author: {'en': 'Yuval Noah Harari', 'ar': 'يوفال نوح هراري', 'ku': 'یوڤاڵ نۆح هەراری'},
      coverImageUrl: '',
      categoryIds: ['cat-history-big-ideas'],
      tags: [],
      description: {'ar': 'ملخص كتاب العاقل'},
      fiveMinuteSummary: {},
      fifteenMinuteSummary: {},
      chapterSummaries: {},
      keyIdeas: {},
      keyQuotes: {},
      actionPoints: {},
      audioUrl: {},
      duration: 1020,
      isPremium: true,
      isPublished: true,
      hiddenLanguages: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. Cache 3 Editions: Atomic Habits (EN), Atomic Habits (KU), Sapiens (AR)
    await OfflineAvailabilityRepository.cacheEditionMetadata(atomicHabits, 'en', userId: user.id);
    await OfflineAvailabilityRepository.cacheEditionMetadata(atomicHabits, 'ku', userId: user.id);
    await OfflineAvailabilityRepository.cacheEditionMetadata(sapiens, 'ar', userId: user.id);

    final boundaryKey3 = GlobalKey();

    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(800, 1600); // 400 x 800 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget buildApp(Key repaintKey) {
      return ChangeNotifierProvider(
        create: (_) => AppLanguageState(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E293B),
              elevation: 0,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E293B),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ku'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            app.FallbackMaterialLocalizationDelegate(),
            app.FallbackCupertinoLocalizationDelegate(),
            app.FallbackWidgetsLocalizationDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RepaintBoundary(
            key: repaintKey,
            child: const DownloadsScreen(),
          ),
        ),
      );
    }

    // PUMP SCREEN 1: 3 / 3 slots
    await tester.pumpWidget(buildApp(boundaryKey3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('3 / 3'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('کوردی (Sorani)'), findsOneWidget);
    expect(find.text('العربية (Arabic)'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary = boundaryKey3.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      const outPath3 = '/Users/peshrawkaramani/.gemini/antigravity-ide/brain/b515dc6d-e05e-4d23-9220-75020f850eaf/downloads_screen_3_of_3.png';
      File(outPath3).writeAsBytesSync(pngBytes);
      print('Saved 3/3 screenshot to: $outPath3 (${pngBytes.length} bytes)');
    });

    // 2. Remove Kurdish Edition -> now 2 / 3 slots
    await OfflineAvailabilityRepository.removeEditionMetadata('atomic_habits', 'ku', userId: user.id);

    final boundaryKey2 = GlobalKey();
    await tester.pumpWidget(buildApp(boundaryKey2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('2 / 3'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('کوردی (Sorani)'), findsNothing);
    expect(find.text('العربية (Arabic)'), findsOneWidget);

    await tester.runAsync(() async {
      final boundary = boundaryKey2.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      const outPath2 = '/Users/peshrawkaramani/.gemini/antigravity-ide/brain/b515dc6d-e05e-4d23-9220-75020f850eaf/downloads_screen_2_of_3.png';
      File(outPath2).writeAsBytesSync(pngBytes);
      print('Saved 2/3 screenshot to: $outPath2 (${pngBytes.length} bytes)');
    });
  });
}
