import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/service_locator.dart';
import 'encrypted_content_storage.dart';
import 'network_guard.dart';

class BookLicence {
  final String userId;
  final String bookId;
  final String downloadDate;
  final String licenceExpiryDate;
  final String premiumPlanId;
  final int contentVersion;
  final String signature;

  BookLicence({
    required this.userId,
    required this.bookId,
    required this.downloadDate,
    required this.licenceExpiryDate,
    required this.premiumPlanId,
    required this.contentVersion,
    required this.signature,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'bookId': bookId,
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
    // Mimics backend entitlement checking
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

  static Future<BookLicence> issueDownloadLicence(String userId, String bookId) async {
    final salt = await _getOrCreateSigningSalt();
    final downloadDate = DateTime.now().toIso8601String();
    // License valid for 30 days
    final licenceExpiryDate = DateTime.now().add(const Duration(days: 30)).toIso8601String();
    const premiumPlanId = 'premium_yearly';
    const contentVersion = 1;

    final signature = _calculateSignature(
      userId,
      bookId,
      downloadDate,
      licenceExpiryDate,
      premiumPlanId,
      contentVersion,
      salt,
    );

    return BookLicence(
      userId: userId,
      bookId: bookId,
      downloadDate: downloadDate,
      licenceExpiryDate: licenceExpiryDate,
      premiumPlanId: premiumPlanId,
      contentVersion: contentVersion,
      signature: signature,
    );
  }

  static Future<bool> validateDownloadLicence(
      String userId, String bookId, String licenceToken) async {
    // Validate signature and content version on the backend side
    final salt = await _getOrCreateSigningSalt();
    try {
      final map = jsonDecode(utf8.decode(base64Decode(licenceToken)));
      final licence = BookLicence.fromMap(map);
      
      final expectedSig = _calculateSignature(
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
          licence.signature == expectedSig &&
          DateTime.parse(licence.licenceExpiryDate).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static Future<void> revokeDownloadedContent(String userId, String bookId) async {
    // Mark download as revoked
    await EncryptedContentStorage.deleteDecryptionKey(userId, bookId);
    final dir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${dir.path}/books/$bookId');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }

  // --- Local Validation & Management ---

  static Future<void> saveLicence(BookLicence licence) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/books/${licence.bookId}/licence.json');
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(licence.toMap()));
  }

  static Future<BookLicence?> loadLicence(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/books/$bookId/licence.json');
    if (!await file.exists()) return null;
    try {
      final jsonStr = await file.readAsString();
      final map = jsonDecode(jsonStr);
      return BookLicence.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteLicence(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/books/$bookId/licence.json');
    if (await file.exists()) {
      await file.delete();
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
      return true; // restricted because never validated online
    }
    final lastVal = DateTime.parse(lastValStr);
    final days = DateTime.now().difference(lastVal).inDays;
    return days >= _offlineGracePeriodDays;
  }

  static Future<void> recordOnlineValidation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastValidationKey, DateTime.now().toIso8601String());
  }

  static Future<bool> isLicenceValid(String bookId) async {
    // 1. Check Offline Grace Period
    if (await isOfflineTooLong()) {
      return false;
    }

    // 2. Load Licence File
    final licence = await loadLicence(bookId);
    if (licence == null) return false;

    // 3. Verify Signature
    final salt = await _getOrCreateSigningSalt();
    final expectedSig = _calculateSignature(
      licence.userId,
      licence.bookId,
      licence.downloadDate,
      licence.licenceExpiryDate,
      licence.premiumPlanId,
      licence.contentVersion,
      salt,
    );

    if (licence.signature != expectedSig) {
      // Tampered licence! Delete key and block immediately
      await revokeDownloadedContent(licence.userId, bookId);
      return false;
    }

    // 4. Verify Expiry Date
    final expiry = DateTime.parse(licence.licenceExpiryDate);
    if (expiry.isBefore(DateTime.now())) {
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
      await revokeDownloadedContent(licence.userId, bookId);
      return false;
    }

    return true;
  }
}
