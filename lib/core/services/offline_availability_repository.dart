import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/book.dart';
import '../../models/user.dart';

class OfflineAvailabilityRepository {
  static const String _userCacheKey = 'cached_user_profile';
  static const String _booksMetadataKey = 'cached_books_metadata';

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

  static Future<void> cacheBookMetadata(Book book) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_booksMetadataKey) ?? [];
    
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
      final map = jsonDecode(item);
      return map['id'] == book.id;
    });

    list.add(jsonEncode(sanitizedBook.toMap()));
    await prefs.setStringList(_booksMetadataKey, list);
  }

  static Future<List<Book>> getCachedBooksMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_booksMetadataKey) ?? [];
    final List<Book> books = [];
    for (var item in list) {
      try {
        final map = jsonDecode(item);
        books.add(Book.fromMap(map['id'] ?? '', map));
      } catch (_) {}
    }
    return books;
  }

  static Future<void> removeBookMetadata(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList(_booksMetadataKey) ?? [];
    list.removeWhere((item) {
      final map = jsonDecode(item);
      return map['id'] == bookId;
    });
    await prefs.setStringList(_booksMetadataKey, list);
  }
}
