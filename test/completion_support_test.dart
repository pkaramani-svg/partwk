import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
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
import 'package:partwk/features/book/book_details_screen.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:provider/provider.dart';

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
      final alreadyCompleted = _currentUser!.completedBooks.contains(bookId);
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
      notifyListeners();

      if (!alreadyCompleted) {
        try {
          final books = await AppLocator.db.fetchBooks();
          final book = books.firstWhere((b) => b.id == bookId);
          triggerCompletionCelebration(book);
        } catch (_) {}
      }
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
      notifyListeners();
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

class TestDownloadService implements DownloadService {
  @override
  Future<bool> isBookDownloaded(String bookId) async {
    return false;
  }

  @override
  Future<bool> downloadBook(Book book, String languageCode, Function(double) onProgress) async {
    return true;
  }

  @override
  Future<List<Book>> getDownloadedBooks() async {
    return [];
  }

  @override
  Future<String?> getLocalCoverUri(String bookId) async {
    return null;
  }

  @override
  Future<String?> getLocalAudioUri(String bookId, String languageCode) async {
    return null;
  }

  @override
  Future<void> removeDownload(String bookId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final Map<String, String> secureStorageMock = {};
  late TestAuthService mockAuth;
  late TestDatabaseService mockDb;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('partwk_test_completion');

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

    DownloadService.mock = TestDownloadService();
    await DownloadService.init();
    NetworkGuard.mockConnectionStatus = true;
  });

  group('Completions support unit tests', () {
    test('Manual completion updates book progress to 1.0 (100%)', () async {
      final book = Book(
        id: 'book-123',
        title: {'en': 'Test Book'},
        author: {'en': 'Author'},
        coverImageUrl: 'local:cover.jpg',
        categoryIds: [],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'S1'},
        fifteenMinuteSummary: {'en': 'S2'},
        chapterSummaries: {},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 200,
        isPremium: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      );

      final user = UserModel(
        id: 'user-123',
        name: 'John',
        email: 'john@example.com',
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
        lastActiveDate: '',
        familyMembers: [],
        createdAt: DateTime.now(),
      );

      mockAuth.currentUser = user;
      await mockDb.addBook(book);

      expect(mockAuth.currentUser!.getBookProgress(book, 'en'), 0.0);

      // Complete book manually
      await mockAuth.addCompletedBook(book.id, source: 'manual');

      expect(mockAuth.currentUser!.completedBooks.contains(book.id), isTrue);
      expect(mockAuth.currentUser!.completionDetails[book.id]['completed'], isTrue);
      expect(mockAuth.currentUser!.completionDetails[book.id]['source'], 'manual');
      expect(mockAuth.currentUser!.getBookProgress(book, 'en'), 1.0);
    });

    test('Mark as Not Complete reverts status without wiping reading progress', () async {
      final book = Book(
        id: 'book-123',
        title: {'en': 'Test Book'},
        author: {'en': 'Author'},
        coverImageUrl: 'local:cover.jpg',
        categoryIds: [],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'S1'},
        fifteenMinuteSummary: {'en': 'S2'},
        chapterSummaries: {},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 200,
        isPremium: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      );

      final user = UserModel(
        id: 'user-123',
        name: 'John',
        email: 'john@example.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: [],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {'book-123': 0.65}, // 65% reading progress
        subscriptionStatus: 'free',
        streakCount: 0,
        lastActiveDate: '',
        familyMembers: [],
        createdAt: DateTime.now(),
      );

      mockAuth.currentUser = user;
      await mockDb.addBook(book);

      expect(mockAuth.currentUser!.getBookProgress(book, 'en'), 0.65);

      // Complete book
      await mockAuth.addCompletedBook(book.id, source: 'manual');
      expect(mockAuth.currentUser!.getBookProgress(book, 'en'), 1.0);

      // Revert completion
      await mockAuth.removeCompletedBook(book.id);
      expect(mockAuth.currentUser!.completedBooks.contains(book.id), isFalse);
      expect(mockAuth.currentUser!.completionDetails[book.id]['completed'], isFalse);
      // Progress should return to 65% (reading progress preserved)
      expect(mockAuth.currentUser!.getBookProgress(book, 'en'), 0.65);
    });

    test('Completion triggers celebration stream exactly once, duplicates blocked', () async {
      final book = Book(
        id: 'book-123',
        title: {'en': 'Test Book'},
        author: {'en': 'Author'},
        coverImageUrl: 'local:cover.jpg',
        categoryIds: [],
        tags: [],
        description: {'en': 'Desc'},
        fiveMinuteSummary: {'en': 'S1'},
        fifteenMinuteSummary: {'en': 'S2'},
        chapterSummaries: {},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 200,
        isPremium: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      );

      final user = UserModel(
        id: 'user-123',
        name: 'John',
        email: 'john@example.com',
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
        lastActiveDate: '',
        familyMembers: [],
        createdAt: DateTime.now(),
      );

      mockAuth.currentUser = user;
      await mockDb.addBook(book);

      int triggerCount = 0;
      final subscription = mockAuth.completionCelebrationStream.listen((event) {
        if (event.id == book.id) {
          triggerCount++;
        }
      });

      // Complete the first time
      await mockAuth.addCompletedBook(book.id, source: 'automatic');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(triggerCount, 1);

      // Try completing again
      await mockAuth.addCompletedBook(book.id, source: 'automatic');
      await Future.delayed(const Duration(milliseconds: 50));

      // Trigger count should remain 1 (blocked duplicate)
      expect(triggerCount, 1);

      await subscription.cancel();
    });

    test('Offline manual completion is cached locally and merged correctly (latest timestamp wins)', () async {
      final now = DateTime.now();
      final olderTime = now.subtract(const Duration(hours: 2));
      final newerTime = now.subtract(const Duration(minutes: 10));

      final serverUser = UserModel(
        id: 'user-123',
        name: 'Test User',
        email: 'test@user.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: ['book-1'],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        streakCount: 1,
        lastActiveDate: '',
        familyMembers: [],
        createdAt: now,
        completionDetails: {
          'book-1': {
            'completed': true,
            'source': 'automatic',
            'completedAt': olderTime.toIso8601String(),
          },
          'book-2': {
            'completed': false,
            'completedAt': olderTime.toIso8601String(),
          }
        },
      );

      final localUser = UserModel(
        id: 'user-123',
        name: 'Test User',
        email: 'test@user.com',
        selectedLanguage: 'en',
        interests: [],
        learningGoals: [],
        savedBooks: [],
        completedBooks: ['book-2'],
        likedBooks: [],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        streakCount: 1,
        lastActiveDate: '',
        familyMembers: [],
        createdAt: now,
        completionDetails: {
          'book-1': {
            'completed': true,
            'source': 'automatic',
            'completedAt': olderTime.toIso8601String(),
          },
          'book-2': {
            'completed': true,
            'source': 'manual',
            'completedAt': newerTime.toIso8601String(),
          }
        },
      );

      // Verify that getCachedUser and cacheUser persist UserModel correctly
      await OfflineAvailabilityRepository.cacheUser(localUser);
      final cachedUser = await OfflineAvailabilityRepository.getCachedUser();
      expect(cachedUser, isNotNull);
      expect(cachedUser!.id, 'user-123');
      expect(cachedUser.completionDetails['book-2']['completed'], isTrue);

      // Perform local merging logic block identical to firebase_auth_service.dart
      final mergedDetails = Map<String, dynamic>.from(serverUser.completionDetails);
      bool hasChanges = false;
      
      cachedUser.completionDetails.forEach((bookId, localVal) {
        if (localVal is Map) {
          final serverVal = serverUser.completionDetails[bookId];
          if (serverVal == null) {
            mergedDetails[bookId] = localVal;
            hasChanges = true;
          } else if (serverVal is Map) {
            final localTimeStr = localVal['completedAt'] as String?;
            final serverTimeStr = serverVal['completedAt'] as String?;
            if (localTimeStr != null && serverTimeStr != null) {
              final localTime = DateTime.tryParse(localTimeStr);
              final serverTime = DateTime.tryParse(serverTimeStr);
              if (localTime != null && serverTime != null && localTime.isAfter(serverTime)) {
                mergedDetails[bookId] = localVal;
                hasChanges = true;
              }
            }
          }
        }
      });

      expect(hasChanges, isTrue);
      expect(mergedDetails['book-2']['completed'], isTrue);
      expect(mergedDetails['book-2']['source'], 'manual');
      expect(mergedDetails['book-2']['completedAt'], newerTime.toIso8601String());
    });
  });

  group('BookDetailsScreen Manual Completion widget tests', () {
    testWidgets('Confirmation dialog is shown before manual completion', (WidgetTester tester) async {
      final book = Book(
        id: 'book-456',
        title: {'en': 'Widget Test Summary'},
        author: {'en': 'Test Author'},
        coverImageUrl: 'local:cover.jpg',
        categoryIds: [],
        tags: [],
        description: {'en': 'A widget test description'},
        fiveMinuteSummary: {'en': 'Summary'},
        fifteenMinuteSummary: {'en': 'Summary'},
        chapterSummaries: {},
        keyIdeas: {},
        keyQuotes: {},
        actionPoints: {},
        audioUrl: {},
        duration: 300,
        isPremium: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hiddenLanguages: const [],
      );

      final user = UserModel(
        id: 'user-123',
        name: 'Jane',
        email: 'jane@example.com',
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
        lastActiveDate: '',
        familyMembers: [],
        createdAt: DateTime.now(),
      );

      mockAuth.currentUser = user;
      await mockDb.addBook(book);

      final bookDir = Directory('${tempDir.path}/books/book-456');
      if (!bookDir.existsSync()) {
        bookDir.createSync(recursive: true);
      }
      File('${bookDir.path}/download.complete').writeAsStringSync('done');
      File('${bookDir.path}/summary.partwkbook').writeAsStringSync('dummy_encrypted_summary');
      File('${bookDir.path}/licence.json').writeAsStringSync(jsonEncode({
        'userId': 'user-123',
        'bookId': 'book-456',
        'licenceIssueDate': '2026-06-22T00:00:00Z',
        'licenceExpiryDate': '2027-06-22T00:00:00Z',
        'signature': 'dummy_signature',
      }));
      File('${bookDir.path}/cover.jpg').writeAsBytesSync([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00,
        0x00, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x21, 0xf9, 0x04, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
        0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b
      ]);

      // Build the BookDetailsScreen
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthService>.value(
          value: mockAuth,
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
            ],
            supportedLocales: const [
              Locale('en', ''),
            ],
            home: const BookDetailsScreen(bookId: 'book-456'),
          ),
        ),
      );

      // Wait for async initialization in BookDetailsScreen (_loadBookDetails)
      await tester.runAsync(() async {
        await Future.delayed(const Duration(seconds: 1));
      });
      // Pump multiple times to process the state changes and rebuild
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify the details screen has loaded
      expect(find.text('Widget Test Summary'), findsOneWidget);

      // Find the overflow menu button (Icons.more_vert)
      final moreButton = find.byIcon(Icons.more_vert);
      expect(moreButton, findsOneWidget);

      // Tap to open the popup menu
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      // Find the "Mark as Complete" option
      final markOption = find.text('Mark as Complete');
      expect(markOption, findsOneWidget);

      // Tap on "Mark as Complete"
      await tester.tap(markOption);
      await tester.pumpAndSettle();

      // Verify that the confirmation dialog pops up
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Mark this summary as complete?'), findsOneWidget);

      // Tap Cancel
      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // Verify dialog is closed and book is NOT completed
      expect(find.byType(AlertDialog), findsNothing);
      expect(mockAuth.currentUser!.completedBooks.contains(book.id), isFalse);

      // Open the menu again
      await tester.tap(moreButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Complete'));
      await tester.pumpAndSettle();

      // Tap "Mark Complete" to confirm
      final confirmButton = find.text('Mark Complete');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Verify dialog is dismissed and book completion is triggered
      expect(find.byType(AlertDialog), findsNothing);
      expect(mockAuth.currentUser!.completedBooks.contains(book.id), isTrue);
    });
  });
}
