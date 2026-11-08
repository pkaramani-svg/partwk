import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/book.dart';
import '../services/service_locator.dart';
import 'encrypted_content_storage.dart';
import 'licence_manager.dart';
import 'offline_availability_repository.dart';
import 'protected_text_service.dart';

class LicenceInvalidException implements Exception {
  final String message;
  LicenceInvalidException(this.message);
}

class LicenceExpiredException implements Exception {
  final String message;
  LicenceExpiredException(this.message);
}

class DownloadPermissionDeniedException implements Exception {
  final String message;
  DownloadPermissionDeniedException([this.message = 'Only active Premium members can download books.']);
  @override
  String toString() => message;
}

class DownloadLimitExceededException implements Exception {
  final String message;
  DownloadLimitExceededException([this.message = 'Download limit reached. You can have at most 3 downloaded language editions at a time.']);
  @override
  String toString() => message;
}

class DownloadManager {
  final Dio _dio = Dio();

  Future<bool> downloadBook(Book book, String languageCode, Function(double) onProgress) async {
    final user = AppLocator.auth.currentUser;
    if (user == null || AppLocator.auth.isGuest || !user.isPremium) {
      throw DownloadPermissionDeniedException();
    }

    // Enforce 3-download maximum across all language editions (validating and pruning expired editions first)
    final existingEditions = await LicenceManager.pruneExpiredEditions(user.id);
    final alreadyDownloaded = await isEditionDownloaded(book.id, languageCode, userId: user.id);
    if (!alreadyDownloaded && existingEditions.length >= 3) {
      throw DownloadLimitExceededException();
    }

    try {
      if (book.isPremium) {
        if (!book.hiddenLanguages.contains(languageCode)) {
          book = await ProtectedTextService.hydrate(book, languageCode);
        }
      }
      final dir = await getApplicationDocumentsDirectory();
      final editionDir = Directory('${dir.path}/users/${user.id}/books/${book.id}/$languageCode');
      if (!await editionDir.exists()) {
        await editionDir.create(recursive: true);
      }

      // 1. Download Cover (unencrypted)
      final coverUrl = book.getCoverImageUrl(languageCode);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('local:')) {
        String localCoverPath = '${editionDir.path}/cover.jpg';
        await _dio.download(coverUrl, localCoverPath);
      }

      // 2. Encrypt and save Text Content (.partwkbook) for this specific language edition
      final sensitiveContent = {
        'fiveMinuteSummary': book.fiveMinuteSummary,
        'fifteenMinuteSummary': book.fifteenMinuteSummary,
        'chapterSummaries': {languageCode: book.getChapterSummaries(languageCode)},
        'keyIdeas': {languageCode: book.getKeyIdeas(languageCode)},
        'keyQuotes': {languageCode: book.getKeyQuotes(languageCode)},
        'actionPoints': {languageCode: book.getActionPoints(languageCode)},
      };
      
      final plaintextTextBytes = utf8.encode(jsonEncode(sensitiveContent));
      final textFilePath = '${editionDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(
        user.id,
        book.id,
        textFilePath,
        plaintextTextBytes,
        languageCode: languageCode,
      );

      // 3. Download, Encrypt, and save Audio Content for chapters in this edition
      final chapters = book.getChapterSummaries(languageCode);
      int totalChaptersToDownload = chapters.where((c) {
        final url = c['audioUrl'] as String? ?? '';
        return url.isNotEmpty && !url.startsWith('local:');
      }).length;

      int downloadedChaptersCount = 0;
      for (int idx = 0; idx < chapters.length; idx++) {
        final chapter = chapters[idx];
        final url = chapter['audioUrl'] as String? ?? '';
        if (url.isNotEmpty && !url.startsWith('local:')) {
          final tempAudioPath = '${editionDir.path}/temp_audio_$idx.mp3';
          
          await _dio.download(
            url,
            tempAudioPath,
            onReceiveProgress: (received, total) {
              if (total != -1 && totalChaptersToDownload > 0) {
                final chapterProgress = received / total;
                final overallProgress = (downloadedChaptersCount + chapterProgress) / totalChaptersToDownload;
                onProgress(overallProgress);
              }
            },
          );

          final tempFile = File(tempAudioPath);
          final plaintextAudioBytes = await tempFile.readAsBytes();
          
          final audioFilePath = '${editionDir.path}/audio_$idx.partwkaudio';
          await EncryptedContentStorage.saveEncryptedFile(
            user.id,
            book.id,
            audioFilePath,
            plaintextAudioBytes,
            languageCode: languageCode,
          );
          
          // Securely delete the unencrypted temp file immediately
          await tempFile.delete();
          downloadedChaptersCount++;
        }
      }
      onProgress(1.0);

