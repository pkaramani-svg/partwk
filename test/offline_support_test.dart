import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio/just_audio.dart';

import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/encrypted_content_storage.dart';
import 'package:partwk/core/services/licence_manager.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/core/services/download_manager.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/services/download_service.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/models/quiz.dart';
import 'package:partwk/models/flashcard.dart';
import 'package:partwk/models/note.dart';
import 'package:partwk/models/highlight.dart';
import 'package:partwk/models/learning_path.dart';
import 'package:partwk/models/achievement.dart';

class TestAuthService extends AuthService {
  UserModel? _currentUser;
  bool _isGuest = false;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  bool get isGuest => _isGuest;

  set currentUser(UserModel? user) {
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
  Future<void> checkAndUnlockAchievements() async {}

  @override
  Future<void> signInAsGuest() async {}

  @override
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  @override
  Future<void> updateSelectedLanguage(String langCode) async {}
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
  Future<void> addCompletedBook(String bookId, {String source = 'automatic', DateTime? completedAt}) async {
    if (_currentUser != null) {
      final list = List<String>.from(_currentUser!.completedBooks);
      if (!list.contains(bookId)) list.add(bookId);
      final details = Map<String, dynamic>.from(_currentUser!.completionDetails);
      details[bookId] = {
        'completed': true,
        'source': source,
        'completedAt': (completedAt ?? DateTime.now()).toIso8601String(),
      };
      _currentUser = _currentUser!.copyWith(
        completedBooks: list,
        completionDetails: details,
      );
    }
  }

  @override
  Future<void> removeCompletedBook(String bookId) async {
    if (_currentUser != null) {
      final list = List<String>.from(_currentUser!.completedBooks)..remove(bookId);
      final details = Map<String, dynamic>.from(_currentUser!.completionDetails);
      details[bookId] = {
        'completed': false,
        'completedAt': DateTime.now().toIso8601String(),
      };
      _currentUser = _currentUser!.copyWith(
        completedBooks: list,
        completionDetails: details,
      );
    }
  }

  @override
  Future<void> linkFamilyMember(String email) async {}
  @override
  Future<void> upgradeToPremium() async {}
  @override
  Future<void> updateListeningProgress(String bookId, String langCode, int chapterIndex, int positionSeconds, {int accumulatedSecondHalfSeconds = 0, bool localOnly = false}) async {}
  @override
  Future<void> recordActivity() async {}
  @override
  Future<void> addLearningTime(int seconds) async {}
  @override
  Future<void> updatePresence({required String screen, String? bookTitle, String? bookId, String? activityType}) async {}
  @override
  Future<void> setOnlineStatus(bool isOnline) async {}
}

class TestDatabaseService extends DatabaseService {
  final List<Book> _books = [];

  @override
  List<Category> get categories => [];
  @override
  List<Book> get books => _books;
  @override
  List<LearningPath> get learningPaths => [];
  @override
  List<Achievement> get achievements => [];

  @override
  Future<List<Book>> fetchBooks() async => _books;
  @override
  Future<List<Category>> fetchCategories() async => [];
  @override
  Future<List<LearningPath>> fetchLearningPaths() async => [];
  @override
  Future<List<Achievement>> fetchAchievements() async => [];

  @override
  Future<Quiz?> fetchQuizForBook(String bookId, String langCode) async => null;
  @override
  Future<List<Flashcard>> fetchFlashcardsForBook(String bookId, String langCode) async => [];

  @override
  Future<List<Note>> fetchNotes(String userId) async => [];
  @override
  Future<void> addNote(Note note) async {}
  @override
  Future<void> deleteNote(String noteId) async {}
  @override
  Future<List<Highlight>> fetchHighlights(String userId) async => [];
  @override
  Future<void> addHighlight(Highlight highlight) async {}
  @override
  Future<void> deleteHighlight(String highlightId) async {}

  @override
  Future<void> addBook(Book book) async {
    _books.add(book);
  }
  @override
  Future<void> addQuiz(Quiz quiz) async {}
  @override
  Future<void> updateTranslations(String key, String enVal, String kuVal, String arVal) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final Map<String, String> secureStorageMock = {};
  late TestAuthService mockAuth;
  late TestDatabaseService mockDb;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('partwk_test_dir');

    // Mock Secure Storage method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        final args = methodCall.arguments;
        final key = args is Map ? args['key'] as String? : null;
        final value = args is Map ? args['value'] as String? : null;

