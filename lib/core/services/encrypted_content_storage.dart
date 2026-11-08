import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:isolate';

class EncryptedContentStorage {
  static const _secureStorage = FlutterSecureStorage();

  // Custom Hex encoder/decoder to avoid external package dependence
  static String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _fromHex(String hexString) {
    final result = <int>[];
    for (int i = 0; i < hexString.length; i += 2) {
      result.add(int.parse(hexString.substring(i, i + 2), radix: 16));
    }
    return result;
  }

  static String getKeyAlias(String userId, String bookId, [String? languageCode]) {
    if (languageCode != null && languageCode.isNotEmpty) {
      return 'enc_key_${userId}_${bookId}_$languageCode';
    }
    return 'enc_key_${userId}_$bookId';
  }

  static Future<List<int>> getOrCreateKey(String userId, String bookId, {String? languageCode}) async {
    final keyName = getKeyAlias(userId, bookId, languageCode);
    String? keyHex = await _secureStorage.read(key: keyName);
    if (keyHex == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (i) => random.nextInt(256));
      keyHex = _toHex(bytes);
      await _secureStorage.write(key: keyName, value: keyHex);
    }
    return _fromHex(keyHex);
  }

  static Future<void> deleteDecryptionKey(String userId, String bookId, {String? languageCode}) async {
    if (languageCode != null && languageCode.isNotEmpty) {
      final keyName = getKeyAlias(userId, bookId, languageCode);
      await _secureStorage.delete(key: keyName);
      return;
    }
    // Also delete base un-scoped key if present
    final baseKey = 'enc_key_${userId}_$bookId';
    await _secureStorage.delete(key: baseKey);

    // If languageCode is not specified, clean up all language-scoped keys for this book as well
    try {
      final allEntries = await _secureStorage.readAll();
      final prefix = 'enc_key_${userId}_${bookId}_';
      for (final k in allEntries.keys) {
        if (k.startsWith(prefix)) {
          await _secureStorage.delete(key: k);
        }
      }
    } catch (_) {}
  }

  static Future<void> clearAllKeys() async {
    await _secureStorage.deleteAll();
  }

  static Future<void> saveEncryptedFile(
      String userId, String bookId, String filePath, List<int> plaintextBytes,
      {String? languageCode}) async {
    final keyBytes = await getOrCreateKey(userId, bookId, languageCode: languageCode);
    
    // Generate random 16 bytes IV
    final random = Random.secure();
    final ivBytes = Uint8List.fromList(List<int>.generate(16, (i) => random.nextInt(256)));
    
    final encryptedBytes = await Isolate.run(() {
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(plaintextBytes, iv: iv);
      return encrypted.bytes;
    });
    
    // Structure: 16 bytes IV + encrypted payload
    final file = File(filePath);
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
    
    final output = BytesBuilder();
    output.add(ivBytes);
    output.add(encryptedBytes);
    await file.writeAsBytes(output.toBytes());
  }

  static Future<List<int>> readDecryptedFile(
      String userId, String bookId, String filePath,
      {String? languageCode}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileNotFoundException('File not found: $filePath');
    }
    
    final fileBytes = await file.readAsBytes();
    if (fileBytes.length < 16) {
      throw CorruptedFileException('Invalid encrypted file length');
    }
    
    final ivBytes = fileBytes.sublist(0, 16);
    final encryptedPayload = fileBytes.sublist(16);

    // If languageCode not specified, infer from file path if possible
    String? resolvedLang = languageCode;
    if (resolvedLang == null || resolvedLang.isEmpty) {
      final segments = filePath.split(Platform.pathSeparator);
      final bookIndex = segments.indexOf(bookId);
      if (bookIndex != -1 && bookIndex + 1 < segments.length) {
        final nextSeg = segments[bookIndex + 1];
        if (!nextSeg.contains('.')) {
          resolvedLang = nextSeg;
        }
      }
    }
    
    final keyBytes = await getOrCreateKey(userId, bookId, languageCode: resolvedLang);
    
    final decryptedBytes = await Isolate.run(() {
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(Uint8List.fromList(ivBytes));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decryptBytes(enc.Encrypted(Uint8List.fromList(encryptedPayload)), iv: iv);
    });
    
    return decryptedBytes;
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
}

class CorruptedFileException implements Exception {
  final String message;
  CorruptedFileException(this.message);
}
