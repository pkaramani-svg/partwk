import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/service_locator.dart';
import 'encrypted_content_storage.dart';
import 'offline_availability_repository.dart';
import 'network_guard.dart';

class BookLicence {
  final String userId;
  final String bookId;
  final String languageCode;
  final String downloadDate;
  final String licenceExpiryDate;
  final String premiumPlanId;
  final int contentVersion;
  final String signature;

  BookLicence({
    required this.userId,
    required this.bookId,
    this.languageCode = 'en',
    required this.downloadDate,
    required this.licenceExpiryDate,
    required this.premiumPlanId,
    required this.contentVersion,
    required this.signature,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'bookId': bookId,
        'languageCode': languageCode,
        'downloadDate': downloadDate,
        'licenceExpiryDate': licenceExpiryDate,
        'premiumPlanId': premiumPlanId,
        'contentVersion': contentVersion,
        'signature': signature,
      };

  factory BookLicence.fromMap(Map<String, dynamic> map) {
    return BookLicence(
      userId: map['userId'] ?? '',
      bookId: map['bookId'] ?? '',
      languageCode: map['languageCode'] ?? 'en',
      downloadDate: map['downloadDate'] ?? '',
      licenceExpiryDate: map['licenceExpiryDate'] ?? '',
      premiumPlanId: map['premiumPlanId'] ?? '',
      contentVersion: map['contentVersion'] ?? 1,
      signature: map['signature'] ?? '',
    );
  }
}

class LicenceManager {
  static const _secureStorage = FlutterSecureStorage();
  static const _offlineGracePeriodDays = 7;
  static const _lastValidationKey = 'last_licence_validation_time';

  static Future<String> _getOrCreateSigningSalt() async {
    const saltKey = 'licence_signing_salt';
    String? salt = await _secureStorage.read(key: saltKey);
    if (salt == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (i) => random.nextInt(256));
      salt = base64Encode(bytes);
      await _secureStorage.write(key: saltKey, value: salt);
    }
    return salt;
  }

