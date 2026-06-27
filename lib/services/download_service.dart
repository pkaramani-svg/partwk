import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';
import '../core/services/download_manager.dart';
import '../core/services/licence_manager.dart';
import '../core/services/encrypted_content_storage.dart';
import '../core/services/offline_availability_repository.dart';
import '../core/services/service_locator.dart';

class DownloadService {
  final Dio _dio = Dio();
  static const String _offlineBooksKey = 'offline_books';
  
  static String? _appDocsPath;

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _appDocsPath = dir.path;
  }

  static String? get appDocsPath => _appDocsPath;

  static bool isBookDownloadedSync(String bookId) {
    if (_appDocsPath == null) return false;
    final completeFile = File('$_appDocsPath/books/$bookId/download.complete');
    return completeFile.existsSync();
  }

  static File getLocalCoverFileSync(String bookId) {
    return File('$_appDocsPath/books/$bookId/cover.jpg');
  }

  static File getLocalAudioFileSync(String bookId, String languageCode) {
    final file = File('$_appDocsPath/books/$bookId/audio_${languageCode}_0.partwkaudio');
    if (file.existsSync()) return file;
    return File('$_appDocsPath/books/$bookId/audio_en_0.partwkaudio');
  }

  /// Returns an ImageProvider, falling back to network if local isn't available
  static ImageProvider getBookCoverProvider(Book book, {String? langCode}) {
    if (isBookDownloadedSync(book.id)) {
      return FileImage(getLocalCoverFileSync(book.id));
    }
    final url = langCode != null ? book.getCoverImageUrl(langCode) : book.coverImageUrl;
    return NetworkImage(url);
  }

  /// Returns a Widget to show the book cover, with fallback to network
  static Widget getBookCoverWidget(Book book, {String? langCode, double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (isBookDownloadedSync(book.id)) {
      return Image.file(
        getLocalCoverFileSync(book.id),
        width: width,
        height: height,
        fit: fit,
      );
    }
    final url = langCode != null ? book.getCoverImageUrl(langCode) : book.coverImageUrl;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[800],
          child: const Icon(Icons.book, color: Colors.white),
        );
      },
    );
  }

  // Singleton pattern
  static DownloadService? _mock;
  static set mock(DownloadService? mockInstance) => _mock = mockInstance;

  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _mock ?? _instance;
  DownloadService._internal();

  /// Downloads cover and audio for offline use
  Future<bool> downloadBook(Book book, String languageCode, Function(double) onProgress) async {
    return DownloadManager().downloadBook(book, languageCode, onProgress);
  }

  /// Retrieves the list of downloaded books
  Future<List<Book>> getDownloadedBooks() async {
    return OfflineAvailabilityRepository.getCachedBooksMetadata();
  }

  /// Checks if a book is fully downloaded
  Future<bool> isBookDownloaded(String bookId) async {
    return DownloadManager.isBookDownloaded(bookId);
  }
  
  /// Gets the local file URI for the cover image
  Future<String?> getLocalCoverUri(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/books/$bookId/cover.jpg');
    if (await file.exists()) {
      return 'file://${file.path}';
    }
    return null;
  }

  /// Gets the local file URI for the audio
  Future<String?> getLocalAudioUri(String bookId, String languageCode) async {
    final dir = await getApplicationDocumentsDirectory();
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

  /// Removes a downloaded book
  Future<void> removeDownload(String bookId) async {
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      await EncryptedContentStorage.deleteDecryptionKey(user.id, bookId);
    }
    await LicenceManager.deleteLicence(bookId);
    await OfflineAvailabilityRepository.removeBookMetadata(bookId);
    
    // Also delete directory
    final dir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${dir.path}/books/$bookId');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }
}
