import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:partwk/core/localization/app_localizations.dart';
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
import 'package:partwk/models/note.dart';
import 'package:partwk/features/library/saved_library_screen.dart';
import 'package:partwk/features/library/downloads_screen.dart';
import 'package:partwk/main.dart' as app;

final Uint8List kTestPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class MockSweepAuthService extends AuthService {
  UserModel? _currentUser;
  @override
  UserModel? get currentUser => _currentUser;
  @override
  bool get isAuthenticated => _currentUser != null;
  @override
  bool get isGuest => false;

  void setUser(UserModel? user) {
    _currentUser = user;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSweepDatabaseService extends MockDatabaseService {
  @override
  Future<List<Book>> fetchBooks() async => books;
  @override
  Future<List<Category>> fetchCategories() async => categories;
  @override
  Future<List<Book>> fetchTrendingBooks(List<Book> allBooks) async => allBooks;
  @override
  Future<List<Note>> fetchNotes(String userId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockSweepAuthService mockAuth;
  late MockSweepDatabaseService mockDb;
  final Map<String, String> secureStorageMemory = {};
  const testSalt = 'mock_test_signing_salt_32_bytes_long!!';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('partwk_sweep_test_');

    mockAuth = MockSweepAuthService();
    mockDb = MockSweepDatabaseService();
    AppLocator.auth = mockAuth;
    AppLocator.db = mockDb;
  });

  setUp(() async {
    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        final key = methodCall.arguments is Map ? methodCall.arguments['key'] as String? : null;
        switch (methodCall.method) {
          case 'read':
            return key != null ? secureStorageMemory[key] : null;
          case 'write':
            final val = methodCall.arguments['value'] as String?;
            if (key != null && val != null) secureStorageMemory[key] = val;
            return null;
          case 'delete':
            if (key != null) secureStorageMemory.remove(key);
            return null;
          case 'deleteAll':
            secureStorageMemory.clear();
            return null;
          case 'readAll':
            return Map<String, String>.from(secureStorageMemory);
          default:
            return null;
        }
      },
    );

    secureStorageMemory.clear();
    secureStorageMemory['licence_signing_salt'] = testSalt;
    SharedPreferences.setMockInitialValues({});
    NetworkGuard.mockConnectionStatus = true;
    await DownloadService.init();
  });

  tearDownAll(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  UserModel createTestUser({
    required String id,
    required String name,
    required String email,
    String subscriptionStatus = 'premium',
    String? subscriptionExpiryDate,
  }) {
    return UserModel(
      id: id,
      name: name,
      email: email,
      selectedLanguage: 'en',
      interests: const ['productivity'],
      learningGoals: const ['15_mins'],
      savedBooks: const [],
      completedBooks: const [],
      likedBooks: const [],
      listeningProgress: const {},
      readingProgress: const {},
      subscriptionStatus: subscriptionStatus,
      subscriptionExpiryDate: subscriptionExpiryDate ?? DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      streakCount: 5,
      lastActiveDate: DateTime.now().toIso8601String(),
      familyMembers: const [],
      createdAt: DateTime.now(),
    );
  }

  Book createTestBook({
    required String id,
    required String titleEn,
    required String titleKu,
    required String titleAr,
  }) {
    return Book(
      id: id,
      title: {'en': titleEn, 'ku': titleKu, 'ar': titleAr},
      author: {'en': 'Author Test', 'ku': 'نووسەری تاقیکردنەوە', 'ar': 'مؤلف تجريبي'},
      coverImageUrl: 'local:cover.jpg',
      categoryIds: ['productivity'],
      tags: ['focus'],
      description: {'en': 'Test book description'},
      fiveMinuteSummary: {'en': '5-min summary text'},
      fifteenMinuteSummary: {'en': '15-min summary text'},
      chapterSummaries: {
        'en': [{'title': 'Ch 1', 'audioUrl': 'local:audio_0', 'duration': 300, 'content': 'Full chapter text content'}],
        'ku': [{'title': 'بەشی ١', 'audioUrl': 'local:audio_0', 'duration': 300, 'content': 'دەقی پوختەی بەش'}],
      },
      keyIdeas: {'en': ['Idea 1']},
      keyQuotes: {'en': ['Quote 1']},
      actionPoints: {'en': ['Action 1']},
      duration: 300,
      audioUrl: {'en': 'local:audio_0'},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      hiddenLanguages: const [],
      isPremium: true,
    );
  }

  String calculateSignature(String userId, String bookId, String languageCode, String downloadDate, String expiryDate, String planId, int version) {
    final payload = '$userId|$bookId|$languageCode|$downloadDate|$expiryDate|$planId|$version';
    final keyBytes = utf8.encode(testSalt);
    final hmac = Hmac(sha256, keyBytes);
    return hmac.convert(utf8.encode(payload)).toString();
  }

  Future<void> setupEditionFixture({
    required String userId,
    required Book book,
    required String languageCode,
    required bool isExpired,
    Duration? timeDelta,
  }) async {
    final editionDir = Directory('${tempDir.path}/users/$userId/books/${book.id}/$languageCode');
    editionDir.createSync(recursive: true);

    // Encrypted text file
    final summaryFile = File('${editionDir.path}/summary.partwkbook');
    summaryFile.writeAsBytesSync(utf8.encode('EncryptedCiphertextBytesMock123456'));

    // Audio file
    final audioFile = File('${editionDir.path}/audio_0.partwkaudio');
    audioFile.writeAsBytesSync(utf8.encode('EncryptedAudioMockData'));

    // Cover file
    final coverFile = File('${editionDir.path}/cover.jpg');
    coverFile.writeAsBytesSync(kTestPng);

    // Download complete marker
    final completeFile = File('${editionDir.path}/download.complete');
    completeFile.createSync();

    // Secure Storage Encryption Key
    final keyAlias = EncryptedContentStorage.getKeyAlias(userId, book.id, languageCode);
    secureStorageMemory[keyAlias] = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    // Licence file
    final now = DateTime.now();
    final downloadDate = now.subtract(const Duration(days: 8)).toIso8601String();
    final expiryDate = isExpired
        ? now.subtract(timeDelta ?? const Duration(days: 1)).toIso8601String()
        : now.add(timeDelta ?? const Duration(days: 5)).toIso8601String();

    final sig = calculateSignature(userId, book.id, languageCode, downloadDate, expiryDate, 'premium_yearly', 1);

    final licence = BookLicence(
      userId: userId,
      bookId: book.id,
      languageCode: languageCode,
      downloadDate: downloadDate,
      licenceExpiryDate: expiryDate,
      premiumPlanId: 'premium_yearly',
      contentVersion: 1,
      signature: sig,
    );

    final licenceFile = File('${editionDir.path}/licence.json');
    licenceFile.writeAsStringSync(jsonEncode(licence.toMap()));

    // Cache edition metadata
    await OfflineAvailabilityRepository.cacheEditionMetadata(book, languageCode, userId: userId);
  }

  Widget wrapWithApp({required Widget child, Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: mockAuth),
      ],
      child: MaterialApp(
        theme: ThemeData.light(),
        locale: locale,
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
        home: child,
      ),
    );
  }

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (int i = 0; i < 50; i++) {
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    await tester.pumpAndSettle();
  }

  group('Download-Expiry Local Cleanup Sweep Verification', () {
    testWidgets('1. Expired edition is automatically removed merely by opening SavedLibraryScreen Downloaded tab (without tapping card)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final user = createTestUser(id: 'user_sweep_1', name: 'User One', email: 'user1@partwk.com');
      mockAuth.setUser(user);

      final expiredBook = createTestBook(id: 'book_exp_1', titleEn: 'Expired Masterclass', titleKu: 'ماستەرکلاسی بەسەرچوو', titleAr: 'درس منتهي');

      await setupEditionFixture(
        userId: user.id,
        book: expiredBook,
        languageCode: 'en',
        isExpired: true,
      );

      // Verify fixture exists before screen opens
      final bookDir = Directory('${tempDir.path}/users/${user.id}/books/${expiredBook.id}/en');
      expect(bookDir.existsSync(), isTrue);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(user.id, expiredBook.id, 'en')), isTrue);
      final preCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(preCached.length, equals(1));

      // Open SavedLibraryScreen with Downloaded Books tab selected (initialIndex: 4)
      await tester.pumpWidget(wrapWithApp(child: const Scaffold(body: SavedLibraryScreen(initialIndex: 4))));
      await pumpUntilLoaded(tester);

      // 1. Expired book must NOT appear in the UI list
      expect(find.text('Expired Masterclass'), findsNothing);

      // 2. Quota must immediately reflect 0 / 3 downloads used
      expect(find.text('0 / 3 downloads used'), findsOneWidget);

      // 3. Complete canonical cleanup: package files, encryption key, licence, and metadata must be gone
      expect(bookDir.existsSync(), isFalse);
      expect(File('${tempDir.path}/users/${user.id}/books/${expiredBook.id}/en/summary.partwkbook').existsSync(), isFalse);
      expect(File('${tempDir.path}/users/${user.id}/books/${expiredBook.id}/en/licence.json').existsSync(), isFalse);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(user.id, expiredBook.id, 'en')), isFalse);

      final postCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(postCached.isEmpty, isTrue);
    });

    testWidgets('2. Expired edition removed merely by opening DownloadsScreen, quota updates (3/3 -> 2/3), slot freed immediately', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final user = createTestUser(id: 'user_sweep_2', name: 'User Two', email: 'user2@partwk.com');
      mockAuth.setUser(user);

      final validBook1 = createTestBook(id: 'book_val_1', titleEn: 'Valid Book 1', titleKu: 'کتێبی دروست ١', titleAr: 'كتاب صالح ١');
      final validBook2 = createTestBook(id: 'book_val_2', titleEn: 'Valid Book 2', titleKu: 'کتێبی دروست ٢', titleAr: 'كتاب صالح ٢');
      final expiredBook3 = createTestBook(id: 'book_exp_3', titleEn: 'Expired Book 3', titleKu: 'کتێبی بەسەرچوو ٣', titleAr: 'كتاب منتهي ٣');

      await setupEditionFixture(userId: user.id, book: validBook1, languageCode: 'en', isExpired: false);
      await setupEditionFixture(userId: user.id, book: validBook2, languageCode: 'en', isExpired: false);
      await setupEditionFixture(userId: user.id, book: expiredBook3, languageCode: 'en', isExpired: true);

      // Pre-screen verification: 3 editions cached
      final preCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(preCached.length, equals(3));

      // Open DownloadsScreen
      await tester.pumpWidget(wrapWithApp(child: const DownloadsScreen()));
      await pumpUntilLoaded(tester);

      // Expired book is gone from UI; valid books remain visible
      expect(find.text('Expired Book 3'), findsNothing);
      expect(find.text('Valid Book 1'), findsOneWidget);
      expect(find.text('Valid Book 2'), findsOneWidget);

      // Quota immediately drops from 3 / 3 to 2 / 3 downloads used
      expect(find.text('2 / 3 downloads used'), findsOneWidget);

      // Package directory, key, licence, and metadata of expired book are completely gone
      final expiredDir = Directory('${tempDir.path}/users/${user.id}/books/${expiredBook3.id}/en');
      expect(expiredDir.existsSync(), isFalse);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(user.id, expiredBook3.id, 'en')), isFalse);

      final postCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(postCached.length, equals(2));
      expect(postCached.any((e) => e.bookId == expiredBook3.id), isFalse);

      // Freed slot is immediately usable by a new download without hitting limit
      final validBook4 = createTestBook(id: 'book_new_4', titleEn: 'New Book 4', titleKu: 'کتێبی ٤', titleAr: 'كتاب ٤');
      expect(
        () async => await DownloadManager().downloadBook(validBook4, 'en', (_) {}),
        returnsNormally,
      );
    });

    testWidgets('3. Still-valid edition survives opening either screen while airplane mode / network failure is simulated', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final user = createTestUser(id: 'user_offline_3', name: 'Offline User', email: 'offline@partwk.com');
      mockAuth.setUser(user);

      final validBook = createTestBook(id: 'book_offline_val', titleEn: 'Resilient Offline Guide', titleKu: 'ڕێبەری ئۆفلاین', titleAr: 'دليل بلا اتصال');
      await setupEditionFixture(userId: user.id, book: validBook, languageCode: 'en', isExpired: false);

      // Simulate airplane mode / network failure
      NetworkGuard.mockConnectionStatus = false;

      // 1. Open SavedLibraryScreen Downloaded Books tab
      await tester.pumpWidget(wrapWithApp(child: const Scaffold(body: SavedLibraryScreen(initialIndex: 4))));
      await pumpUntilLoaded(tester);

      expect(find.text('Resilient Offline Guide'), findsOneWidget);
      expect(find.text('1 / 3 downloads used'), findsOneWidget);

      // 2. Open DownloadsScreen
      await tester.pumpWidget(wrapWithApp(child: const DownloadsScreen()));
      await pumpUntilLoaded(tester);

      expect(find.text('Resilient Offline Guide'), findsOneWidget);
      expect(find.text('1 / 3 downloads used'), findsOneWidget);

      // Verify files, key, licence, and metadata survive completely intact
      final bookDir = Directory('${tempDir.path}/users/${user.id}/books/${validBook.id}/en');
      expect(bookDir.existsSync(), isTrue);
      expect(File('${bookDir.path}/summary.partwkbook').existsSync(), isTrue);
      expect(File('${bookDir.path}/licence.json').existsSync(), isTrue);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(user.id, validBook.id, 'en')), isTrue);
      final cached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(cached.length, equals(1));
      expect(cached.first.bookId, equals(validBook.id));
    });

    testWidgets('4. Language-edition isolation: same book EN valid + KU expired, only KU is removed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final user = createTestUser(id: 'user_lang_iso_4', name: 'Polyglot User', email: 'polyglot@partwk.com');
      mockAuth.setUser(user);

      final bilingualBook = createTestBook(id: 'book_polyglot', titleEn: 'Atomic Habits', titleKu: 'خووە ئەتۆمییەکان', titleAr: 'العادات الذرية');

      // EN edition is still valid
      await setupEditionFixture(userId: user.id, book: bilingualBook, languageCode: 'en', isExpired: false);
      // KU edition of the SAME book is expired
      await setupEditionFixture(userId: user.id, book: bilingualBook, languageCode: 'ku', isExpired: true);

      final enDir = Directory('${tempDir.path}/users/${user.id}/books/${bilingualBook.id}/en');
      final kuDir = Directory('${tempDir.path}/users/${user.id}/books/${bilingualBook.id}/ku');
      expect(enDir.existsSync(), isTrue);
      expect(kuDir.existsSync(), isTrue);

      final preCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(preCached.length, equals(2));

      // Open DownloadsScreen
      await tester.pumpWidget(wrapWithApp(child: const DownloadsScreen()));
      await pumpUntilLoaded(tester);

      // KU edition package directory, licence, key, and metadata must be gone
      expect(kuDir.existsSync(), isFalse);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(user.id, bilingualBook.id, 'ku')), isFalse);

      // EN edition package directory, licence, key, and metadata must remain completely intact
      expect(enDir.existsSync(), isTrue);
      expect(File('${enDir.path}/summary.partwkbook').existsSync(), isTrue);
      expect(File('${enDir.path}/licence.json').existsSync(), isTrue);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(user.id, bilingualBook.id, 'en')), isTrue);

      final postCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
      expect(postCached.length, equals(1));
      expect(postCached.first.languageCode, equals('en'));

      // Quota reflects 1 / 3 downloads used
      expect(find.text('1 / 3 downloads used'), findsOneWidget);
    });

    testWidgets('5. Account isolation: another account opening the screen cannot trigger cleanup of the first account’s editions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final userA = createTestUser(id: 'user_alice_5', name: 'Alice', email: 'alice@partwk.com');
      final userB = createTestUser(id: 'user_bob_5', name: 'Bob', email: 'bob@partwk.com');

      // User A has an expired edition
      final bookA = createTestBook(id: 'book_alice', titleEn: 'Alice Expired Book', titleKu: 'کتێبی ئەلیس', titleAr: 'كتاب أليس');
      await setupEditionFixture(userId: userA.id, book: bookA, languageCode: 'en', isExpired: true);

      final aliceDir = Directory('${tempDir.path}/users/${userA.id}/books/${bookA.id}/en');
      expect(aliceDir.existsSync(), isTrue);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(userA.id, bookA.id, 'en')), isTrue);

      // Switch signed-in user to User B
      mockAuth.setUser(userB);

      // User B opens DownloadsScreen
      await tester.pumpWidget(wrapWithApp(child: const DownloadsScreen()));
      await pumpUntilLoaded(tester);

      // User B sees empty state
      expect(find.text('0 / 3 downloads used'), findsOneWidget);

      // User A's files, keys, licence, and metadata MUST NOT be touched or cleaned by User B's session!
      expect(aliceDir.existsSync(), isTrue);
      expect(File('${aliceDir.path}/licence.json').existsSync(), isTrue);
      expect(secureStorageMemory.containsKey(EncryptedContentStorage.getKeyAlias(userA.id, bookA.id, 'en')), isTrue);
      final aliceCached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: userA.id);
      expect(aliceCached.length, equals(1));
    });

    test('6. Concurrent sweep deduplication: simultaneous calls return deduplicated result without race conditions', () async {
      final user = createTestUser(id: 'user_race_6', name: 'Race Tester', email: 'race@partwk.com');
      mockAuth.setUser(user);

      final validBook = createTestBook(id: 'book_race_val', titleEn: 'Race Book', titleKu: 'کتێبی پێشبڕکێ', titleAr: 'كتاب السباق');
      await setupEditionFixture(userId: user.id, book: validBook, languageCode: 'en', isExpired: false);

      // Trigger two simultaneous sweep requests
      final future1 = DownloadService().getDownloadedEditions();
      final future2 = DownloadService().getDownloadedEditions();

      final results = await Future.wait([future1, future2]);
      expect(results[0].length, equals(1));
      expect(results[1].length, equals(1));
      expect(results[0].first.bookId, equals('book_race_val'));
      expect(results[1].first.bookId, equals('book_race_val'));
    });
  });
}
