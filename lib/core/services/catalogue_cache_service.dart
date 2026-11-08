import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import '../../models/book.dart';
import '../../models/category.dart';

/// App-private catalogue-only cache service.
/// Quietly caches catalogue metadata (titles, authors, descriptions, categories,
/// language visibility, durations, tags, isPremium) and cover images.
/// 
/// STRICT SECURITY RULES:
/// Never caches or downloads full book content:
/// - no chapter text
/// - no summaries or key points
/// - no quotes, quizzes or flashcards
/// - no audio or audio URLs
class CatalogueCacheService {
  static const String _catalogueFileName = 'catalogue_cache.json';
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 10)));

  static Future<String> _getAppDocsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<Directory> _getCoversDir() async {
    final docsPath = await _getAppDocsPath();
    final coversDir = Directory('$docsPath/cache/covers');
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir;
  }

  /// Returns cached cover file if it exists on disk, otherwise null.
  static File? getCachedCoverFileSync(String? docsPath, String bookId) {
    if (docsPath == null || docsPath.isEmpty) return null;
    try {
      final f = File('$docsPath/cache/covers/$bookId.jpg');
      if (f.existsSync() && f.lengthSync() > 0) {
        return f;
      }
    } catch (_) {}
    return null;
  }

  /// Asynchronously saves sanitized catalogue metadata and caches covers in background.
  static Future<void> saveCatalogueCache(List<Book> books, List<Category> categories) async {
    try {
      final docsPath = await _getAppDocsPath();
      final file = File('$docsPath/$_catalogueFileName');

      // Sanitize books: STRICTLY catalogue metadata only. No chapter text or audio!
      final sanitizedBooksList = books.where((b) => b.isPublished).map((b) {
        return {
          'id': b.id,
          'title': b.title,
          'author': b.author,
          'description': b.description,
          'categoryIds': b.categoryIds,
          'categories': b.categories,
          'tags': b.tags,
          'coverImageUrl': b.coverImageUrlMap,
          'duration': b.duration,
          'isPremium': b.isPremium,
          'isPublished': b.isPublished,
          'hiddenLanguages': b.hiddenLanguages,
          'createdAt': b.createdAt.toIso8601String(),
          'updatedAt': b.updatedAt.toIso8601String(),
          // Explicitly empty for all sensitive content:
          'fiveMinuteSummary': {},
          'fifteenMinuteSummary': {},
          'chapterSummaries': {},
          'keyIdeas': {},
          'keyQuotes': {},
          'actionPoints': {},
          'audioUrl': {},
          'quiz': {},
          'flashcards': {},
        };
      }).toList();

      final categoriesList = categories.map((c) => {
        'id': c.id,
        'name': c.name,
        'iconName': c.iconName,
      }).toList();

      final payload = {
        'timestamp': DateTime.now().toIso8601String(),
        'books': sanitizedBooksList,
        'categories': categoriesList,
      };

      await file.writeAsString(jsonEncode(payload), flush: true);

      // Quietly cache cover images in background
      _cacheCoversInBackground(books);
    } catch (e) {
      debugPrint('Error saving catalogue cache: $e');
    }
  }

  static void _cacheCoversInBackground(List<Book> books) async {
    try {
      final coversDir = await _getCoversDir();
      for (final book in books) {
        if (!book.isPublished) continue;
        final targetFile = File('${coversDir.path}/${book.id}.jpg');
        if (targetFile.existsSync() && targetFile.lengthSync() > 0) continue;

        // Try to download cover image
        final url = book.getCoverImageUrl('en');
        if (url.isNotEmpty && url.startsWith('http')) {
          try {
            await _dio.download(url, targetFile.path);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Loads cached catalogue books. Returns empty list if cache does not exist.
  static Future<List<Book>> loadCatalogueBooks() async {
    try {
      final docsPath = await _getAppDocsPath();
      final file = File('$docsPath/$_catalogueFileName');
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final rawBooks = data['books'] as List<dynamic>? ?? [];

      return rawBooks.map((item) {
        final map = item as Map<String, dynamic>;
        final id = map['id'] as String;
        return Book.fromMap(id, map);
      }).toList();
    } catch (e) {
      debugPrint('Error loading catalogue cache books: $e');
      return [];
    }
  }

  /// Loads cached categories. Returns empty list if cache does not exist.
  static Future<List<Category>> loadCatalogueCategories() async {
    try {
      final docsPath = await _getAppDocsPath();
      final file = File('$docsPath/$_catalogueFileName');
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      final rawCats = data['categories'] as List<dynamic>? ?? [];

      return rawCats.map((item) {
        final map = item as Map<String, dynamic>;
        return Category.fromMap(map['id'] as String, map);
      }).toList();
    } catch (e) {
      debugPrint('Error loading catalogue cache categories: $e');
      return [];
    }
  }
}