  static String _calculateSignature(
    String userId,
    String bookId,
    String languageCode,
    String downloadDate,
    String licenceExpiryDate,
    String premiumPlanId,
    int contentVersion,
    String salt,
  ) {
    final payload = '$userId|$bookId|$languageCode|$downloadDate|$licenceExpiryDate|$premiumPlanId|$contentVersion';
    final keyBytes = utf8.encode(salt);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  static String _calculateLegacySignature(
    String userId,
    String bookId,
    String downloadDate,
    String licenceExpiryDate,
    String premiumPlanId,
    int contentVersion,
    String salt,
  ) {
    final payload = '$userId|$bookId|$downloadDate|$licenceExpiryDate|$premiumPlanId|$contentVersion';
    final keyBytes = utf8.encode(salt);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  // --- Backend APIs (Mocked/Exposed for DRM flow) ---

  static Future<Map<String, dynamic>> checkEntitlement(String userId) async {
    final user = AppLocator.auth.currentUser;
    if (user != null && user.id == userId) {
      return {
        'userId': userId,
        'isPremium': user.isPremium,
        'subscriptionStatus': user.subscriptionStatus,
      };
    }
    return {
      'userId': userId,
      'isPremium': false,
      'subscriptionStatus': 'free',
    };
  }

  static Future<BookLicence> issueDownloadLicence(
    String userId,
    String bookId, {
    String languageCode = 'en',
    String? primaryExpiryOverride,
  }) async {
    final salt = await _getOrCreateSigningSalt();
    final downloadDate = DateTime.now().toIso8601String();

    // A downloaded licence expires at the earliest of:
    // 1. 7 days after download/refresh
    // 2. The primary subscriber's verified subscription expiry
    var licenceExpiry = DateTime.now().add(const Duration(days: _offlineGracePeriodDays));

    final user = AppLocator.auth.currentUser;
    String? entitlementExpiry = primaryExpiryOverride ?? user?.effectiveSubscriptionExpiry;

    if (entitlementExpiry == null && user != null) {
      final prefs = await SharedPreferences.getInstance();
      entitlementExpiry = prefs.getString('cached_entitlement_expiry_${user.id}');
    }

    if (entitlementExpiry != null && entitlementExpiry.isNotEmpty) {
      final parsed = DateTime.tryParse(entitlementExpiry);
      if (parsed != null && parsed.isBefore(licenceExpiry)) {
        licenceExpiry = parsed;
      }
    }
    final licenceExpiryDate = licenceExpiry.toIso8601String();
    const premiumPlanId = 'premium_yearly';
    const contentVersion = 1;

    final signature = _calculateSignature(
      userId,
      bookId,
      languageCode,
      downloadDate,
      licenceExpiryDate,
      premiumPlanId,
      contentVersion,
      salt,
    );

    await recordOnlineValidation();

    return BookLicence(
      userId: userId,
      bookId: bookId,
      languageCode: languageCode,
      downloadDate: downloadDate,
      licenceExpiryDate: licenceExpiryDate,
      premiumPlanId: premiumPlanId,
      contentVersion: contentVersion,
      signature: signature,
    );
  }

  static Future<bool> validateDownloadLicence(
      String userId, String bookId, String licenceToken,
      {String languageCode = 'en'}) async {
    final salt = await _getOrCreateSigningSalt();
    try {
      final map = jsonDecode(utf8.decode(base64Decode(licenceToken)));
      final licence = BookLicence.fromMap(map);
      
      final expectedSig = _calculateSignature(
        licence.userId,
        licence.bookId,
        licence.languageCode,
        licence.downloadDate,
        licence.licenceExpiryDate,
        licence.premiumPlanId,
        licence.contentVersion,
        salt,
      );

      final legacySig = _calculateLegacySignature(
        licence.userId,
        licence.bookId,
        licence.downloadDate,
        licence.licenceExpiryDate,
        licence.premiumPlanId,
        licence.contentVersion,
        salt,
      );
      
      return licence.userId == userId &&
          licence.bookId == bookId &&
          (licence.signature == expectedSig || licence.signature == legacySig) &&
          DateTime.parse(licence.licenceExpiryDate).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static Future<void> revokeDownloadedContent(
      String userId, String bookId, {String? languageCode}) async {
    final dir = await getApplicationDocumentsDirectory();

    if (languageCode != null && languageCode.isNotEmpty) {
      // 1. Delete edition decryption key
      await EncryptedContentStorage.deleteDecryptionKey(userId, bookId, languageCode: languageCode);

      // 2. Delete edition directory
      final editionDir = Directory('${dir.path}/users/$userId/books/$bookId/$languageCode');
      if (await editionDir.exists()) {
        await editionDir.delete(recursive: true);
      }

      // Also clean up legacy edition directory if it exists
      final legacyLangDir = Directory('${dir.path}/books/$bookId/$languageCode');
      if (await legacyLangDir.exists()) {
        await legacyLangDir.delete(recursive: true);
      }
      final legacyBookDir = Directory('${dir.path}/books/$bookId');
      if (await legacyBookDir.exists()) {
        try {
          final entries = legacyBookDir.listSync();
          final hasOtherDirs = entries.any((e) => e is Directory);
          if (!hasOtherDirs) {
            await legacyBookDir.delete(recursive: true);
          }
        } catch (_) {}
      }

      // Explicitly delete licence file
      await deleteLicence(bookId, languageCode: languageCode, userId: userId);

      // 3. Remove edition metadata
      await OfflineAvailabilityRepository.removeEditionMetadata(bookId, languageCode, userId: userId);

      // 4. If parent folder has no other editions, clean it up
      final parentDir = Directory('${dir.path}/users/$userId/books/$bookId');
      if (await parentDir.exists()) {
        try {
          final entries = parentDir.listSync();
          final hasOtherDirs = entries.any((e) => e is Directory);
          if (!hasOtherDirs) {
            await parentDir.delete(recursive: true);
            await OfflineAvailabilityRepository.removeBookMetadata(bookId, userId: userId);
          }
        } catch (_) {}
      }
      return;
    }

    // Full book revocation (all editions)
    await EncryptedContentStorage.deleteDecryptionKey(userId, bookId);
    final userBookDir = Directory('${dir.path}/users/$userId/books/$bookId');
    if (await userBookDir.exists()) {
      await userBookDir.delete(recursive: true);
    }
    final legacyBookDir = Directory('${dir.path}/books/$bookId');
    if (await legacyBookDir.exists()) {
      await legacyBookDir.delete(recursive: true);
    }
    await OfflineAvailabilityRepository.removeBookMetadata(bookId, userId: userId);
  }

  static Future<void> revokeAllDownloadedContentForUser(String userId) async {
    final dir = await getApplicationDocumentsDirectory();
    final userBooksDir = Directory('${dir.path}/users/$userId/books');
    if (await userBooksDir.exists()) {
      try {
        final entries = userBooksDir.listSync();
        for (final entry in entries) {
          if (entry is Directory) {
            final bookId = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
            await revokeDownloadedContent(userId, bookId);
          }
        }
        await userBooksDir.delete(recursive: true);
      } catch (e) {
        // Continue cleanup
      }
    }
    // Delete any language-scoped or base encryption keys from secure storage
    try {
      final allEntries = await _secureStorage.readAll();
      final prefix = 'enc_key_${userId}_';
      for (final k in allEntries.keys) {
        if (k.startsWith(prefix)) {
          await _secureStorage.delete(key: k);
        }
      }
    } catch (_) {}

    await OfflineAvailabilityRepository.clearAllMetadataForUser(userId);
  }

  // --- Local Validation & Management ---

  static Future<File> _resolveLicenceFile(
      String bookId, {String? languageCode, String? userId}) async {
    final dir = await getApplicationDocumentsDirectory();
    final uid = userId ?? AppLocator.auth.currentUser?.id;

    if (uid != null && uid.isNotEmpty) {
      if (languageCode != null && languageCode.isNotEmpty) {
        final langFile = File('${dir.path}/users/$uid/books/$bookId/$languageCode/licence.json');
        if (langFile.existsSync()) return langFile;
      } else {
        final defaultLang = File('${dir.path}/users/$uid/books/$bookId/en/licence.json');
        if (defaultLang.existsSync()) return defaultLang;
        final bookDir = Directory('${dir.path}/users/$uid/books/$bookId');
        if (bookDir.existsSync()) {
          try {
            for (final entity in bookDir.listSync()) {
              if (entity is Directory) {
                final cand = File('${entity.path}/licence.json');
                if (cand.existsSync()) return cand;
              }
            }
          } catch (_) {}
        }
      }
      final userFile = File('${dir.path}/users/$uid/books/$bookId/licence.json');
      if (userFile.existsSync()) return userFile;
    }

    if (languageCode != null && languageCode.isNotEmpty) {
      final legacyLangFile = File('${dir.path}/books/$bookId/$languageCode/licence.json');
      if (legacyLangFile.existsSync()) return legacyLangFile;
    } else {
      final legacyDefault = File('${dir.path}/books/$bookId/en/licence.json');
      if (legacyDefault.existsSync()) return legacyDefault;
      final legacyBookDir = Directory('${dir.path}/books/$bookId');
      if (legacyBookDir.existsSync()) {
        try {
          for (final entity in legacyBookDir.listSync()) {
            if (entity is Directory) {
              final cand = File('${entity.path}/licence.json');
              if (cand.existsSync()) return cand;
            }
          }
        } catch (_) {}
      }
    }
    final legacyFile = File('${dir.path}/books/$bookId/licence.json');
    if (legacyFile.existsSync()) return legacyFile;

    if (uid != null && uid.isNotEmpty) {
      if (languageCode != null && languageCode.isNotEmpty) {
        return File('${dir.path}/users/$uid/books/$bookId/$languageCode/licence.json');
      }
      return File('${dir.path}/users/$uid/books/$bookId/en/licence.json');
    }
    if (languageCode != null && languageCode.isNotEmpty) {
      return File('${dir.path}/books/$bookId/$languageCode/licence.json');
    }
    return legacyFile;
  }

  static Future<void> saveLicence(BookLicence licence) async {
    final file = await _resolveLicenceFile(
      licence.bookId,
      languageCode: licence.languageCode,
      userId: licence.userId,
    );
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(licence.toMap()));
  }

  static Future<BookLicence?> loadLicence(
      String bookId, {String? languageCode, String? userId}) async {
    final file = await _resolveLicenceFile(
      bookId,
      languageCode: languageCode,
      userId: userId,
    );
    if (!await file.exists()) return null;
    try {
      final jsonStr = await file.readAsString();
      final map = jsonDecode(jsonStr);
      return BookLicence.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteLicence(
      String bookId, {String? languageCode, String? userId}) async {
    final file = await _resolveLicenceFile(
      bookId,
      languageCode: languageCode,
      userId: userId,
    );
    if (await file.exists()) {
      await file.delete();
    }
    if (languageCode == null || languageCode.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      final legacy = File('${dir.path}/books/$bookId/licence.json');
      if (await legacy.exists()) {
        await legacy.delete();
      }
    }
  }

  static Future<bool> isOfflineTooLong() async {
    final hasNet = await NetworkGuard.hasConnection();
    if (hasNet) {
      await recordOnlineValidation();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastValStr = prefs.getString(_lastValidationKey);
    if (lastValStr == null) {
      return false; // Not restricted if no validation timestamp recorded yet
    }
    final lastVal = DateTime.parse(lastValStr);
    final days = DateTime.now().difference(lastVal).inDays;
    return days >= _offlineGracePeriodDays;
  }

  static Future<void> recordOnlineValidation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastValidationKey, DateTime.now().toIso8601String());
  }

  static Future<bool> isLicenceValid(
      String bookId, {String? languageCode, String? userId}) async {
    final effectiveUid = userId ?? AppLocator.auth.currentUser?.id;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      return false;
    }

    // 1. Check Offline Grace Period
    if (await isOfflineTooLong()) {
      await revokeDownloadedContent(effectiveUid, bookId, languageCode: languageCode);
      return false;
    }

    // 2. Load Licence File
    final licence = await loadLicence(bookId, languageCode: languageCode, userId: effectiveUid);
    if (licence == null) return false;

    // 3. Verify Signature
    final salt = await _getOrCreateSigningSalt();
    final expectedSig = _calculateSignature(
      licence.userId,
      licence.bookId,
      licence.languageCode,
      licence.downloadDate,
      licence.licenceExpiryDate,
      licence.premiumPlanId,
      licence.contentVersion,
      salt,
    );
    final legacySig = _calculateLegacySignature(
      licence.userId,
      licence.bookId,
      licence.downloadDate,
      licence.licenceExpiryDate,
      licence.premiumPlanId,
      licence.contentVersion,
      salt,
    );

    if (licence.signature != expectedSig && licence.signature != legacySig) {
      // Tampered licence! Delete key and block immediately
      await revokeDownloadedContent(licence.userId, bookId, languageCode: licence.languageCode);
      return false;
    }

    // 4. Verify Expiry Date
    final expiry = DateTime.parse(licence.licenceExpiryDate);
    if (expiry.isBefore(DateTime.now())) {
      await revokeDownloadedContent(licence.userId, bookId, languageCode: licence.languageCode);
      return false;
    }

    // 5. Verify User Match
    final user = AppLocator.auth.currentUser;
    if (user == null || user.id != licence.userId) {
      return false;
    }

    // 6. Verify Premium Entitlement Status
    if (!user.isPremium) {
      // Premium ended! Mark key and content as locked
      await revokeDownloadedContent(licence.userId, bookId, languageCode: licence.languageCode);
      return false;
    }

    return true;
  }

  static String? _activeSweepUserId;
  static Future<List<DownloadedEdition>>? _activeSweep;

  /// Performs a safe local validation sweep for the user's downloaded editions.
  /// Validates local licences, removes expired packages/keys/metadata,
  /// and returns only currently valid editions.
  /// Deduplicates concurrent sweeps to avoid race conditions.
  static Future<List<DownloadedEdition>> pruneExpiredEditions(String userId) async {
    if (userId.isEmpty) return [];

    final currentUser = AppLocator.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      return [];
    }

    if (_activeSweep != null && _activeSweepUserId == userId) {
      return _activeSweep!;
    }

    final sweepFuture = _performValidationSweep(userId);
    _activeSweep = sweepFuture;
    _activeSweepUserId = userId;
    try {
      return await sweepFuture;
    } finally {
      if (_activeSweep == sweepFuture) {
        _activeSweep = null;
        _activeSweepUserId = null;
      }
    }
  }

  static Future<List<DownloadedEdition>> _performValidationSweep(String userId) async {
    final cached = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: userId);
    if (cached.isEmpty) return [];

    final validList = <DownloadedEdition>[];

    for (final edition in cached) {
      final isValid = await isLicenceValid(
        edition.bookId,
        languageCode: edition.languageCode,
        userId: userId,
      );

      if (isValid) {
        validList.add(edition);
      } else {
        await revokeDownloadedContent(
          userId,
          edition.bookId,
          languageCode: edition.languageCode,
        );
      }
    }

    return validList;
  }
}