      // 4. Issue and Save Signed Licence scoped to this edition
      final licence = await LicenceManager.issueDownloadLicence(
        user.id,
        book.id,
        languageCode: languageCode,
      );
      await LicenceManager.saveLicence(licence);

      // 5. Cache Sanitized Edition Metadata scoped to this user
      await OfflineAvailabilityRepository.cacheEditionMetadata(
        book,
        languageCode,
        userId: user.id,
      );

      // 6. Write complete marker file in edition directory
      final completeFile = File('${editionDir.path}/download.complete');
      await completeFile.create();

      return true;
    } catch (e) {
      if (e is DownloadPermissionDeniedException || e is DownloadLimitExceededException) {
        rethrow;
      }
      print('DownloadManager downloadBook error: $e');
      return false;
    }
  }

  static Future<bool> isEditionDownloaded(String bookId, String languageCode, {String? userId}) async {
    final uid = userId ?? AppLocator.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return false;
    final dir = await getApplicationDocumentsDirectory();
    final userComplete = File('${dir.path}/users/$uid/books/$bookId/$languageCode/download.complete');
    if (await userComplete.exists()) return true;
    final legacyComplete = File('${dir.path}/books/$bookId/$languageCode/download.complete');
    if (await legacyComplete.exists()) return true;
    // Check root folder complete marker for backwards compatibility
    final rootComplete = File('${dir.path}/users/$uid/books/$bookId/download.complete');
    if (await rootComplete.exists()) return true;
    final legacyRoot = File('${dir.path}/books/$bookId/download.complete');
    return await legacyRoot.exists();
  }

  static Future<bool> isBookDownloaded(String bookId, {String? userId}) async {
    final uid = userId ?? AppLocator.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return false;

    final editions = await OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: uid);
    if (editions.any((e) => e.bookId == bookId)) return true;

    final dir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${dir.path}/users/$uid/books/$bookId');
    if (await bookDir.exists()) {
      try {
        final entries = await bookDir.list().toList();
        for (final entry in entries) {
          if (entry is Directory) {
            final comp = File('${entry.path}/download.complete');
            if (await comp.exists()) return true;
          }
        }
        final rootComp = File('${bookDir.path}/download.complete');
        if (await rootComp.exists()) return true;
      } catch (_) {}
    }
    final legacyComplete = File('${dir.path}/books/$bookId/download.complete');
    return await legacyComplete.exists();
  }

  static Future<Book> loadBookContent(Book book, {String? languageCode}) async {
    final user = AppLocator.auth.currentUser;
    if (user == null || AppLocator.auth.isGuest || !user.isPremium) {
      throw LicenceInvalidException('Active Premium required');
    }

    final lang = languageCode ?? 'en';
    final isValid = await LicenceManager.isLicenceValid(book.id, languageCode: lang, userId: user.id) ||
                    await LicenceManager.isLicenceValid(book.id, userId: user.id);
    if (!isValid) {
      throw LicenceInvalidException('Licence is invalid or expired for book: ${book.id}');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      String textFilePath = '${dir.path}/users/${user.id}/books/${book.id}/$lang/summary.partwkbook';
      String? activeLang = lang;
      if (!await File(textFilePath).exists()) {
        textFilePath = '${dir.path}/users/${user.id}/books/${book.id}/summary.partwkbook';
        activeLang = null;
      }
      if (!await File(textFilePath).exists()) {
        textFilePath = '${dir.path}/books/${book.id}/summary.partwkbook';
        activeLang = null;
      }
      
      final decryptedBytes = await EncryptedContentStorage.readDecryptedFile(
        user.id,
        book.id,
        textFilePath,
        languageCode: activeLang,
      );
      final decryptedStr = utf8.decode(decryptedBytes);
      final contentMap = jsonDecode(decryptedStr) as Map<String, dynamic>;

      // Load sensitive collections safely
      final parsedChapters = contentMap['chapterSummaries'] as Map<String, dynamic>? ?? {};
      final Map<String, List<Map<String, dynamic>>> chapterSummaries = Map.from(book.chapterSummaries);
      parsedChapters.forEach((k, v) {
        if (v is List) {
          chapterSummaries[k] = v.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      });

      final parsedKeyIdeas = contentMap['keyIdeas'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> keyIdeas = Map.from(book.keyIdeas);
      parsedKeyIdeas.forEach((k, v) {
        if (v is List) {
          keyIdeas[k] = v.map((e) => e.toString()).toList();
        }
      });

      final parsedKeyQuotes = contentMap['keyQuotes'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> keyQuotes = Map.from(book.keyQuotes);
      parsedKeyQuotes.forEach((k, v) {
        if (v is List) {
          keyQuotes[k] = v.map((e) => e.toString()).toList();
        }
      });

      final parsedActionPoints = contentMap['actionPoints'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> actionPoints = Map.from(book.actionPoints);
      parsedActionPoints.forEach((k, v) {
        if (v is List) {
          actionPoints[k] = v.map((e) => e.toString()).toList();
        }
      });

      final fiveMinuteSummary = Map<String, String>.from(book.fiveMinuteSummary);
      final fifteenMinuteSummary = Map<String, String>.from(book.fifteenMinuteSummary);
      (contentMap['fiveMinuteSummary'] as Map<String, dynamic>?)?.forEach((k, v) {
        fiveMinuteSummary[k] = v.toString();
      });
      (contentMap['fifteenMinuteSummary'] as Map<String, dynamic>?)?.forEach((k, v) {
        fifteenMinuteSummary[k] = v.toString();
      });

      return Book(
        id: book.id,
        title: book.title,
        author: book.author,
        coverImageUrl: book.coverImageUrlMap,
        categoryIds: book.categoryIds,
        tags: book.tags,
        description: book.description,
        fiveMinuteSummary: fiveMinuteSummary,
        fifteenMinuteSummary: fifteenMinuteSummary,
        chapterSummaries: chapterSummaries,
        keyIdeas: keyIdeas,
        keyQuotes: keyQuotes,
        actionPoints: actionPoints,
        audioUrl: book.audioUrl,
        duration: book.duration,
        isPremium: book.isPremium,
        createdAt: book.createdAt,
        updatedAt: book.updatedAt,
        hiddenLanguages: book.hiddenLanguages,
      );
    } catch (e) {
      print('DownloadManager loadBookContent error: $e');
      throw CorruptedFileException('Failed to decrypt book summary');
    }
  }

  static Future<AudioSource> loadAudioSource(
      String bookId, String langCode, MediaItem tag) async {
    final user = AppLocator.auth.currentUser;
    if (user == null || AppLocator.auth.isGuest || !user.isPremium) {
      throw LicenceInvalidException('Active Premium required');
    }

    final isValid = await LicenceManager.isLicenceValid(bookId, languageCode: langCode, userId: user.id) ||
                    await LicenceManager.isLicenceValid(bookId, userId: user.id);
    if (!isValid) {
      throw LicenceInvalidException('Licence is invalid or expired for book: $bookId');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final parts = tag.id.split('_');
      final idx = parts.isNotEmpty ? parts.last : '0';
      
      String audioFilePath = '${dir.path}/users/${user.id}/books/$bookId/$langCode/audio_$idx.partwkaudio';
      String? activeLang = langCode;

      if (!await File(audioFilePath).exists()) {
        audioFilePath = '${dir.path}/users/${user.id}/books/$bookId/$langCode/audio_${langCode}_$idx.partwkaudio';
      }
      if (!await File(audioFilePath).exists()) {
        audioFilePath = '${dir.path}/users/${user.id}/books/$bookId/audio_${langCode}_$idx.partwkaudio';
        activeLang = null;
      }
      if (!await File(audioFilePath).exists()) {
        audioFilePath = '${dir.path}/users/${user.id}/books/$bookId/audio_en_$idx.partwkaudio';
        activeLang = null;
      }
      if (!await File(audioFilePath).exists()) {
        // Fallback to legacy path
        audioFilePath = '${dir.path}/books/$bookId/audio_${langCode}_$idx.partwkaudio';
        activeLang = null;
        if (!await File(audioFilePath).exists()) {
          audioFilePath = '${dir.path}/books/$bookId/audio_en_$idx.partwkaudio';
        }
      }
      
      final decryptedBytes = await EncryptedContentStorage.readDecryptedFile(
        user.id,
        bookId,
        audioFilePath,
        languageCode: activeLang,
      );
      
      // Dynamically detect extension from the decrypted file signature to support WAV and MP3
      String ext = '.mp3';
      if (decryptedBytes.length >= 4) {
        final isWav = decryptedBytes[0] == 0x52 && // R
                      decryptedBytes[1] == 0x49 && // I
                      decryptedBytes[2] == 0x46 && // F
                      decryptedBytes[3] == 0x46;   // F
        if (isWav) {
          ext = '.wav';
        }
      }
      
      final tempDir = await getTemporaryDirectory();
      final playDir = Directory('${tempDir.path}/temp_play');
      if (!await playDir.exists()) {
        await playDir.create(recursive: true);
      }
      final tempFile = File('${playDir.path}/temp_${bookId}_${langCode}_$idx$ext');
      await tempFile.writeAsBytes(decryptedBytes, flush: true);
      
      return AudioSource.file(tempFile.path, tag: tag);
    } catch (e) {
      print('DownloadManager loadAudioSource error: $e');
      throw CorruptedFileException('Failed to decrypt audio source');
    }
  }

  static Future<void> cleanupTempPlaybackFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final playDir = Directory('${tempDir.path}/temp_play');
      if (await playDir.exists()) {
        await playDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error cleaning up temp playback files: $e');
    }
  }
}
