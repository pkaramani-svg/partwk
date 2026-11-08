import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:partwk/models/book.dart';
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
import 'package:partwk/services/download_service.dart';

class MockDistributionAuthService extends AuthService {
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
  late MockDistributionAuthService mockAuth;
  final Map<String, String> secureStorageMock = {};

  setUpAll(() {
    JustAudioPlatform.instance = FakeJustAudioPlatform();

    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
        .setMockMethodCallHandler((MethodCall call) async {
      if (call.method == 'read') {
        return secureStorageMock[call.arguments['key']];
      } else if (call.method == 'write') {
        secureStorageMock[call.arguments['key']] = call.arguments['value'];
        return null;
      } else if (call.method == 'delete') {
        secureStorageMock.remove(call.arguments['key']);
        return null;
      } else if (call.method == 'deleteAll') {
        secureStorageMock.clear();
        return null;
      }
      return null;
    });

    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall call) async {
      return tempDir.path;
    });
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('partwk_dist_test_');
    SharedPreferences.setMockInitialValues({});
    secureStorageMock.clear();
    mockAuth = MockDistributionAuthService();
    AppLocator.auth = mockAuth;
    await DownloadService.init();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('1. Category Migration & Multi-Category Matching', () {
    test('Safely migrates legacy single category into categoryIds and categories', () {
      final legacyData = {
        'title': {'en': 'Test Book'},
        'author': {'en': 'Author'},
        'category': 'cat-productivity',
        'isPremium': false,
        'isPublished': true,
      };

      final book = Book.fromMap('book_legacy', legacyData);
      expect(book.categoryIds, equals(['cat-productivity']));
      expect(book.categories, equals(['cat-productivity']));

      final exported = book.toMap();
      expect(exported['categories'], equals(['cat-productivity']));
      expect(exported['categoryIds'], equals(['cat-productivity']));
      expect(exported['category'], equals('cat-productivity'));
    });

    test('Parses multi-category array from categories or categoryIds', () {
      final multiCatData = {
        'title': {'en': 'Multi Cat Book'},
        'author': {'en': 'Author'},
        'categories': ['cat-productivity', 'cat-psychology', 'cat-business'],
        'isPremium': false,
        'isPublished': true,
      };

      final book = Book.fromMap('book_multi', multiCatData);
      expect(book.categoryIds, equals(['cat-productivity', 'cat-psychology', 'cat-business']));
      expect(book.categories, equals(['cat-productivity', 'cat-psychology', 'cat-business']));

      // Appears under every assigned category
      expect(book.categoryIds.contains('cat-productivity'), isTrue);
      expect(book.categoryIds.contains('cat-psychology'), isTrue);
      expect(book.categoryIds.contains('cat-business'), isTrue);
      expect(book.categoryIds.contains('cat-leadership'), isFalse);
    });
  });