        switch (methodCall.method) {
          case 'read':
            return secureStorageMock[key ?? ''];
          case 'write':
            if (key != null && value != null) {
              secureStorageMock[key] = value;
            }
            return null;
          case 'delete':
            if (key != null) {
              secureStorageMock.remove(key);
            }
            return null;
          case 'deleteAll':
            secureStorageMock.clear();
            return null;
          case 'containsKey':
            return secureStorageMock.containsKey(key ?? '');
          default:
            return null;
        }
      },
    );

    // Mock Path Provider method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getApplicationDocumentsDirectory':
            return tempDir.path;
          case 'getTemporaryDirectory':
            return tempDir.path;
          default:
            return null;
        }
      },
    );
  });

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    secureStorageMock.clear();
    SharedPreferences.setMockInitialValues({});
    
    mockAuth = TestAuthService();
    mockDb = TestDatabaseService();
    
    AppLocator.auth = mockAuth;
    AppLocator.db = mockDb;

    await DownloadService.init();
    NetworkGuard.mockConnectionStatus = null;
  });

  group('Offline Caching & Launch tests', () {
    test('User profile is cached and loaded successfully on offline startup', () async {
      final user = UserModel(
        id: 'user-777',
        name: 'Jane Doe',
        email: 'jane@example.com',
        selectedLanguage: 'ku',
        interests: ['business'],
        learningGoals: ['read_more'],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'premium',
        streakCount: 5,
        lastActiveDate: '2026-06-22',
        familyMembers: [],
        createdAt: DateTime.now(),
      );

      // Verify no cached user initially
      final initialCached = await OfflineAvailabilityRepository.getCachedUser();
      expect(initialCached, isNull);

      // Cache user
      await OfflineAvailabilityRepository.cacheUser(user);

      // Retrieve cached user
      final loadedCached = await OfflineAvailabilityRepository.getCachedUser();
      expect(loadedCached, isNotNull);
      expect(loadedCached!.id, equals('user-777'));
      expect(loadedCached.subscriptionStatus, equals('premium'));
      expect(loadedCached.selectedLanguage, equals('ku'));
    });

    test('Book metadata is cached with stripped sensitive content', () async {
      final book = Book(
        id: 'book-habit',
        title: {'en': 'Atomic Habits'},
        author: {'en': 'James Clear'},
        coverImageUrl: 'local:habit.jpg',
        categoryIds: ['cat-productivity'],
        tags: [],
        description: {'en': 'Build good habits.'},
        fiveMinuteSummary: {'en': 'SENSITIVE FIVE MINUTE SUMMARY'},
        fifteenMinuteSummary: {'en': 'SENSITIVE FIFTEEN MINUTE SUMMARY'},
        chapterSummaries: {'en': [{'title': 'Ch 1', 'content': 'SENSITIVE CHAPTER SUMMARY'}]},
        keyIdeas: {'en': ['SENSITIVE IDEA']},
        keyQuotes: {'en': ['SENSITIVE QUOTE']},
        actionPoints: {'en': ['SENSITIVE POINT']},
        audioUrl: {'en': 'local:habit.mp3'},
        duration: 450,
        isPremium: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      );

      // Cache metadata
      await OfflineAvailabilityRepository.cacheBookMetadata(book);

      // Fetch cached metadata
      final cachedBooks = await OfflineAvailabilityRepository.getCachedBooksMetadata();
      expect(cachedBooks.length, equals(1));
      
      final cachedBook = cachedBooks.first;
      expect(cachedBook.id, equals('book-habit'));
      expect(cachedBook.title['en'], equals('Atomic Habits'));
      
      // Confirm all sensitive data has been stripped out
      expect(cachedBook.fiveMinuteSummary, isEmpty);
      expect(cachedBook.fifteenMinuteSummary, isEmpty);
      expect(cachedBook.chapterSummaries, isEmpty);
      expect(cachedBook.keyIdeas, isEmpty);
      expect(cachedBook.keyQuotes, isEmpty);
      expect(cachedBook.actionPoints, isEmpty);
    });
  });

  group('DRM & Local Content Encryption tests', () {
    late Book book;
    late UserModel user;

    setUp(() {
      user = UserModel(
        id: 'user-drm',
        name: 'DRM Tester',
        email: 'tester@drm.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'premium',
        streakCount: 0,
        lastActiveDate: '',
        familyMembers: [],
        createdAt: DateTime.now(),
      );
      mockAuth.currentUser = user;

      book = Book(
        id: 'book-drm-1',
        title: {'en': 'DRM Book Title'},
        author: {'en': 'DRM Author'},
        coverImageUrl: 'local:cover.jpg',
        categoryIds: [],
        tags: [],
        description: {'en': 'A DRM book description'},
        fiveMinuteSummary: {'en': 'This is the decrypted five-minute summary.'},
        fifteenMinuteSummary: {'en': 'This is the decrypted fifteen-minute summary.'},
        chapterSummaries: {
          'en': [{'title': 'Chapter 1', 'content': 'This is the decrypted chapter one content.'}]
        },
        keyIdeas: {'en': ['Idea 1']},
        keyQuotes: {'en': ['Quote 1']},
        actionPoints: {'en': ['Point 1']},
        audioUrl: {'en': 'local:audio.mp3'},
        duration: 600,
        isPremium: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      );
    });

    test('Securely encrypts and decrypts text summaries and audio bytes', () async {
      // 1. Encrypt and save text summary
      final sensitiveContent = {
        'fiveMinuteSummary': book.fiveMinuteSummary,
        'fifteenMinuteSummary': book.fifteenMinuteSummary,
        'chapterSummaries': book.chapterSummaries,
        'keyIdeas': book.keyIdeas,
        'keyQuotes': book.keyQuotes,
        'actionPoints': book.actionPoints,
      };
      
      final bookDir = Directory('${tempDir.path}/books/${book.id}');
      if (!bookDir.existsSync()) {
        bookDir.createSync(recursive: true);
      }
      
      final textFilePath = '${bookDir.path}/summary.partwkbook';
      final plaintextTextBytes = utf8.encode(jsonEncode(sensitiveContent));
      
      await EncryptedContentStorage.saveEncryptedFile(user.id, book.id, textFilePath, plaintextTextBytes);
      
      // Verify file exists
      final textFile = File(textFilePath);
      expect(textFile.existsSync(), isTrue);

      // Verify that the file content on disk is encrypted (does not contain plaintext)
      final rawFileBytes = textFile.readAsBytesSync();
      final rawFileString = String.fromCharCodes(rawFileBytes);
      expect(rawFileString.contains('decrypted five-minute summary'), isFalse);

      // 2. Encrypt and save audio bytes
      final audioFilePath = '${bookDir.path}/audio_en_0.partwkaudio';
      final plaintextAudioBytes = utf8.encode('DUMMY PLAINTEXT MP3 AUDIO DATA');
      
      await EncryptedContentStorage.saveEncryptedFile(user.id, book.id, audioFilePath, plaintextAudioBytes);
      
      // Verify audio file exists and is encrypted
      final audioFile = File(audioFilePath);
      expect(audioFile.existsSync(), isTrue);
      expect(String.fromCharCodes(audioFile.readAsBytesSync()).contains('DUMMY PLAINTEXT MP3'), isFalse);

      // 3. Issue Licence and cache metadata (to simulate a fully downloaded book)
      final licence = await LicenceManager.issueDownloadLicence(user.id, book.id);
      await LicenceManager.saveLicence(licence);
      await OfflineAvailabilityRepository.cacheBookMetadata(book);
      await LicenceManager.recordOnlineValidation(); // record validation

      // Create complete marker file
      final completeFile = File('${bookDir.path}/download.complete');
      await completeFile.create();

      // 4. Verify book downloaded status
      expect(await DownloadManager.isBookDownloaded(book.id), isTrue);

      // 5. Load and decrypt book text summary in-memory
      final loadedBook = await DownloadManager.loadBookContent(book);
      expect(loadedBook.fiveMinuteSummary['en'], equals('This is the decrypted five-minute summary.'));
      expect(loadedBook.chapterSummaries['en']!.first['content'], equals('This is the decrypted chapter one content.'));

      // 6. Stream and decrypt audio in-memory (UriAudioSource from AudioSource.file)
      final tag = MediaItem(id: '${book.id}_0', title: 'DRM Title');
      final audioSource = await DownloadManager.loadAudioSource(book.id, 'en', tag);
      expect(audioSource, isA<AudioSource>());

      final uri = (audioSource as dynamic).uri;
      final decryptedFile = File(uri.toFilePath());
      final decryptedBytes = await decryptedFile.readAsBytes();
      expect(utf8.decode(decryptedBytes), equals('DUMMY PLAINTEXT MP3 AUDIO DATA'));
    });

    test('Revoking user entitlement wipes decryption keys and deletes cached files', () async {
      // Setup: Encrypt and save content
      final bookDir = Directory('${tempDir.path}/books/${book.id}');
      if (!bookDir.existsSync()) {
        bookDir.createSync(recursive: true);
      }
      final textFilePath = '${bookDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(user.id, book.id, textFilePath, utf8.encode('plaintext summary'));
      
      final licence = await LicenceManager.issueDownloadLicence(user.id, book.id);
      await LicenceManager.saveLicence(licence);
      await OfflineAvailabilityRepository.cacheBookMetadata(book);
      await LicenceManager.recordOnlineValidation();

      // Create complete marker file
      final completeFile = File('${bookDir.path}/download.complete');
      await completeFile.create();

      expect(await DownloadManager.isBookDownloaded(book.id), isTrue);
      expect(secureStorageMock.containsKey('enc_key_${user.id}_${book.id}'), isTrue);

      // Change user status to FREE (premium expired/revoked)
      final freeUser = UserModel(
        id: user.id,
        name: user.name,
        email: user.email,
        selectedLanguage: user.selectedLanguage,
        interests: user.interests,
        learningGoals: user.learningGoals,
        savedBooks: user.savedBooks,
        completedBooks: user.completedBooks,
        likedBooks: user.likedBooks,
        listeningProgress: user.listeningProgress,
        readingProgress: user.readingProgress,
        subscriptionStatus: 'free', // Not Premium!
        streakCount: user.streakCount,
        lastActiveDate: user.lastActiveDate,
        familyMembers: user.familyMembers,
        createdAt: user.createdAt,
      );
      mockAuth.currentUser = freeUser;

      // Licence validity check should fail and trigger automatic revocation
      final isValid = await LicenceManager.isLicenceValid(book.id);
      expect(isValid, isFalse);

      // Key must be deleted from secure storage
      expect(secureStorageMock.containsKey('enc_key_${user.id}_${book.id}'), isFalse);

      // Files must be deleted from the file system
      expect(bookDir.existsSync(), isFalse);
      expect(await DownloadManager.isBookDownloaded(book.id), isFalse);
    });

    test('Rejects tampered license (signature validation failures)', () async {
      // Setup: Save encrypted book and valid licence
      final bookDir = Directory('${tempDir.path}/books/${book.id}');
      if (!bookDir.existsSync()) {
        bookDir.createSync(recursive: true);
      }
      final textFilePath = '${bookDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(user.id, book.id, textFilePath, utf8.encode('plaintext summary'));
      
      final licence = await LicenceManager.issueDownloadLicence(user.id, book.id);
      await LicenceManager.saveLicence(licence);
      await LicenceManager.recordOnlineValidation();

      // Read licence, modify it, and write it back (tampering)
      final licenceFile = File('${bookDir.path}/licence.json');
      final licenceJson = jsonDecode(licenceFile.readAsStringSync());
      
      // Tamper with the expiry date
      licenceJson['licenceExpiryDate'] = DateTime.now().subtract(const Duration(days: 10)).toIso8601String();
      licenceFile.writeAsStringSync(jsonEncode(licenceJson));

      // Licence check must fail and trigger automatic revocation
      final isValid = await LicenceManager.isLicenceValid(book.id);
      expect(isValid, isFalse);

      // Verify revocation wiped the keys and files
      expect(secureStorageMock.containsKey('enc_key_${user.id}_${book.id}'), isFalse);
      expect(bookDir.existsSync(), isFalse);
    });

    test('Offline grace period blocks use when offline longer than 7 days', () async {
      // Setup: Valid premium user and valid licence
      final bookDir = Directory('${tempDir.path}/books/${book.id}');
      if (!bookDir.existsSync()) {
        bookDir.createSync(recursive: true);
      }
      final licence = await LicenceManager.issueDownloadLicence(user.id, book.id);
      await LicenceManager.saveLicence(licence);

      // 1. Force offline status
      NetworkGuard.mockConnectionStatus = false;

      // 2. Check isOfflineTooLong when no validation has ever occurred
      final prefs = await SharedPreferences.getInstance();
      expect(await LicenceManager.isOfflineTooLong(), isTrue); // Should be true because last validation is null
      
      // 3. Set last validation to 5 days ago (should be allowed)
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      await prefs.setString('last_licence_validation_time', fiveDaysAgo.toIso8601String());
      expect(await LicenceManager.isOfflineTooLong(), isFalse);

      // 4. Set last validation to 8 days ago (should block)
      final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
      await prefs.setString('last_licence_validation_time', eightDaysAgo.toIso8601String());
      expect(await LicenceManager.isOfflineTooLong(), isTrue);

      // 5. Connect back online and check. Should update validation time automatically.
      NetworkGuard.mockConnectionStatus = true;
      expect(await LicenceManager.isOfflineTooLong(), isFalse);
      
      final newValStr = prefs.getString('last_licence_validation_time');
      expect(newValStr, isNotNull);
      expect(DateTime.now().difference(DateTime.parse(newValStr!)).inMinutes, equals(0));
    });
  });
}
