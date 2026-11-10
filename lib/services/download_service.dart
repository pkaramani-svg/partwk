import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../core/services/download_manager.dart';
import '../core/services/licence_manager.dart';
import '../core/services/offline_availability_repository.dart';
import '../core/services/catalogue_cache_service.dart';
import '../core/services/service_locator.dart';

class DownloadService {
  
  static String? _appDocsPath;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDocsPath = dir.path;
  }

  static String? get appDocsPath => _appDocsPath;

  static bool isEditionDownloadedSync(String bookId, String languageCode) {
    if (_appDocsPath == null) return false;
    final user = AppLocator.auth.currentUser;
    if (user == null || AppLocator.auth.isGuest || !user.isPremium) return false;

    final editionComplete = File('$_appDocsPath/users/${user.id}/books/$bookId/$languageCode/download.complete');
    if (editionComplete.existsSync()) return true;

    final legacyEditionComplete = File('$_appDocsPath/books/$bookId/$languageCode/download.complete');
    if (legacyEditionComplete.existsSync()) return true;

    final userRootComplete = File('$_appDocsPath/users/${user.id}/books/$bookId/download.complete');
    if (userRootComplete.existsSync()) return true;

    final legacyComplete = File('$_appDocsPath/books/$bookId/download.complete');
    return legacyComplete.existsSync();
  }

  static bool isBookDownloadedSync(String bookId) {
    if (_appDocsPath == null) return false;
    final user = AppLocator.auth.currentUser;
    if (user == null || AppLocator.auth.isGuest || !user.isPremium) return false;

    final bookDir = Directory('$_appDocsPath/users/${user.id}/books/$bookId');
    if (bookDir.existsSync()) {
      try {
        final entries = bookDir.listSync();
        for (final entry in entries) {
          if (entry is Directory) {
            final comp = File('${entry.path}/download.complete');
            if (comp.existsSync()) return true;
          }
        }
        final rootComp = File('${bookDir.path}/download.complete');
        if (rootComp.existsSync()) return true;
      } catch (_) {}
    }

    final legacyComplete = File('$_appDocsPath/books/$bookId/download.complete');
    return legacyComplete.existsSync();
  }

  /// Returns the local cover File ONLY if it exists on disk and is non-empty.
  static File? getLocalCoverFileIfExists(String bookId, [String? languageCode]) {
    if (_appDocsPath == null) return null;
    final user = AppLocator.auth.currentUser;
    if (user != null && !AppLocator.auth.isGuest) {
      if (languageCode != null && languageCode.isNotEmpty) {
        final langCover = File('$_appDocsPath/users/${user.id}/books/$bookId/$languageCode/cover.jpg');
        if (langCover.existsSync() && langCover.lengthSync() > 0) return langCover;
      }
      final userCover = File('$_appDocsPath/users/${user.id}/books/$bookId/cover.jpg');
      if (userCover.existsSync() && userCover.lengthSync() > 0) return userCover;

      // Check if any downloaded language edition folder has a cover
      final userBookDir = Directory('$_appDocsPath/users/${user.id}/books/$bookId');
      if (userBookDir.existsSync()) {
        try {
          for (final sub in userBookDir.listSync()) {
            if (sub is Directory) {
              final f = File('${sub.path}/cover.jpg');
              if (f.existsSync() && f.lengthSync() > 0) return f;
            }
          }
        } catch (_) {}
      }
    }
    if (languageCode != null && languageCode.isNotEmpty) {
      final legacyLangCover = File('$_appDocsPath/books/$bookId/$languageCode/cover.jpg');
      if (legacyLangCover.existsSync() && legacyLangCover.lengthSync() > 0) return legacyLangCover;
    }
    final legacyCover = File('$_appDocsPath/books/$bookId/cover.jpg');
    if (legacyCover.existsSync() && legacyCover.lengthSync() > 0) return legacyCover;

    // Check catalogue cache covers
    final cachedCover = CatalogueCacheService.getCachedCoverFileSync(_appDocsPath!, bookId);
    if (cachedCover != null) return cachedCover;

    return null;
  }

  static File getLocalCoverFileSync(String bookId, [String? languageCode]) {
    final existing = getLocalCoverFileIfExists(bookId, languageCode);
    if (existing != null) return existing;
    return File('$_appDocsPath/books/$bookId/cover.jpg');
  }

  /// Returns the local audio File ONLY if it exists on disk and is non-empty.
  /// NEVER falls back to another language's audio.
  static File? getLocalAudioFileIfExists(String bookId, String languageCode) {
    if (_appDocsPath == null) return null;
    final user = AppLocator.auth.currentUser;
    if (user != null && !AppLocator.auth.isGuest) {
      final editionAudio = File('$_appDocsPath/users/${user.id}/books/$bookId/$languageCode/audio_0.partwkaudio');
      if (editionAudio.existsSync() && editionAudio.lengthSync() > 0) return editionAudio;

      final userAudio = File('$_appDocsPath/users/${user.id}/books/$bookId/audio_${languageCode}_0.partwkaudio');
      if (userAudio.existsSync() && userAudio.lengthSync() > 0) return userAudio;
    }
    final file = File('$_appDocsPath/books/$bookId/audio_${languageCode}_0.partwkaudio');
    if (file.existsSync() && file.lengthSync() > 0) return file;

    // Only if languageCode is explicitly English can it match legacy audio_en_0
    if (languageCode == 'en') {
      final legacyEn = File('$_appDocsPath/books/$bookId/audio_en_0.partwkaudio');
      if (legacyEn.existsSync() && legacyEn.lengthSync() > 0) return legacyEn;
    }

    return null;
  }

  static File getLocalAudioFileSync(String bookId, String languageCode) {
    final existing = getLocalAudioFileIfExists(bookId, languageCode);
    if (existing != null) return existing;
    return File('$_appDocsPath/books/$bookId/audio_${languageCode}_0.partwkaudio');
  }

  /// Clean, elegant Partwk cover placeholder. Never throws or displays raw errors.
  static Widget buildCoverPlaceholder({double? width, double? height, String? title, BoxFit fit = BoxFit.cover}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, color: Colors.tealAccent, size: 28),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Returns an ImageProvider, falling back cleanly to network or asset
  static ImageProvider getBookCoverProvider(Book book, {String? langCode}) {
    final localCover = getLocalCoverFileIfExists(book.id, langCode);
    if (localCover != null) {
      return FileImage(localCover);
    }
    final cachedCover = CatalogueCacheService.getCachedCoverFileSync(_appDocsPath, book.id);
    if (cachedCover != null) {
      return FileImage(cachedCover);
    }
    final url = langCode != null ? book.getCoverImageUrl(langCode) : book.coverImageUrl;
    if (url.isNotEmpty && url.startsWith('http')) {
      return NetworkImage(url);
    }
    return const AssetImage('assets/images/partwk_emblem.png');
  }

  /// Returns a Widget to show the book cover, with fallback to network and clean placeholder
  static Widget getBookCoverWidget(Book book, {String? langCode, double? width, double? height, BoxFit fit = BoxFit.cover}) {
    final effectiveLang = langCode ?? 'en';
    final localCover = getLocalCoverFileIfExists(book.id, langCode);
    if (localCover != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          localCover,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return buildCoverPlaceholder(width: width, height: height, title: book.getTitle(effectiveLang));
          },
        ),
      );
    }

    final cachedCover = CatalogueCacheService.getCachedCoverFileSync(_appDocsPath, book.id);
    if (cachedCover != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          cachedCover,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return buildCoverPlaceholder(width: width, height: height, title: book.getTitle(effectiveLang));
          },
        ),
      );
    }

    final url = langCode != null ? book.getCoverImageUrl(langCode) : book.coverImageUrl;
    if (url.isNotEmpty && url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return buildCoverPlaceholder(width: width, height: height, title: book.getTitle(effectiveLang));
          },
        ),
      );
    }

    return buildCoverPlaceholder(width: width, height: height, title: book.getTitle(effectiveLang));
  }

  // Singleton pattern
  static DownloadService? _mock;
  static set mock(DownloadService? mockInstance) => _mock = mockInstance;

  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _mock ?? _instance;
  DownloadService._internal();

  /// Downloads cover and audio for offline use for a specific language edition
  Future<bool> downloadBook(Book book, String languageCode, Function(double) onProgress) async {
    return DownloadManager().downloadBook(book, languageCode, onProgress);
  }

  /// Retrieves the list of downloaded editions
  Future<List<DownloadedEdition>> getDownloadedEditions({bool validateExpiry = true}) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return [];
    if (validateExpiry) {
      return LicenceManager.pruneExpiredEditions(user.id);
    }
    return OfflineAvailabilityRepository.getCachedEditionsMetadata(userId: user.id);
  }

  /// Retrieves the list of unique downloaded books
  Future<List<Book>> getDownloadedBooks({bool validateExpiry = true}) async {
    final user = AppLocator.auth.currentUser;
    if (user == null) return [];
    if (validateExpiry) {
      await LicenceManager.pruneExpiredEditions(user.id);
    }
    return OfflineAvailabilityRepository.getCachedBooksMetadata(userId: user.id);
  }

  /// Checks if a specific language edition is downloaded
  Future<bool> isEditionDownloaded(String bookId, String languageCode) async {
    final user = AppLocator.auth.currentUser;
    return DownloadManager.isEditionDownloaded(bookId, languageCode, userId: user?.id);
  }

  /// Checks if a book or edition is downloaded
  Future<bool> isBookDownloaded(String bookId, {String? languageCode}) async {
    final user = AppLocator.auth.currentUser;
    if (languageCode != null && languageCode.isNotEmpty) {
      return DownloadManager.isEditionDownloaded(bookId, languageCode, userId: user?.id);
    }
    return DownloadManager.isBookDownloaded(bookId, userId: user?.id);
  }
  
  /// Gets the local file URI for the cover image
  Future<String?> getLocalCoverUri(String bookId, [String? languageCode]) async {
    final dir = await getApplicationDocumentsDirectory();
    final user = AppLocator.auth.currentUser;
    if (user != null && languageCode != null) {
      final langFile = File('${dir.path}/users/${user.id}/books/$bookId/$languageCode/cover.jpg');
      if (await langFile.exists()) {
        return 'file://${langFile.path}';
      }
    }
    final file = File('${dir.path}/books/$bookId/cover.jpg');
    if (await file.exists()) {
      return 'file://${file.path}';
    }
    return null;
  }

  /// Gets the local file URI for the audio
  Future<String?> getLocalAudioUri(String bookId, String languageCode) async {
    final dir = await getApplicationDocumentsDirectory();
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      final editionAudio = File('${dir.path}/users/${user.id}/books/$bookId/$languageCode/audio_0.partwkaudio');
      if (await editionAudio.exists()) {
        return 'file://${editionAudio.path}';
      }
    }
    final file = File('${dir.path}/books/$bookId/audio_${languageCode}_0.partwkaudio');
    if (await file.exists()) {
      return 'file://${file.path}';
    }
    final fallbackFile = File('${dir.path}/books/$bookId/audio_en_0.partwkaudio');
    if (await fallbackFile.exists()) {
      return 'file://${fallbackFile.path}';
    }
    return null;
  }

  /// Removes a downloaded book or a specific language edition
  Future<void> removeDownload(String bookId, {String? languageCode}) async {
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      await LicenceManager.revokeDownloadedContent(user.id, bookId, languageCode: languageCode);
    }
  }
}