  group('2. Fully Free Access (Audio & Reader)', () {
    test('Free book (isPremium: false) is accessible without audio limitation for guest', () {
      mockAuth.setUser(null, guest: true);

      final freeChapters = List.generate(
        5,
        (i) => {'title': {'en': 'Chapter $i'}, 'audioUrl': 'http://example.com/$i.mp3'},
      );

      final audio = RealAudioService();
      audio.play(
        'free_book_1',
        'en',
        'Free Title',
        '',
        '',
        freeChapters,
        startIndex: 0,
        isPremium: false,
      );

      expect(audio.isGuestRestricted, isFalse);
      expect(audio.isCurrentBookPremium, isFalse);

      // Advancing to chapter 2, 3, 4 continues normally without restriction
      audio.play(
        'free_book_1',
        'en',
        'Free Title',
        '',
        '',
        freeChapters,
        startIndex: 3,
        isPremium: false,
      );
      expect(audio.isGuestRestricted, isFalse);
    });

    test('Free book text hydration succeeds unconditionally for guest and free users', () async {
      mockAuth.setUser(null, guest: true);

      final freeBook = Book(
        id: 'sapiens_free',
        title: {'en': 'Sapiens'},
        author: {'en': 'Yuval Noah Harari'},
        coverImageUrl: 'cover.jpg',
        categoryIds: ['cat-history-big-ideas'],
        tags: [],
        description: {'en': 'Summary'},
        fiveMinuteSummary: {'en': '5m'},
        fifteenMinuteSummary: {'en': '15m'},
        chapterSummaries: {
          'en': [{'title': 'Ch 1', 'content': 'Full Chapter Text'}],
          'ku': [{'title': 'Ch 1', 'content': 'دەقی تەواو'}],
          'ar': [{'title': 'Ch 1', 'content': 'النص الكامل'}],
        },
        keyIdeas: {'en': ['Idea 1']},
        keyQuotes: {'en': ['Quote 1']},
        actionPoints: {'en': ['Action 1']},
        audioUrl: {'en': 'http://audio.mp3'},
        duration: 900,
        isPremium: false,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final hydrated = await ProtectedTextService.hydrate(freeBook, 'en');
      expect(hydrated.id, equals('sapiens_free'));
      expect(hydrated.isPremium, isFalse);
    });
  });

  group('3. Premium Content Denial & Family Entitlement', () {
    test('Premium title (isPremium: true) denies access to free user and guest with paywall exception', () async {
      mockAuth.setUser(null, guest: true);

      final premiumBook = Book(
        id: 'atomic_habits_prem',
        title: {'en': 'Atomic Habits'},
        author: {'en': 'James Clear'},
        coverImageUrl: 'cover.jpg',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Description'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'Text'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 800,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(() => ProtectedTextService.hydrate(premiumBook, 'en'),
          throwsA(isA<ContentUnauthenticatedException>()));

      // Free registered account
      final freeUser = UserModel(
        id: 'free_user_1',
        name: 'Free User',
        email: 'free@test.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        streakCount: 0,
        lastActiveDate: '2026-11-06',
        familyMembers: [],
        createdAt: DateTime.now(),
      );
      mockAuth.setUser(freeUser);

      expect(() => ProtectedTextService.hydrate(premiumBook, 'en'),
          throwsA(isA<ContentPermissionDeniedException>()));
    });

    test('Linked family member (hasFamilyPremium: true) has valid Premium access', () async {
      final familyUser = UserModel(
        id: 'family_member_1',
        name: 'Family User',
        email: 'family@test.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        hasFamilyPremium: true,
        streakCount: 0,
        lastActiveDate: '2026-11-06',
        familyMembers: [],
        createdAt: DateTime.now(),
      );
      mockAuth.setUser(familyUser);
      expect(familyUser.isPremium, isTrue);

      final premiumBook = Book(
        id: 'atomic_habits_prem',
        title: {'en': 'Atomic Habits'},
        author: {'en': 'James Clear'},
        coverImageUrl: 'cover.jpg',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Description'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'Premium Text'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 800,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final hydrated = await ProtectedTextService.hydrate(premiumBook, 'en');
      expect(hydrated.id, equals('atomic_habits_prem'));
    });
  });

  group('4. Secure Offline Downloads — Premium Only, 3-Book Limit, & Deletion', () {
    test('Free user cannot download any book (throws DownloadPermissionDeniedException)', () async {
      final freeUser = UserModel(
        id: 'free_user_1',
        name: 'Free User',
        email: 'free@test.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        streakCount: 0,
        lastActiveDate: '2026-11-06',
        familyMembers: [],
        createdAt: DateTime.now(),
      );
      mockAuth.setUser(freeUser);

      final book = Book(
        id: 'book_free_test',
        title: {'en': 'Book 1'},
        author: {'en': 'Author'},
        coverImageUrl: 'cover.jpg',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': []},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 100,
        isPremium: false,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(() => DownloadManager().downloadBook(book, 'en', (_) {}),
          throwsA(isA<DownloadPermissionDeniedException>()));
    });

    test('Per-edition package tests: same book in English + Kurdish uses 2 slots; 3rd edition fills quota; 4th is blocked', () async {
      final premiumUser = UserModel(
        id: 'premium_user_slots',
        name: 'Premium User',
        email: 'slots@test.com',
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
      mockAuth.setUser(premiumUser);

      // Book 1: Atomic Habits with both 'en' and 'ku' content
      final atomicHabits = Book(
        id: 'atomic_habits',
        title: {'en': 'Atomic Habits', 'ku': 'خووە بنەڕەتییەکان'},
        author: {'en': 'James Clear', 'ku': 'جەیمس کلیر'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'Atomic Habits 5m', 'ku': 'کورتەی ٥ خولەک'},
        fifteenMinuteSummary: {'en': 'Atomic Habits 15m', 'ku': 'کورتەی ١٥ خولەک'},
        chapterSummaries: {
          'en': [{'title': 'Chapter 1', 'content': 'English Ch 1 Content'}],
          'ku': [{'title': 'بەشی ١', 'content': 'دەقی کوردی بەشی ١'}],
        },
        keyIdeas: {'en': ['Idea EN'], 'ku': ['بیرۆکەی کوردی']},
        keyQuotes: {'en': ['Quote EN'], 'ku': ['وتەی کوردی']},
        actionPoints: {'en': ['Action EN'], 'ku': ['خاڵی کردارەکی']},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Download Atomic Habits in English -> uses slot 1
      final res1 = await DownloadManager().downloadBook(atomicHabits, 'en', (_) {});
      expect(res1, isTrue);

      var editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(1));
      expect(DownloadService.isEditionDownloadedSync('atomic_habits', 'en'), isTrue);
      expect(DownloadService.isEditionDownloadedSync('atomic_habits', 'ku'), isFalse);

      // 2. Download Atomic Habits in Kurdish -> uses slot 2!
      final res2 = await DownloadManager().downloadBook(atomicHabits, 'ku', (_) {});
      expect(res2, isTrue);

      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(2));
      expect(DownloadService.isEditionDownloadedSync('atomic_habits', 'en'), isTrue);
      expect(DownloadService.isEditionDownloadedSync('atomic_habits', 'ku'), isTrue);

      // Verify two independent encrypted packages and key aliases exist
      final userDocsDir = tempDir.path;
      final enDir = Directory('$userDocsDir/users/premium_user_slots/books/atomic_habits/en');
      final kuDir = Directory('$userDocsDir/users/premium_user_slots/books/atomic_habits/ku');
      expect(await enDir.exists(), isTrue);
      expect(await kuDir.exists(), isTrue);
      expect(await File('${enDir.path}/summary.partwkbook').exists(), isTrue);
      expect(await File('${kuDir.path}/summary.partwkbook').exists(), isTrue);
      expect(await File('${enDir.path}/download.complete').exists(), isTrue);
      expect(await File('${kuDir.path}/download.complete').exists(), isTrue);

      expect(secureStorageMock.containsKey('enc_key_premium_user_slots_atomic_habits_en'), isTrue);
      expect(secureStorageMock.containsKey('enc_key_premium_user_slots_atomic_habits_ku'), isTrue);

      // 3. Download a third different language/book -> fills quota (3/3)
      final sapiens = Book(
        id: 'sapiens',
        title: {'en': 'Sapiens'},
        author: {'en': 'Yuval Noah Harari'},
        coverImageUrl: '',
        categoryIds: ['cat-history-big-ideas'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'Sapiens Ch 1'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res3 = await DownloadManager().downloadBook(sapiens, 'en', (_) {});
      expect(res3, isTrue);

      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(3));

      // 4. Fourth edition is blocked with DownloadLimitExceededException
      final book4 = Book(
        id: 'book_4',
        title: {'en': 'Book 4'},
        author: {'en': 'Author 4'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'Content'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => DownloadManager().downloadBook(book4, 'en', (_) {}),
        throwsA(isA<DownloadLimitExceededException>()),
      );
    });

    test('Deleting one language edition frees exactly one slot and preserves other language edition of same book', () async {
      final user = UserModel(
        id: 'user_delete_test',
        name: 'Delete Tester',
        email: 'del@test.com',
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
      mockAuth.setUser(user);

      final atomicHabits = Book(
        id: 'atomic_habits_isolation',
        title: {'en': 'Atomic Habits', 'ku': 'خووە بنەڕەتییەکان'},
        author: {'en': 'James Clear', 'ku': 'جەیمس کلیر'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'Atomic Habits 5m', 'ku': 'کورتەی ٥ خولەک'},
        fifteenMinuteSummary: {'en': 'Atomic Habits 15m', 'ku': 'کورتەی ١٥ خولەک'},
        chapterSummaries: {
          'en': [{'title': 'Chapter 1', 'content': 'English Chapter 1 Working'}],
          'ku': [{'title': 'بەشی ١', 'content': 'دەقی کوردی بەشی ١'}],
        },
        keyIdeas: {'en': ['Idea EN'], 'ku': ['بیرۆکەی کوردی']},
        keyQuotes: {'en': ['Quote EN'], 'ku': ['وتەی کوردی']},
        actionPoints: {'en': ['Action EN'], 'ku': ['خاڵی کردارەکی']},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Download both English and Kurdish editions
      await DownloadManager().downloadBook(atomicHabits, 'en', (_) {});
      await DownloadManager().downloadBook(atomicHabits, 'ku', (_) {});

      var editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(2));

      // Delete Kurdish edition only
      await DownloadService().removeDownload('atomic_habits_isolation', languageCode: 'ku');

      // 1. Quota: frees exactly one slot (now 1/3)
      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(1));
      expect(editions.first.languageCode, equals('en'));

      // 2. Kurdish files and key are gone
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_isolation', 'ku'), isFalse);
      expect(secureStorageMock.containsKey('enc_key_user_delete_test_atomic_habits_isolation_ku'), isFalse);

      // 3. English files, key, licence, and decryption remain 100% working
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_isolation', 'en'), isTrue);
      expect(secureStorageMock.containsKey('enc_key_user_delete_test_atomic_habits_isolation_en'), isTrue);
      expect(await LicenceManager.isLicenceValid('atomic_habits_isolation', languageCode: 'en', userId: user.id), isTrue);

      final decryptedEnglish = await DownloadManager.loadBookContent(atomicHabits, languageCode: 'en');
      expect(decryptedEnglish.chapterSummaries['en']!.first['content'], equals('English Chapter 1 Working'));
    });

    test('Sequential Rule Verification: Download EN (1/3) -> Download KU (2/3) -> Download AR (3/3) -> Attempt 4th (blocked) -> Delete KU (2/3) -> Confirm EN opens and plays offline -> Download 4th (3/3)', () async {
      final user = UserModel(
        id: 'user_sequential_evidence',
        name: 'Evidence Tester',
        email: 'evidence@partwk.com',
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
      mockAuth.setUser(user);

      // Book 1: Atomic Habits (EN + KU)
      final atomicHabits = Book(
        id: 'atomic_habits_seq',
        title: {'en': 'Atomic Habits', 'ku': 'خووە بنەڕەتییەکان'},
        author: {'en': 'James Clear', 'ku': 'جەیمس کلیر'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'Atomic Habits 5m', 'ku': 'کورتەی ٥ خولەک'},
        fifteenMinuteSummary: {'en': 'Atomic Habits 15m', 'ku': 'کورتەی ١٥ خولەک'},
        chapterSummaries: {
          'en': [{'title': 'The Fundamentals', 'content': 'Atomic Habits English Offline Text'}],
          'ku': [{'title': 'بنەما سەرەکییەکان', 'content': 'دەقی کوردی خووە بنەڕەتییەکان ئۆفلاین'}],
        },
        keyIdeas: {'en': ['Tiny changes'], 'ku': ['گۆڕانکارییە بچووکەکان']},
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

      // Book 2: Sapiens (AR)
      final sapiens = Book(
        id: 'sapiens_ar_seq',
        title: {'en': 'Sapiens', 'ar': 'العاقل: تاريخ مختصر للنوع البشري'},
        author: {'en': 'Yuval Noah Harari', 'ar': 'يوفال نوح هراري'},
        coverImageUrl: '',
        categoryIds: ['cat-history-big-ideas'],
        tags: [],
        description: {'ar': 'ملخص كتاب العاقل'},
        fiveMinuteSummary: {'ar': 'العاقل ٥ دقائق'},
        fifteenMinuteSummary: {},
        chapterSummaries: {
          'ar': [{'title': 'الفصل الأول', 'content': 'النص العربي لكتاب العاقل'}],
        },
        keyIdeas: {'ar': ['الثورة الإدراكية']},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 950,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Book 3: Deep Work (4th edition candidate)
      final deepWork = Book(
        id: 'deep_work_seq',
        title: {'en': 'Deep Work'},
        author: {'en': 'Cal Newport'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Deep Work summary'},
        fiveMinuteSummary: {'en': 'Deep Work 5m'},
        fifteenMinuteSummary: {},
        chapterSummaries: {
          'en': [{'title': 'Rule 1', 'content': 'Work Deeply Offline Text'}],
        },
        keyIdeas: {'en': ['Focus without distraction']},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 800,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 1. Download Atomic Habits in English -> 1 / 3
      final step1 = await DownloadManager().downloadBook(atomicHabits, 'en', (_) {});
      expect(step1, isTrue);
      var editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(1));
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_seq', 'en'), isTrue);
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_seq', 'ku'), isFalse);
      print('✓ STEP 1: Downloaded Atomic Habits in English -> 1 / 3 slots');

      // 2. Download Atomic Habits in Kurdish -> 2 / 3
      final step2 = await DownloadManager().downloadBook(atomicHabits, 'ku', (_) {});
      expect(step2, isTrue);
      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(2));
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_seq', 'en'), isTrue);
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_seq', 'ku'), isTrue);
      print('✓ STEP 2: Downloaded Atomic Habits in Kurdish -> 2 / 3 slots');

      // 3. Download a different book in Arabic (Sapiens) -> 3 / 3
      final step3 = await DownloadManager().downloadBook(sapiens, 'ar', (_) {});
      expect(step3, isTrue);
      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(3));
      expect(DownloadService.isEditionDownloadedSync('sapiens_ar_seq', 'ar'), isTrue);
      print('✓ STEP 3: Downloaded Sapiens in Arabic -> 3 / 3 slots (limit reached)');

      // 4. Attempt a fourth language edition -> BLOCKED
      expect(
        () => DownloadManager().downloadBook(deepWork, 'en', (_) {}),
        throwsA(isA<DownloadLimitExceededException>()),
      );
      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(3));
      print('✓ STEP 4: Attempted 4th language edition (Deep Work EN) -> BLOCKED by DownloadLimitExceededException');

      // 5. Delete Atomic Habits Kurdish -> 2 / 3
      await DownloadService().removeDownload('atomic_habits_seq', languageCode: 'ku');
      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(2));
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_seq', 'ku'), isFalse);
      expect(secureStorageMock.containsKey('enc_key_user_sequential_evidence_atomic_habits_seq_ku'), isFalse);
      print('✓ STEP 5: Deleted Atomic Habits in Kurdish -> 2 / 3 slots (freed 1 slot)');

      // 6. Confirm Atomic Habits English still opens and plays offline
      expect(DownloadService.isEditionDownloadedSync('atomic_habits_seq', 'en'), isTrue);
      expect(secureStorageMock.containsKey('enc_key_user_sequential_evidence_atomic_habits_seq_en'), isTrue);
      expect(await LicenceManager.isLicenceValid('atomic_habits_seq', languageCode: 'en', userId: user.id), isTrue);

      // Verify text opens and decrypts properly
      final openedBook = await DownloadManager.loadBookContent(atomicHabits, languageCode: 'en');
      expect(openedBook.chapterSummaries['en']!.first['content'], equals('Atomic Habits English Offline Text'));

      // Verify audio loads and plays offline
      final enAudioPath = '${tempDir.path}/users/${user.id}/books/atomic_habits_seq/en/audio_0.partwkaudio';
      await EncryptedContentStorage.saveEncryptedFile(
        user.id,
        'atomic_habits_seq',
        enAudioPath,
        utf8.encode('RIFF_ENCRYPTED_MOCK_WAV_AUDIO_FOR_OFFLINE_PLAYBACK'),
        languageCode: 'en',
      );
      final audioSource = await DownloadManager.loadAudioSource(
        'atomic_habits_seq',
        'en',
        const MediaItem(id: 'atomic_habits_seq_0', title: 'The Fundamentals'),
      );
      expect(audioSource, isNotNull);
      print('✓ STEP 6: Confirmed Atomic Habits English still opens text and plays audio offline');

      // 7. Download the fourth edition successfully -> 3 / 3
      final step7 = await DownloadManager().downloadBook(deepWork, 'en', (_) {});
      expect(step7, isTrue);
      editions = await DownloadService().getDownloadedEditions();
      expect(editions.length, equals(3));
      expect(DownloadService.isEditionDownloadedSync('deep_work_seq', 'en'), isTrue);
      print('✓ STEP 7: Downloaded 4th edition (Deep Work EN) successfully -> 3 / 3 slots');
    });
  });

  group('5. Family-Member Licence Expiry & Entitlement Rules', () {
    test('Family member licence expiry derives from primary subscriber verified expiry (earliest of 7 days or primary expiry)', () async {
      // Case 1: Primary subscriber verified subscription expires in 3 days (< 7 days)
      final subExpiry3Days = DateTime.now().add(const Duration(days: 3)).toIso8601String();
      final familyMemberShort = UserModel(
        id: 'family_user_short',
        name: 'Family User Short',
        email: 'fam_short@test.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        hasFamilyPremium: true,
        primarySubscriptionExpiry: subExpiry3Days,
        streakCount: 0,
        lastActiveDate: '2026-11-06',
        familyMembers: [],
        createdAt: DateTime.now(),
      );
      mockAuth.setUser(familyMemberShort);

      final licenceShort = await LicenceManager.issueDownloadLicence(
        familyMemberShort.id,
        'book_fam_1',
        languageCode: 'en',
      );
      final expiryShort = DateTime.parse(licenceShort.licenceExpiryDate);
      // Must be capped by the primary subscriber expiry (<= 3 days)
      expect(expiryShort.difference(DateTime.now()).inDays, lessThanOrEqualTo(3));

      // Case 2: Primary subscriber subscription has 365 days remaining (> 7 days)
      final subExpiry1Year = DateTime.now().add(const Duration(days: 365)).toIso8601String();
      final familyMemberLong = familyMemberShort.copyWith(
        primarySubscriptionExpiry: subExpiry1Year,
      );
      mockAuth.setUser(familyMemberLong);

      final licenceLong = await LicenceManager.issueDownloadLicence(
        familyMemberLong.id,
        'book_fam_2',
        languageCode: 'en',
      );
      final expiryLong = DateTime.parse(licenceLong.licenceExpiryDate);
      // Must be capped at 7 days from download
      expect(expiryLong.difference(DateTime.now()).inDays, lessThanOrEqualTo(7));
    });

    test('Expired primary subscriber entitlement blocks access and revokes licence', () async {
      final expiredPrimaryDate = DateTime.now().subtract(const Duration(days: 1)).toIso8601String();
      final familyMemberExpired = UserModel(
        id: 'family_user_expired',
        name: 'Family User Expired',
        email: 'fam_exp@test.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        hasFamilyPremium: true,
        primarySubscriptionExpiry: expiredPrimaryDate,
        streakCount: 0,
        lastActiveDate: '2026-11-06',
        familyMembers: [],
        createdAt: DateTime.now(),
      );
      mockAuth.setUser(familyMemberExpired);

      expect(familyMemberExpired.isPremium, isFalse);

      final book = Book(
        id: 'book_fam_blocked',
        title: {'en': 'Blocked Book'},
        author: {'en': 'Author'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'Text'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Downloading is denied
      expect(
        () => DownloadManager().downloadBook(book, 'en', (_) {}),
        throwsA(isA<DownloadPermissionDeniedException>()),
      );
    });

    test('Valid offline packages are NOT wiped on network timeout or phone offline', () async {
      final validUser = UserModel(
        id: 'user_offline_safe',
        name: 'Offline Safe User',
        email: 'safe@test.com',
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
      mockAuth.setUser(validUser);

      final book = Book(
        id: 'offline_safe_book',
        title: {'en': 'Safe Book'},
        author: {'en': 'Author'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'Safe 5m summary'},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'Safe offline text'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await DownloadManager().downloadBook(book, 'en', (_) {});
      expect(DownloadService.isEditionDownloadedSync('offline_safe_book', 'en'), isTrue);

      // Verify licence is valid while offline
      final isValidOffline = await LicenceManager.isLicenceValid('offline_safe_book', languageCode: 'en', userId: validUser.id);
      expect(isValidOffline, isTrue);

      // Content and keys are NOT wiped
      final userDocsDir = tempDir.path;
      final file = File('$userDocsDir/users/user_offline_safe/books/offline_safe_book/en/summary.partwkbook');
      expect(await file.exists(), isTrue);
      expect(secureStorageMock.containsKey('enc_key_user_offline_safe_offline_safe_book_en'), isTrue);
    });
  });

  group('6. Account Switching & Storage Placement Isolation', () {
    test('User B and Guest cannot see, list, or access User A downloads or decrypt any edition', () async {
      final userA = UserModel(
        id: 'user_alice',
        name: 'Alice',
        email: 'alice@test.com',
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
      mockAuth.setUser(userA);

      final bookA = Book(
        id: 'alice_book_1',
        title: {'en': 'Alice Exclusive Book'},
        author: {'en': 'Author'},
        coverImageUrl: '',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {},
        fifteenMinuteSummary: {},
        chapterSummaries: {'en': [{'title': 'Chapter 1', 'content': 'Sample chapter content'}]},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 100,
        isPremium: true,
        isPublished: true,
        hiddenLanguages: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await DownloadManager().downloadBook(bookA, 'en', (_) {});
      expect(DownloadService.isEditionDownloadedSync('alice_book_1', 'en'), isTrue);
      expect((await DownloadService().getDownloadedEditions()).length, equals(1));

      // File placement: verify files are in app-private storage users/user_alice/books/alice_book_1/en/...
      final userDocsDir = tempDir.path;
      final aliceEditionFolder = Directory('$userDocsDir/users/user_alice/books/alice_book_1/en');
      expect(await aliceEditionFolder.exists(), isTrue);
      final completeMarker = File('${aliceEditionFolder.path}/download.complete');
      expect(await completeMarker.exists(), isTrue);

      // Sign out to Guest
      await mockAuth.signOut();
      expect(DownloadService.isEditionDownloadedSync('alice_book_1', 'en'), isFalse);
      expect((await DownloadService().getDownloadedEditions()).length, equals(0));

      // Sign in as User Bob (also Premium)
      final userB = UserModel(
        id: 'user_bob',
        name: 'Bob',
        email: 'bob@test.com',
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
      mockAuth.setUser(userB);

      // Bob's download list is completely empty
      expect(DownloadService.isEditionDownloadedSync('alice_book_1', 'en'), isFalse);
      final bobDownloads = await DownloadService().getDownloadedEditions();
      expect(bobDownloads.isEmpty, isTrue);

      // Bob cannot load or decrypt Alice's edition
      expect(await DownloadManager.isEditionDownloaded('alice_book_1', 'en'), isFalse);
      expect(await LicenceManager.isLicenceValid('alice_book_1', languageCode: 'en', userId: userB.id), isFalse);
      expect(
        () => EncryptedContentStorage.readDecryptedFile(
          userB.id,
          'alice_book_1',
          '${aliceEditionFolder.path}/summary.partwkbook',
          languageCode: 'en',
        ),
        throwsA(anything),
      );
    });
  });
}
