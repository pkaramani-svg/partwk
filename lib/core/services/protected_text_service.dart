import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/book.dart';
import 'service_locator.dart';
import 'network_guard.dart';

class ContentUnauthenticatedException implements Exception {
  final String message;
  const ContentUnauthenticatedException([this.message = 'Please sign in to access Premium content.']);
  @override
  String toString() => message;
}

class ContentPermissionDeniedException implements Exception {
  final String message;
  const ContentPermissionDeniedException([this.message = 'Premium access required.']);
  @override
  String toString() => message;
}

class UnpublishedLanguageException implements Exception {
  final String language;
  final String message;
  UnpublishedLanguageException(this.language, [String? message])
      : message = message ?? 'Content in this language is currently unavailable.';
  @override
  String toString() => message;
}

class ContentUnavailableException implements Exception {
  final String message;
  const ContentUnavailableException([this.message = 'Content is unavailable.']);
  @override
  String toString() => message;
}

/// Trusted entitlement and content retrieval service for book text summaries.
/// Hydrates a single published language without changing catalogue or audio URLs.
class ProtectedTextService {
  static Future<Book> hydrate(Book book, String language) async {
    // 1. Free titles remain unconditionally accessible without entitlement checks.
    if (!book.isPremium) return book;

    // 2. Publication and visibility checks
    if (!book.isPublished) {
      throw const ContentUnavailableException('This title is not published.');
    }
    if (book.hiddenLanguages.contains(language)) {
      throw UnpublishedLanguageException(language);
    }

    // 3. Entitlement verification: require valid authenticated primary or family entitlement.
    final user = AppLocator.auth.currentUser;
    if (user == null || AppLocator.auth.isGuest) {
      throw const ContentUnauthenticatedException();
    }
    if (!user.isPremium) {
      throw const ContentPermissionDeniedException(
        'Premium subscription or linked family entitlement required.',
      );
    }

    // 4. Verify chapter summaries structure
    final chapters = book.chapterSummaries[language];
    if (chapters == null || chapters.isEmpty) {
      throw const ContentUnavailableException('No chapter summaries available for this language.');
    }

    // 5. If the book already contains full text in memory/catalogue (as in production Firestore),
    // return the entitled book immediately without invoking an un-deployed or failing remote callable.
    final bool alreadyHasText = chapters.any((c) => (c['content'] as String?)?.trim().isNotEmpty == true);
    if (alreadyHasText) {
      return book;
    }

    // 6. If content is missing/migrated to private backend storage, invoke callable.
    final bool hasNet = await NetworkGuard.hasConnection();
    if (!hasNet) {
      throw const ContentUnavailableException('Connect to the internet to load this title.');
    }

    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('getPremiumChapterText')
          .call({'bookId': book.id, 'language': language});
      final text = List<dynamic>.from((response.data as Map)['chapters'] as List);
      if (text.length != chapters.length) {
        throw const ContentUnavailableException('Chapter content mismatch.');
      }
      final data = book.toMap();
      final all = Map<String, dynamic>.from(data['chapterSummaries'] as Map);
      all[language] = List.generate(chapters.length, (i) {
        final chapter = Map<String, dynamic>.from(chapters[i]);
        final privateText = Map<String, dynamic>.from(text[i] as Map);
        chapter['content'] = privateText['content'];
        final segments = chapter['segments'];
        final segmentTexts = privateText['segmentTexts'];
        if (segments is List && segmentTexts is List && segments.length == segmentTexts.length) {
          chapter['segments'] = List.generate(segments.length, (j) =>
              {...Map<String, dynamic>.from(segments[j] as Map), 'text': segmentTexts[j]});
        }
        return chapter;
      });
      data['chapterSummaries'] = all;
      final study = (response.data as Map)['study'];
      if (study is Map) {
        for (final field in ['fiveMinuteSummary', 'fifteenMinuteSummary', 'keyIdeas', 'keyQuotes', 'actionPoints']) {
          if (study.containsKey(field)) {
            final current = Map<String, dynamic>.from(data[field] as Map? ?? {});
            current[language] = study[field];
            data[field] = current;
          }
        }
      }
      return Book.fromMap(book.id, data);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated') {
        throw const ContentUnauthenticatedException();
      } else if (e.code == 'permission-denied') {
        throw ContentPermissionDeniedException(e.message ?? 'Premium access required.');
      } else if (e.code == 'not-found') {
        throw const ContentUnavailableException('Content unavailable for this title.');
      } else if (e.code == 'deadline-exceeded') {
        throw TimeoutException('Request timed out loading book text.');
      } else {
        throw ContentUnavailableException('Unable to retrieve title content (${e.code}).');
      }
    }
  }
}
