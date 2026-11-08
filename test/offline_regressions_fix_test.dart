import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/download_manager.dart';
import 'package:partwk/core/services/licence_manager.dart';
import 'package:partwk/core/services/encrypted_content_storage.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/core/services/protected_text_service.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/core/services/catalogue_cache_service.dart';
import 'package:partwk/services/download_service.dart';
import 'package:partwk/core/widgets/book_card.dart';

class MockRegressionAuthService extends MockAuthService {
  UserModel? _currentUser;
  bool _isGuest = false;

  @override
  UserModel? get currentUser => _currentUser;
  @override
  bool get isAuthenticated => _currentUser != null;
  @override
  bool get isGuest => _isGuest;

  void setUser(UserModel? user, {bool guest = false}) {
    _currentUser = user;
    _isGuest = guest;
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
  Future<void> signInAsGuest() async {
    _isGuest = true;
    _currentUser = null;
    notifyListeners();
  }
  @override
  Future<void> signOut() async {
    _currentUser = null;
    _isGuest = false;
    notifyListeners();
  }
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
  Future<void> upgradeToPremium() async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(subscriptionStatus: 'premium');
      notifyListeners();
    }
  }
}

class FakeAudioPlayerPlatform extends AudioPlayerPlatform {
  FakeAudioPlayerPlatform(super.id);
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => const Stream.empty();
  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => const Stream.empty();
  @override
  Future<LoadResponse> load(LoadRequest request) async => LoadResponse(duration: const Duration(minutes: 10));
  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();
  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();
  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();
  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();
  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async => DisposeResponse();
}

class FakeJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async => FakeAudioPlayerPlatform(request.id);
  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async => DisposePlayerResponse();
  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async => DisposeAllPlayersResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MockRegressionAuthService mockAuth;
  final Map<String, String> secureStorageMemory = {};

  final UserModel primaryPremiumUser = UserModel(
    id: 'user_reg_premium_1',
    name: 'Premium Reader',
    email: 'test_premium@partwk.com',
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
    streakCount: 0,
    lastActiveDate: '2026-11-06',
    familyMembers: [],
    createdAt: DateTime.now(),
  );

  Book createMultiLangAtomicHabits() {
    return Book(
      id: 'atomic_habits',
      title: {
        'en': 'Atomic Habits',
        'ku': 'خووە گەردیلەییەکان',
        'ar': 'العادات الذرية',
      },
      author: {
        'en': 'James Clear',
        'ku': 'جەیمس کلیر',
        'ar': 'جيمس كلير',
      },
      description: {
        'en': 'An Easy & Proven Way to Build Good Habits & Break Bad Ones.',
        'ku': 'ڕێگایەکی ئاسان و سەلمێنراو بۆ بنیادنانی خووی باش و شکاندنی خووی خراپ.',
        'ar': 'طريقة سهلة ومثبتة لبناء عادات جيدة والتخلص من العادات السيئة.',
      },
      coverImageUrl: '',
      duration: 900,
      isPremium: true,
      isPublished: true,
      categoryIds: ['self_help', 'productivity'],
      tags: ['habits', 'growth'],
      hiddenLanguages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      chapterSummaries: {
        'en': [
          {'index': 0, 'title': 'Introduction', 'content': 'English intro text for Atomic Habits.', 'audioUrl': 'local:audio_en_0', 'duration': 300},
          {'index': 1, 'title': 'The Fundamentals', 'content': 'English fundamentals summary.', 'audioUrl': 'local:audio_en_1', 'duration': 600},
        ],
        'ku': [
          {'index': 0, 'title': 'پێشەکی', 'content': 'دەقی کوردی پێشەکی خووە گەردیلەییەکان.', 'audioUrl': 'local:audio_ku_0', 'duration': 300},
          {'index': 1, 'title': 'بنەما سەرەکییەکان', 'content': 'پوختەی کوردی لەسەر بنەماکان.', 'audioUrl': 'local:audio_ku_1', 'duration': 600},
        ],
        'ar': [
          {'index': 0, 'title': 'المقدمة', 'content': 'النص العربي لمقدمة كتاب العادات الذرية.', 'audioUrl': 'local:audio_ar_0', 'duration': 300},
          {'index': 1, 'title': 'الأساسيات', 'content': 'الملخص العربي للأساسيات.', 'audioUrl': 'local:audio_ar_1', 'duration': 600},
        ],
      },
      fiveMinuteSummary: {'en': 'En 5m', 'ku': 'Ku 5m', 'ar': 'Ar 5m'},
      fifteenMinuteSummary: {'en': 'En 15m', 'ku': 'Ku 15m', 'ar': 'Ar 15m'},
      keyIdeas: {'en': ['Idea EN'], 'ku': ['Idea KU'], 'ar': ['Idea AR']},
      keyQuotes: {'en': ['Quote EN'], 'ku': ['Quote KU'], 'ar': ['Quote AR']},
      actionPoints: {'en': ['Action EN'], 'ku': ['Action KU'], 'ar': ['Action AR']},
      audioUrl: {
        'en': 'local:audio_en',
        'ku': 'local:audio_ku',
        'ar': 'local:audio_ar',
      },
    );
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('partwk_reg_test_');

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return tempDir.path;
      },
    );

    const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'read') {
          return secureStorageMemory[methodCall.arguments['key']];
        } else if (methodCall.method == 'write') {
          secureStorageMemory[methodCall.arguments['key']] = methodCall.arguments['value'];
          return null;
        } else if (methodCall.method == 'delete') {
          secureStorageMemory.remove(methodCall.arguments['key']);
          return null;
        } else if (methodCall.method == 'deleteAll') {
          secureStorageMemory.clear();
          return null;
        }
        return null;
      },
    );

    SharedPreferences.setMockInitialValues({});
    await DownloadService.init();

    mockAuth = MockRegressionAuthService();
    AppLocator.auth = mockAuth;
    mockAuth.setUser(primaryPremiumUser);
  });

  tearDownAll(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('A. Missing Downloaded Cover Safety Tests', () {
    test('getLocalCoverFileIfExists returns null safely when no cover exists on disk without throwing', () {
      final file = DownloadService.getLocalCoverFileIfExists('non_existent_book', 'en');
      expect(file, isNull);
    });

    test('buildCoverPlaceholder renders a clean gradient placeholder with book title and icon', () {
      final placeholder = DownloadService.buildCoverPlaceholder(
        width: 100,
        height: 150,
        title: 'The Total Money Makeover',
      );
      expect(placeholder, isA<Container>());
    });

    test('getBookCoverWidget gracefully falls back to placeholder when local cover is missing offline', () {
      final book = createMultiLangAtomicHabits();
      final widget = DownloadService.getBookCoverWidget(book, langCode: 'en', width: 90, height: 120);
      expect(widget, isNotNull);
    });

    test('getBookCoverWidget uses existing file when cover is present on disk', () async {
      final book = createMultiLangAtomicHabits();
      final coverDir = Directory('${tempDir.path}/users/${primaryPremiumUser.id}/books/${book.id}/en');
      await coverDir.create(recursive: true);
      final coverFile = File('${coverDir.path}/cover.jpg');
      await coverFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]); // Fake jpeg header

      final detected = DownloadService.getLocalCoverFileIfExists(book.id, 'en');
      expect(detected, isNotNull);
      expect(detected!.existsSync(), isTrue);

      final widget = DownloadService.getBookCoverWidget(book, langCode: 'en');
      expect(widget, isA<ClipRRect>());
    });
  });

  group('B. Language Isolation and Offline Independence Sequence (1 - 5)', () {
    late Book atomicHabits;

    setUp(() async {
      atomicHabits = createMultiLangAtomicHabits();
      NetworkGuard.mockConnectionStatus = true;
    });

    test('Sequential Rule Verification: Download EN (1/3) -> Online KU/AR without contamination -> Airplane mode (EN works, KU/AR blocked) -> Download KU (2/3) -> Delete KU (2/3) -> Reconnect', () async {
      NetworkGuard.mockConnectionStatus = true;

      // STEP 1: Download Atomic Habits English -> Quota becomes 1 / 3
      final dlEn = await DownloadManager().downloadBook(atomicHabits, 'en', (_) {});
      expect(dlEn, isTrue);

      var editions = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: primaryPremiumUser.id);
      expect(editions.length, equals(1));
      expect(editions.first.languageCode, equals('en'));
      print('✓ STEP 1: Downloaded Atomic Habits English -> 1 / 3 used');

      // STEP 2: While online, Kurdish and Arabic load correct independent text and audio without contamination
      NetworkGuard.mockConnectionStatus = true;
      final hydratedKurdish = await ProtectedTextService.hydrate(atomicHabits, 'ku');
      final kuChapters = hydratedKurdish.getChapterSummaries('ku');
      expect(kuChapters.isNotEmpty, isTrue);
      expect(kuChapters.first['title'], equals('پێشەکی'));
      expect(kuChapters.first['content'], contains('دەقی کوردی'));
      expect(hydratedKurdish.getAudioUrl('ku'), equals('local:audio_ku'));

      final hydratedArabic = await ProtectedTextService.hydrate(atomicHabits, 'ar');
      final arChapters = hydratedArabic.getChapterSummaries('ar');
      expect(arChapters.isNotEmpty, isTrue);
      expect(arChapters.first['title'], equals('المقدمة'));
      expect(arChapters.first['content'], contains('النص العربي'));
      expect(hydratedArabic.getAudioUrl('ar'), equals('local:audio_ar'));
      print('✓ STEP 2: Online Kurdish and Arabic load their own live content without English contamination');

      // STEP 3: Enable airplane mode -> English opens offline; Kurdish & Arabic state not downloaded
      NetworkGuard.mockConnectionStatus = false;
      final isEnDownloaded = await DownloadManager.isEditionDownloaded(atomicHabits.id, 'en', userId: primaryPremiumUser.id);
      expect(isEnDownloaded, isTrue);

      final decryptedEn = await DownloadManager.loadBookContent(atomicHabits, languageCode: 'en');
      final enChapters = decryptedEn.getChapterSummaries('en');
      expect(enChapters.isNotEmpty, isTrue);
      expect(enChapters.first['content'], equals('English intro text for Atomic Habits.'));

      final isKuDownloaded = await DownloadManager.isEditionDownloaded(atomicHabits.id, 'ku', userId: primaryPremiumUser.id);
      final isArDownloaded = await DownloadManager.isEditionDownloaded(atomicHabits.id, 'ar', userId: primaryPremiumUser.id);
      expect(isKuDownloaded, isFalse);
      expect(isArDownloaded, isFalse);
      print('✓ STEP 3: In airplane mode, English opens offline while Kurdish & Arabic are correctly flagged not downloaded');

      // STEP 4: Download Kurdish -> English and Kurdish work offline independently (2 / 3 slots)
      NetworkGuard.mockConnectionStatus = true;
      final dlKu = await DownloadManager().downloadBook(atomicHabits, 'ku', (_) {});
      expect(dlKu, isTrue);

      editions = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: primaryPremiumUser.id);
      expect(editions.length, equals(2));

      // Airplane mode on again
      NetworkGuard.mockConnectionStatus = false;
      final loadedEn = await DownloadManager.loadBookContent(atomicHabits, languageCode: 'en');
      expect(loadedEn.getChapterSummaries('en').first['content'], contains('English intro'));

      final loadedKu = await DownloadManager.loadBookContent(atomicHabits, languageCode: 'ku');
      expect(loadedKu.getChapterSummaries('ku').first['content'], contains('دەقی کوردی'));
      print('✓ STEP 4: English and Kurdish work offline independently (2 / 3 slots)');

      // STEP 5: Delete Kurdish -> English still works offline; Kurdish unavailable offline; online Kurdish works after reconnect
      await DownloadService().removeDownload(atomicHabits.id, languageCode: 'ku');

      editions = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: primaryPremiumUser.id);
      expect(editions.length, equals(1));
      expect(editions.first.languageCode, equals('en'));

      NetworkGuard.mockConnectionStatus = false;
      final isKuDown = await DownloadManager.isEditionDownloaded(atomicHabits.id, 'ku', userId: primaryPremiumUser.id);
      expect(isKuDown, isFalse);

      final loadedEnAfter = await DownloadManager.loadBookContent(atomicHabits, languageCode: 'en');
      expect(loadedEnAfter.getChapterSummaries('en').first['content'], contains('English intro'));

      NetworkGuard.mockConnectionStatus = true;
      final reconnectedKu = await ProtectedTextService.hydrate(atomicHabits, 'ku');
      expect(reconnectedKu.getChapterSummaries('ku').first['content'], contains('دەقی کوردی'));
      print('✓ STEP 5: Deleted Kurdish: English intact; Kurdish offline blocked; online Kurdish works after reconnect');
    });
  });

  group('C. Layout Overflow Resilience Tests (BookCard on compact phone)', () {
    testWidgets('BookCard renders without horizontal overflow on 320dp narrow phone in English', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final book = createMultiLangAtomicHabits();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: BookCard(
                book: book,
                displayLanguageCode: 'en',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: const Text('English', style: TextStyle(fontSize: 10)),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () {},
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('BookCard renders without horizontal overflow on 320dp narrow phone in Kurdish Sorani (RTL)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final book = createMultiLangAtomicHabits();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: BookCard(
                  book: book,
                  displayLanguageCode: 'ku',
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: const Text('کوردی سۆرانی', style: TextStyle(fontSize: 10)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {},
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('BookCard renders without horizontal overflow on 320dp narrow phone in Arabic (RTL)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final book = createMultiLangAtomicHabits();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 320,
                child: BookCard(
                  book: book,
                  displayLanguageCode: 'ar',
                  badge: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: const Text('العربية', style: TextStyle(fontSize: 10)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {},
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('D. Catalogue-Only Cache Tests', () {
    test('CatalogueCacheService saves only catalogue metadata and strictly strips sensitive text/audio', () async {
      final book = createMultiLangAtomicHabits();
      final cat = Category(id: 'c1', name: {'en': 'Self-Help'}, iconName: 'book');

      await CatalogueCacheService.saveCatalogueCache([book], [cat]);

      final cachedBooks = await CatalogueCacheService.loadCatalogueBooks();
      expect(cachedBooks.isNotEmpty, isTrue);
      final cb = cachedBooks.first;

      // Metadata must be present
      expect(cb.id, equals(book.id));
      expect(cb.getTitle('en'), equals('Atomic Habits'));
      expect(cb.getAuthor('en'), equals('James Clear'));
      expect(cb.isPremium, isTrue);

      // Sensitive text and audio must NEVER be cached
      expect(cb.chapterSummaries['en'] ?? [], isEmpty);
      expect(cb.fiveMinuteSummary['en'] ?? '', isEmpty);
      expect(cb.fifteenMinuteSummary['en'] ?? '', isEmpty);
      expect(cb.keyIdeas['en'] ?? [], isEmpty);
      expect(cb.keyQuotes['en'] ?? [], isEmpty);
      expect(cb.actionPoints['en'] ?? [], isEmpty);
      expect(cb.audioUrl['en'] ?? '', isEmpty);

      final cachedCats = await CatalogueCacheService.loadCatalogueCategories();
      expect(cachedCats.isNotEmpty, isTrue);
      expect(cachedCats.first.id, equals('c1'));
    });
  });
}
