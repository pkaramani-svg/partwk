import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book.dart';
import '../../models/user.dart';
import 'service_locator.dart';

class DownloadedEdition {
  final String bookId;
  final String languageCode;
  final Book book;

  DownloadedEdition({
    required this.bookId,
    required this.languageCode,
    required this.book,
  });

  Map<String, dynamic> toMap() => {
        'bookId': bookId,
        'languageCode': languageCode,
        'book': book.toMap(),
      };

  factory DownloadedEdition.fromMap(Map<String, dynamic> map) {
    final bookData = Map<String, dynamic>.from(map['book'] ?? {});
    return DownloadedEdition(
      bookId: map['bookId'] ?? '',
      languageCode: map['languageCode'] ?? 'en',
      book: Book.fromMap(map['bookId'] ?? '', bookData),
    );
  }
}

class OfflineAvailabilityRepository {
  static const String _userCacheKey = 'cached_user_profile';
  
  static String _getBooksMetadataKey([String? userId]) {
    final uid = userId ?? AppLocator.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      return 'cached_books_metadata_$uid';
    }
    return 'cached_books_metadata';
  }

  static String _getEditionsMetadataKey([String? userId]) {
    final uid = userId ?? AppLocator.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      return 'cached_editions_metadata_$uid';
    }
    return 'cached_editions_metadata';
  }

  static Future<void> cacheUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final map = user.toMap();
    map['id'] = user.id;
    await prefs.setString(_userCacheKey, jsonEncode(map));
  }

  static Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userCacheKey);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr);
      return UserModel.fromMap(map['id'] ?? '', map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userCacheKey);
  }

  static Future<void> cacheEditionMetadata(Book book, String languageCode, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getEditionsMetadataKey(userId);
    List<String> list = prefs.getStringList(key) ?? [];

    final sanitizedBook = Book(
      id: book.id,
      title: book.title,
      author: book.author,
      coverImageUrl: book.coverImageUrlMap,
      categoryIds: book.categoryIds,
      tags: book.tags,
      description: book.description,
      fiveMinuteSummary: {},
      fifteenMinuteSummary: {},
      chapterSummaries: {},
      keyIdeas: {},
      keyQuotes: {},
      actionPoints: {},
      audioUrl: book.audioUrl,
      duration: book.duration,
      isPremium: book.isPremium,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
      hiddenLanguages: book.hiddenLanguages,
    );

    final edition = DownloadedEdition(
      bookId: book.id,
      languageCode: languageCode,
      book: sanitizedBook,
    );

    list.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return map['bookId'] == book.id && map['languageCode'] == languageCode;
      } catch (_) {
        return false;
      }
    });

    list.add(jsonEncode(edition.toMap()));
    await prefs.setStringList(key, list);

    // Also update legacy/book-level metadata for backwards compatibility
    await cacheBookMetadata(book, userId: userId);
  }

  static Future<List<DownloadedEdition>> getCachedEditionsMetadata({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getEditionsMetadataKey(userId);
    List<String> list = prefs.getStringList(key) ?? [];
    if (list.isEmpty && (userId == null || userId.isEmpty)) {
      list = prefs.getStringList('cached_editions_metadata') ?? [];
    }
    final List<DownloadedEdition> editions = [];
    for (var item in list) {
      try {
        final map = jsonDecode(item);
        editions.add(DownloadedEdition.fromMap(map));
      } catch (_) {}
    }
    return editions;
  }

  static Future<void> removeEditionMetadata(String bookId, String languageCode, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getEditionsMetadataKey(userId);
    List<String> list = prefs.getStringList(key) ?? [];
    list.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return map['bookId'] == bookId && map['languageCode'] == languageCode;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(key, list);

    // If no other editions of this book exist, also remove book metadata
    final hasOtherEditions = list.any((item) {
      try {
        final map = jsonDecode(item);
        return map['bookId'] == bookId;
      } catch (_) {
        return false;
      }
    });
    if (!hasOtherEditions) {
      await removeBookMetadata(bookId, userId: userId);
    }
  }

  static Future<void> cacheBookMetadata(Book book, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getBooksMetadataKey(userId);
    List<String> list = prefs.getStringList(key) ?? [];
    
    // Create a copy of the book without the sensitive, protected data
    final sanitizedBook = Book(
      id: book.id,
      title: book.title,
      author: book.author,
      coverImageUrl: book.coverImageUrlMap,
      categoryIds: book.categoryIds,
      tags: book.tags,
      description: book.description,
      // Strip out the text summaries and key ideas/action points/quotes
      fiveMinuteSummary: {},
      fifteenMinuteSummary: {},
      chapterSummaries: {},
      keyIdeas: {},
      keyQuotes: {},
      actionPoints: {},
      audioUrl: book.audioUrl,
      duration: book.duration,
      isPremium: book.isPremium,
      createdAt: book.createdAt,
      updatedAt: book.updatedAt,
      hiddenLanguages: book.hiddenLanguages,
    );

    // Remove if already exists
    list.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return map['id'] == book.id;
      } catch (_) {
        return false;
      }
    });

    list.add(jsonEncode(sanitizedBook.toMap()));
    await prefs.setStringList(key, list);
  }

  static Future<List<Book>> getCachedBooksMetadata({String? userId}) async {
    final editions = await getCachedEditionsMetadata(userId: userId);
    if (editions.isNotEmpty) {
      final seenBookIds = <String>{};
      final List<Book> uniqueBooks = [];
      for (final e in editions) {
        if (!seenBookIds.contains(e.bookId)) {
          seenBookIds.add(e.bookId);
          uniqueBooks.add(e.book);
        }
      }
      return uniqueBooks;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _getBooksMetadataKey(userId);
    List<String> list = prefs.getStringList(key) ?? [];
    if (list.isEmpty && (userId == null || userId.isEmpty)) {
      list = prefs.getStringList('cached_books_metadata') ?? [];
    }
    final List<Book> books = [];
    for (var item in list) {
      try {
        final map = jsonDecode(item);
        books.add(Book.fromMap(map['id'] ?? '', map));
      } catch (_) {}
    }
    return books;
  }

  static Future<void> removeBookMetadata(String bookId, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getBooksMetadataKey(userId);
    List<String> list = prefs.getStringList(key) ?? [];
    list.removeWhere((item) {
      try {
        final map = jsonDecode(item);
        return map['id'] == bookId;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(key, list);

    // Also remove from legacy key if present
    List<String> legacyList = prefs.getStringList('cached_books_metadata') ?? [];
    if (legacyList.isNotEmpty) {
      legacyList.removeWhere((item) {
        try {
          final map = jsonDecode(item);
          return map['id'] == bookId;
        } catch (_) {
          return false;
        }
      });
      await prefs.setStringList('cached_books_metadata', legacyList);
    }
  }
}
