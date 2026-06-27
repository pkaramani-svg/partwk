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

class LicenceInvalidException implements Exception {
  final String message;
  LicenceInvalidException(this.message);
}

class LicenceExpiredException implements Exception {
  final String message;
  LicenceExpiredException(this.message);
}

class DownloadManager {
  final Dio _dio = Dio();

  Future<bool> downloadBook(Book book, String languageCode, Function(double) onProgress) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return false;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final bookDir = Directory('${dir.path}/books/${book.id}');
      if (!await bookDir.exists()) {
        await bookDir.create(recursive: true);
      }

      // 1. Download Cover (unencrypted)
      final coverUrl = book.getCoverImageUrl(languageCode);
      if (coverUrl.isNotEmpty && !coverUrl.startsWith('local:')) {
        String localCoverPath = '${bookDir.path}/cover.jpg';
        await _dio.download(coverUrl, localCoverPath);
      }

      // 2. Encrypt and save Text Content (.partwkbook)
      final sensitiveContent = {
        'fiveMinuteSummary': book.fiveMinuteSummary,
        'fifteenMinuteSummary': book.fifteenMinuteSummary,
        'chapterSummaries': book.chapterSummaries,
        'keyIdeas': book.keyIdeas,
        'keyQuotes': book.keyQuotes,
        'actionPoints': book.actionPoints,
      };
      
      final plaintextTextBytes = utf8.encode(jsonEncode(sensitiveContent));
      final textFilePath = '${bookDir.path}/summary.partwkbook';
      await EncryptedContentStorage.saveEncryptedFile(user.id, book.id, textFilePath, plaintextTextBytes);

      // 3. Download, Encrypt, and save Audio Content for each chapter across all available languages
      final languages = book.chapterSummaries.keys.toList();
      if (languages.isEmpty) {
        languages.add('en');
      }

      int totalChaptersToDownload = 0;
      for (final lang in languages) {
        final chapters = book.getChapterSummaries(lang);
        for (final chapter in chapters) {
          final url = chapter['audioUrl'] as String? ?? '';
          if (url.isNotEmpty && !url.startsWith('local:')) {
            totalChaptersToDownload++;
          }
        }
      }

      int downloadedChaptersCount = 0;
      for (final lang in languages) {
        final chapters = book.getChapterSummaries(lang);
        for (int idx = 0; idx < chapters.length; idx++) {
          final chapter = chapters[idx];
          final url = chapter['audioUrl'] as String? ?? '';
          if (url.isNotEmpty && !url.startsWith('local:')) {
            final tempAudioPath = '${bookDir.path}/temp_audio_${lang}_$idx.mp3';
            
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
            
            final audioFilePath = '${bookDir.path}/audio_${lang}_$idx.partwkaudio';
            await EncryptedContentStorage.saveEncryptedFile(user.id, book.id, audioFilePath, plaintextAudioBytes);
            
            // Securely delete the unencrypted temp file immediately
            await tempFile.delete();
            downloadedChaptersCount++;
          }
        }
      }
      onProgress(1.0);

      // 4. Issue and Save Signed Licence
      final licence = await LicenceManager.issueDownloadLicence(user.id, book.id);
      await LicenceManager.saveLicence(licence);

      // 5. Cache Sanitized Book Metadata
      await OfflineAvailabilityRepository.cacheBookMetadata(book);

      // 6. Write complete marker file
      final completeFile = File('${bookDir.path}/download.complete');
      await completeFile.create();

      return true;
    } catch (e) {
      print('DownloadManager downloadBook error: $e');
      return false;
    }
  }

  static Future<bool> isBookDownloaded(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final completeFile = File('${dir.path}/books/$bookId/download.complete');
    return await completeFile.exists();
  }

  static Future<Book> loadBookContent(Book book) async {
    final isDownloaded = await isBookDownloaded(book.id);
    if (!isDownloaded) return book;

    // Validate Licence
    final isValid = await LicenceManager.isLicenceValid(book.id);
    if (!isValid) {
      throw LicenceInvalidException('Licence is invalid or expired for book: ${book.id}');
    }

    final user = AppLocator.auth.currentUser;
    if (user == null) {
      throw LicenceInvalidException('User not authenticated');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final textFilePath = '${dir.path}/books/${book.id}/summary.partwkbook';
      
      final decryptedBytes = await EncryptedContentStorage.readDecryptedFile(user.id, book.id, textFilePath);
      final decryptedStr = utf8.decode(decryptedBytes);
      final contentMap = jsonDecode(decryptedStr) as Map<String, dynamic>;

      // Load sensitive collections safely
      final parsedChapters = contentMap['chapterSummaries'] as Map<String, dynamic>? ?? {};
      final Map<String, List<Map<String, dynamic>>> chapterSummaries = {};
      parsedChapters.forEach((k, v) {
        if (v is List) {
          chapterSummaries[k] = v.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      });

      final parsedKeyIdeas = contentMap['keyIdeas'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> keyIdeas = {};
      parsedKeyIdeas.forEach((k, v) {
        if (v is List) {
          keyIdeas[k] = v.map((e) => e.toString()).toList();
        }
      });

      final parsedKeyQuotes = contentMap['keyQuotes'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> keyQuotes = {};
      parsedKeyQuotes.forEach((k, v) {
        if (v is List) {
          keyQuotes[k] = v.map((e) => e.toString()).toList();
        }
      });

      final parsedActionPoints = contentMap['actionPoints'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> actionPoints = {};
      parsedActionPoints.forEach((k, v) {
        if (v is List) {
          actionPoints[k] = v.map((e) => e.toString()).toList();
        }
      });

      final fiveMinuteSummary = Map<String, String>.from(contentMap['fiveMinuteSummary'] ?? {});
      final fifteenMinuteSummary = Map<String, String>.from(contentMap['fifteenMinuteSummary'] ?? {});

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
    final isValid = await LicenceManager.isLicenceValid(bookId);
    if (!isValid) {
      throw LicenceInvalidException('Licence is invalid or expired for book: $bookId');
    }

    final user = AppLocator.auth.currentUser;
    if (user == null) {
      throw LicenceInvalidException('User not authenticated');
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final parts = tag.id.split('_');
      final idx = parts.isNotEmpty ? parts.last : '0';
      
      String audioFilePath = '${dir.path}/books/$bookId/audio_${langCode}_$idx.partwkaudio';
      if (!await File(audioFilePath).exists()) {
        // Fallback to English
        audioFilePath = '${dir.path}/books/$bookId/audio_en_$idx.partwkaudio';
      }
      
      final decryptedBytes = await EncryptedContentStorage.readDecryptedFile(user.id, bookId, audioFilePath);
      
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
