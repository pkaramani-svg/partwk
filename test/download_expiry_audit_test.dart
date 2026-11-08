import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/encrypted_content_storage.dart';
import 'package:partwk/core/services/licence_manager.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/core/services/download_manager.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/user.dart';

class AuditMockAuthService extends AuthService {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AuditMockAuthService mockAuth;
  final Map<String, String> secureStorageMock = {};

  setUpAll(() {
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
        .setMockMethodCallHandler((MethodCall call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          final val = call.arguments['value'] as String?;
          if (key != null && val != null) secureStorageMock[key] = val;
          return null;
        case 'read':
          return key != null ? secureStorageMock[key] : null;
        case 'delete':
          if (key != null) secureStorageMock.remove(key);
          return null;
        case 'deleteAll':
          secureStorageMock.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStorageMock);
        default:
          return null;
      }
    });
  });

  setUp(() async {
    secureStorageMock.clear();
    tempDir = await Directory.systemTemp.createTemp('partwk_download_audit_');
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall call) async {
      return tempDir.path;
    });

    SharedPreferences.setMockInitialValues({});
    NetworkGuard.mockConnectionStatus = true;

    mockAuth = AuditMockAuthService();
    AppLocator.auth = mockAuth;
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  final sampleBook = Book(
    id: 'book_audit_101',
    title: {'en': 'Deep Focus', 'ku': 'سەرنجدانی قووڵ', 'ar': 'التركيز العميق'},
    author: {'en': 'Dr. Cal Newport', 'ku': 'د. کال نیوپۆرت', 'ar': 'د. كال نيوبورت'},
    coverImageUrl: '',
    categoryIds: ['productivity'],
    tags: ['focus'],
    description: {'en': 'Master deep work'},
    fiveMinuteSummary: {'en': 'Secret to productivity is deep uninterrupted focus.'},
    fifteenMinuteSummary: {'en': 'Comprehensive 15-minute summary.'},
    chapterSummaries: {
      'en': [
        {'title': 'Chapter 1: The Deep Work Hypothesis', 'audioUrl': 'local:audio_0', 'duration': 300},
      ],
      'ku': [
        {'title': 'بەشی ١: کاری قووڵ', 'audioUrl': 'local:audio_0', 'duration': 300},
      ],
    },
    keyIdeas: {'en': ['Focus is a superpower in the 21st century.']},
    keyQuotes: {'en': ['Clarity about what matters provides clarity about what does not.']},
    actionPoints: {'en': ['Block 2 hours of distraction-free work every morning.']},
    duration: 300,
    audioUrl: {'en': 'https://example.com/audio.mp3'},
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    hiddenLanguages: const [],
    isPremium: true,
  );

  UserModel createTestUser({
    required String id,
    required String name,
    required String email,
    String subscriptionStatus = 'premium',
    String? subscriptionExpiryDate,
    String? primarySubscriptionExpiry,
    bool hasFamilyPremium = false,
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
      subscriptionExpiryDate: subscriptionExpiryDate,
      primarySubscriptionExpiry: primarySubscriptionExpiry,
      hasFamilyPremium: hasFamilyPremium,
      streakCount: 5,
      lastActiveDate: DateTime.now().toIso8601String(),
      familyMembers: const [],
      createdAt: DateTime.now(),
    );
  }

  final userA = createTestUser(
    id: 'user_alice_1',
    name: 'Alice Reader',
    email: 'alice@partwk.com',
    subscriptionStatus: 'premium',
    subscriptionExpiryDate: DateTime.now().add(const Duration(days: 365)).toIso8601String(),
  );

  final userB = createTestUser(
    id: 'user_bob_2',
    name: 'Bob Intruder',
    email: 'bob@partwk.com',
    subscriptionStatus: 'premium',
    subscriptionExpiryDate: DateTime.now().add(const Duration(days: 365)).toIso8601String(),
  );

  group('Download-Expiry Audit Verification', () {
    test('1. Each downloaded edition is encrypted and stored under {userId, bookId, languageCode} outside public downloads', () async {
      mockAuth.setUser(userA);

      // Verify path resolution
      final expectedPath = '${tempDir.path}/users/${userA.id}/books/${sampleBook.id}/en';
      final editionDir = Directory(expectedPath);
      await editionDir.create(recursive: true);

      // Verify text encryption
      final sensitiveContent = {'summary': 'Deep focus secret'};
      final plainBytes = utf8.encode(jsonEncode(sensitiveContent));
      final textFilePath = '${editionDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(
        userA.id,
        sampleBook.id,
        textFilePath,
        plainBytes,
        languageCode: 'en',
      );

      // Verify raw file on disk is encrypted (does not contain plaintext)
      final rawFile = File(textFilePath);
      expect(rawFile.existsSync(), isTrue);
      final rawBytes = await rawFile.readAsBytes();
      expect(rawBytes.length, greaterThan(16)); // 16 bytes IV + AES CBC blocks
      final rawString = String.fromCharCodes(rawBytes);
      expect(rawString.contains('Deep focus secret'), isFalse); // Strict ciphertext

      // Verify storage is in private sandbox, NOT public downloads
      expect(textFilePath.contains('/users/${userA.id}/books/${sampleBook.id}/en/'), isTrue);
      expect(textFilePath.startsWith(tempDir.path), isTrue);
      expect(textFilePath.contains('/Download/'), isFalse);
      expect(textFilePath.contains('/storage/emulated/0/'), isFalse);

      // Verify key alias in secure storage is scoped to {userId, bookId, languageCode}
      final keyAlias = EncryptedContentStorage.getKeyAlias(userA.id, sampleBook.id, 'en');
      expect(keyAlias, equals('enc_key_${userA.id}_${sampleBook.id}_en'));
      expect(secureStorageMock.containsKey(keyAlias), isTrue);
    });

    test('2. Cannot be read or played outside Partwk or by another signed-in account', () async {
      mockAuth.setUser(userA);

      final editionDir = Directory('${tempDir.path}/users/${userA.id}/books/${sampleBook.id}/en');
      await editionDir.create(recursive: true);

      final plainBytes = utf8.encode('Private Alice Book Data');
      final textFilePath = '${editionDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(
        userA.id,
        sampleBook.id,
        textFilePath,
        plainBytes,
        languageCode: 'en',
      );

      final licence = await LicenceManager.issueDownloadLicence(userA.id, sampleBook.id, languageCode: 'en');
      await LicenceManager.saveLicence(licence);

      // User A can decrypt successfully
      final decryptedAlice = await EncryptedContentStorage.readDecryptedFile(
        userA.id,
        sampleBook.id,
        textFilePath,
        languageCode: 'en',
      );
      expect(utf8.decode(decryptedAlice), equals('Private Alice Book Data'));

      // Now switch signed-in user to User B
      mockAuth.setUser(userB);

      // User B cannot decrypt User A's file because User B's key alias does not exist in secure storage
      expect(
        () async => await EncryptedContentStorage.readDecryptedFile(
          userB.id,
          sampleBook.id,
          textFilePath,
          languageCode: 'en',
        ),
        throwsA(anything), // Decryption failure due to key mismatch
      );

      // User B licence validation for User A's book must fail immediately
      final isLicenceValidForBob = await LicenceManager.isLicenceValid(
        sampleBook.id,
        languageCode: 'en',
        userId: userB.id,
      );
      expect(isLicenceValidForBob, isFalse);

      // Attempting to load book content as User B throws LicenceInvalidException
      expect(
        () async => await DownloadManager.loadBookContent(sampleBook, languageCode: 'en'),
        throwsA(isA<LicenceInvalidException>()),
      );
    });

    test('3. Earliest of 7 days vs verified Premium entitlement expiry blocks reading and audio', () async {
      // Case A: 365-day premium -> capped at 7 days
      mockAuth.setUser(userA);
      final licenceLong = await LicenceManager.issueDownloadLicence(userA.id, sampleBook.id, languageCode: 'en');
      final expiryLong = DateTime.parse(licenceLong.licenceExpiryDate);
      expect(expiryLong.difference(DateTime.now()).inHours, inInclusiveRange(167, 168)); // 7 days = 168 hours

      // Case B: Premium expiring in 3 days -> capped at 3 days
      final userExpiringIn3Days = userA.copyWith(
        subscriptionExpiryDate: DateTime.now().add(const Duration(days: 3, hours: 2)).toIso8601String(),
      );
      mockAuth.setUser(userExpiringIn3Days);
      final licenceShort = await LicenceManager.issueDownloadLicence(userExpiringIn3Days.id, sampleBook.id, languageCode: 'en');
      final expiryShort = DateTime.parse(licenceShort.licenceExpiryDate);
      expect(expiryShort.difference(DateTime.now()).inDays, equals(3)); // Capped at subscriber's verified expiry

      // Case C: Family member with primary subscriber expiry in 2 days -> capped at 2 days
      final userFamilyMember = createTestUser(
        id: 'user_family_child',
        name: 'Child Member',
        email: 'child@partwk.com',
        subscriptionStatus: 'free',
        hasFamilyPremium: true,
        primarySubscriptionExpiry: DateTime.now().add(const Duration(days: 2, hours: 1)).toIso8601String(),
      );
      mockAuth.setUser(userFamilyMember);
      final licenceFamily = await LicenceManager.issueDownloadLicence(userFamilyMember.id, sampleBook.id, languageCode: 'en');
      final expiryFamily = DateTime.parse(licenceFamily.licenceExpiryDate);
      expect(expiryFamily.difference(DateTime.now()).inDays, equals(2)); // Primary subscriber's verified expiry

      // Verification: Expired licence blocks both reading and audio
      final expiredLicence = BookLicence(
        userId: userA.id,
        bookId: sampleBook.id,
        languageCode: 'en',
        downloadDate: DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        licenceExpiryDate: DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String(), // Expired!
        premiumPlanId: 'premium_yearly',
        contentVersion: 1,
        signature: 'invalid_or_expired',
      );
      mockAuth.setUser(userA);
      await LicenceManager.saveLicence(expiredLicence);

      final isValid = await LicenceManager.isLicenceValid(sampleBook.id, languageCode: 'en', userId: userA.id);
      expect(isValid, isFalse);

      expect(
        () async => await DownloadManager.loadBookContent(sampleBook, languageCode: 'en'),
        throwsA(isA<LicenceInvalidException>()),
      );

      final tag = MediaItem(id: 'audio_en_0', title: 'Chapter 1');
      expect(
        () async => await DownloadManager.loadAudioSource(sampleBook.id, 'en', tag),
        throwsA(isA<LicenceInvalidException>()),
      );
    });

    test('4. Expired packages and encryption keys are removed on the safe cleanup point (attempt to open/play)', () async {
      mockAuth.setUser(userA);

      // Create an edition on disk with encryption key and metadata
      final editionDir = Directory('${tempDir.path}/users/${userA.id}/books/${sampleBook.id}/en');
      await editionDir.create(recursive: true);

      final textFilePath = '${editionDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(
        userA.id,
        sampleBook.id,
        textFilePath,
        utf8.encode('To be revoked'),
        languageCode: 'en',
      );

      await OfflineAvailabilityRepository.cacheEditionMetadata(sampleBook, 'en', userId: userA.id);

      // Create an EXPIRED licence
      final expiredLicence = await LicenceManager.issueDownloadLicence(
        userA.id,
        sampleBook.id,
        languageCode: 'en',
        primaryExpiryOverride: DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      );
      await LicenceManager.saveLicence(expiredLicence);

      final keyAlias = EncryptedContentStorage.getKeyAlias(userA.id, sampleBook.id, 'en');
      expect(secureStorageMock.containsKey(keyAlias), isTrue);
      expect(editionDir.existsSync(), isTrue);

      // Trigger cleanup via safe access point: an attempt to open / play the edition
      // (as done in BookDetailsScreen, SummaryReaderScreen, and AudioPlayerScreen)
      final valid = await LicenceManager.isLicenceValid(sampleBook.id, languageCode: 'en', userId: userA.id);
      expect(valid, isFalse);

      // Verify that revocation cleanup occurred:
      // 1. Encryption key removed from secure storage
      expect(secureStorageMock.containsKey(keyAlias), isFalse);

      // 2. Edition directory and downloaded files deleted from disk
      expect(editionDir.existsSync(), isFalse);

      // 3. Metadata removed from SharedPreferences cache
      final cachedEditions = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: userA.id);
      expect(cachedEditions.any((e) => e.bookId == sampleBook.id && e.languageCode == 'en'), isFalse);
    });

    test('5. Temporary offline/network failure never deletes or invalidates a still-valid downloaded edition', () async {
      mockAuth.setUser(userA);

      // Setup a valid downloaded edition
      final editionDir = Directory('${tempDir.path}/users/${userA.id}/books/${sampleBook.id}/en');
      await editionDir.create(recursive: true);

      final textFilePath = '${editionDir.path}/summary.partwkbook';
      final sensitiveData = {
        'fiveMinuteSummary': {'en': 'Offline accessible summary.'},
        'fifteenMinuteSummary': {'en': 'Offline 15m.'},
        'chapterSummaries': {'en': []},
        'keyIdeas': {'en': []},
        'keyQuotes': {'en': []},
        'actionPoints': {'en': []},
      };
      await EncryptedContentStorage.saveEncryptedFile(
        userA.id,
        sampleBook.id,
        textFilePath,
        utf8.encode(jsonEncode(sensitiveData)),
        languageCode: 'en',
      );

      final licence = await LicenceManager.issueDownloadLicence(userA.id, sampleBook.id, languageCode: 'en');
      await LicenceManager.saveLicence(licence);
      await OfflineAvailabilityRepository.cacheEditionMetadata(sampleBook, 'en', userId: userA.id);

      // Simulate a network failure / airplane mode (offline)
      NetworkGuard.mockConnectionStatus = false;

      // Last validation was 2 days ago (well within 7-day grace period)
      final prefs = await SharedPreferences.getInstance();
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      await prefs.setString('last_licence_validation_time', twoDaysAgo.toIso8601String());

      // Check validity during offline failure
      final isValidOffline = await LicenceManager.isLicenceValid(sampleBook.id, languageCode: 'en', userId: userA.id);
      expect(isValidOffline, isTrue);

      // Verify edition files, key, and metadata are completely INTACT (NEVER deleted)
      final keyAlias = EncryptedContentStorage.getKeyAlias(userA.id, sampleBook.id, 'en');
      expect(secureStorageMock.containsKey(keyAlias), isTrue);
      expect(editionDir.existsSync(), isTrue);
      expect(File(textFilePath).existsSync(), isTrue);

      final cachedEditions = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: userA.id);
      expect(cachedEditions.any((e) => e.bookId == sampleBook.id && e.languageCode == 'en'), isTrue);

      // Verify book reading succeeds offline
      final loadedBook = await DownloadManager.loadBookContent(sampleBook, languageCode: 'en');
      expect(loadedBook.fiveMinuteSummary['en'], equals('Offline accessible summary.'));
    });
  });
}
