import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';

Book _createMockBook({
  required String id,
  required Map<String, String> title,
  Map<String, String> author = const {'en': 'Test Author', 'ku': 'نووسەری تاقیکاری', 'ar': 'مؤلف تجريبي'},
  List<String> categoryIds = const ['cat-productivity'],
  List<String> hiddenLanguages = const [],
  bool isPublished = true,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    coverImageUrl: 'https://example.com/cover.jpg',
    categoryIds: categoryIds,
    tags: const [],
    description: const {'en': 'Test Description'},
    fiveMinuteSummary: const {},
    fifteenMinuteSummary: const {},
    chapterSummaries: const {},
    keyIdeas: const {},
    keyQuotes: const {},
    actionPoints: const {},
    audioUrl: const {},
    duration: 900,
    isPremium: false,
    isPublished: isPublished,
    hiddenLanguages: hiddenLanguages,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// Helper replicating HomeScreen._checkForNewBooks edition-based logic
Future<List<Book>> simulateCheckForNewBooks({
  required SharedPreferences prefs,
  required List<Book> books,
  required String userLangCode,
}) async {
  final List<String>? seenEditions = prefs.getStringList('seen_book_editions');
  final List<String>? legacySeenBookIds = prefs.getStringList('seen_book_ids');
  const supportedLangs = ['en', 'ku', 'ar'];

  // 1. First-Launch / Safe Migration Guard:
  if (seenEditions == null) {
    final Set<String> initialEditions = {};
    for (final b in books) {
      if (!b.isPublished) continue;
      for (final lang in supportedLangs) {
        if (b.hasContentForLanguage(lang)) {
          initialEditions.add('${b.id}_$lang');
        }
      }
    }
    await prefs.setStringList('seen_book_editions', initialEditions.toList());
    if (legacySeenBookIds == null) {
      await prefs.setStringList('seen_book_ids', books.map((b) => b.id).toList());
    }
    return []; // No flood on initial run
  }

  // 2. Find eligible books for user's active language
  final List<Book> eligibleBooks = [];
  final List<String> newlySeenEditions = [];

  for (final book in books) {
    if (!book.isPublished) continue;
    if (!book.hasContentForLanguage(userLangCode)) continue;

    final editionKey = '${book.id}_$userLangCode';
    if (!seenEditions.contains(editionKey)) {
      eligibleBooks.add(book);
      newlySeenEditions.add(editionKey);
    }
  }

  if (eligibleBooks.isEmpty) return [];

  // 3. Mark as seen
  final updatedEditions = List<String>.from(seenEditions)..addAll(newlySeenEditions);
  await prefs.setStringList('seen_book_editions', updatedEditions);

  if (legacySeenBookIds != null) {
    final updatedLegacy = Set<String>.from(legacySeenBookIds)..addAll(eligibleBooks.map((b) => b.id));
    await prefs.setStringList('seen_book_ids', updatedLegacy.toList());
  }

  return eligibleBooks;
}

String computeLanguageAvailabilityText(Book book, String langCode) {
  final hasEn = book.hasContentForLanguage('en');
  final hasKu = book.hasContentForLanguage('ku');
  final hasAr = book.hasContentForLanguage('ar');
  final availableInAll3 = hasEn && hasKu && hasAr;

  if (langCode == 'ku') {
    if (availableInAll3) return 'بەردەستە بە زمانەکانی کوردی، عەرەبی و ئینگلیزی';
    final List<String> langs = [];
    if (hasKu) langs.add('کوردی');
    if (hasAr) langs.add('عەرەبی');
    if (hasEn) langs.add('ئینگلیزی');
    return 'بەردەستە بە زمانی ${langs.join(' و ')}';
  } else if (langCode == 'ar') {
    if (availableInAll3) return 'متوفر باللغات الكردية، العربية والإنجليزية';
    final List<String> langs = [];
    if (hasKu) langs.add('الكردية');
    if (hasAr) langs.add('العربية');
    if (hasEn) langs.add('الإنجليزية');
    return 'متوفر باللغة ${langs.join(' و ')}';
  } else {
    if (availableInAll3) return 'Available in English, Kurdish & Arabic';
    final List<String> langs = [];
    if (hasEn) langs.add('English');
    if (hasKu) langs.add('Kurdish');
    if (hasAr) langs.add('Arabic');
    return 'Available in ${langs.join(', ')}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Automatic "New Book Available" Hardening & Edition Tracking Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Hidden-language exclusion: hasContentForLanguage and availability text ignore hidden languages', () {
      final book = _createMockBook(
        id: 'steve-jobs',
        title: {'en': 'Steve Jobs', 'ku': 'ستیڤ جۆبز', 'ar': 'ستيف جوبز'},
        hiddenLanguages: ['ku'], // Kurdish is hidden
      );

      // Kurdish must be treated as unavailable everywhere
      expect(book.hasContentForLanguage('en'), isTrue);
      expect(book.hasContentForLanguage('ar'), isTrue);
      expect(book.hasContentForLanguage('ku'), isFalse);

      // Language availability text must never advertise Kurdish
      final enText = computeLanguageAvailabilityText(book, 'en');
      expect(enText, equals('Available in English, Arabic'));
      expect(enText.contains('Kurdish'), isFalse);

      final arText = computeLanguageAvailabilityText(book, 'ar');
      expect(arText, equals('متوفر باللغة العربية و الإنجليزية'));
      expect(arText.contains('الكردية'), isFalse);
    });

    test('2. Single-language publication targeting: English book only announces to English users', () async {
      final prefs = await SharedPreferences.getInstance();
      // Pre-seed system as initialized with no books
      await prefs.setStringList('seen_book_editions', []);

      final englishOnlyBook = _createMockBook(
        id: 'deep-work',
        title: {'en': 'Deep Work'},
      );

      // Kurdish user check -> excluded
      final kuAnnouncements = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [englishOnlyBook],
        userLangCode: 'ku',
      );
      expect(kuAnnouncements, isEmpty);

      // Arabic user check -> excluded
      final arAnnouncements = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [englishOnlyBook],
        userLangCode: 'ar',
      );
      expect(arAnnouncements, isEmpty);

      // English user check -> included once
      final enAnnouncements = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [englishOnlyBook],
        userLangCode: 'en',
      );
      expect(enAnnouncements.length, equals(1));
      expect(enAnnouncements.first.id, equals('deep-work'));

      // Check edition key is recorded
      expect(prefs.getStringList('seen_book_editions'), contains('deep-work_en'));
      expect(prefs.getStringList('seen_book_editions')!.contains('deep-work_ku'), isFalse);
    });

    test('3. Later Kurdish publication for existing book: Kurdish user gets announcement, English user does not', () async {
      final prefs = await SharedPreferences.getInstance();
      // Setup state where English edition was already seen
      await prefs.setStringList('seen_book_editions', ['atomic-habits_en']);

      // Admin adds Kurdish edition to the existing atomic-habits book
      final updatedBook = _createMockBook(
        id: 'atomic-habits',
        title: {'en': 'Atomic Habits', 'ku': 'خووە ئەتۆمییەکان'},
      );

      // English user opens app -> already seen English, zero popups
      final enResult = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [updatedBook],
        userLangCode: 'en',
      );
      expect(enResult, isEmpty);

      // Kurdish user opens app -> sees the newly available Kurdish edition once
      final kuResult = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [updatedBook],
        userLangCode: 'ku',
      );
      expect(kuResult.length, equals(1));
      expect(kuResult.first.id, equals('atomic-habits'));

      // Now atomic-habits_ku is recorded
      expect(prefs.getStringList('seen_book_editions'), containsAll(['atomic-habits_en', 'atomic-habits_ku']));

      // Second check for Kurdish user -> no repeat
      final kuResultSecond = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [updatedBook],
        userLangCode: 'ku',
      );
      expect(kuResultSecond, isEmpty);
    });

    test('4. Language-switch behavior: user changing language sees newly available edition once, never repeatedly', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seen_book_editions', []);

      final multilingualBook = _createMockBook(
        id: 'sapiens',
        title: {'en': 'Sapiens', 'ku': 'مرۆڤی ژیر'},
      );

      // User in English sees Sapiens (English edition)
      final enResult = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [multilingualBook],
        userLangCode: 'en',
      );
      expect(enResult.length, equals(1));
      expect(prefs.getStringList('seen_book_editions'), contains('sapiens_en'));

      // User changes app language to Kurdish in Settings
      final kuResult = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [multilingualBook],
        userLangCode: 'ku',
      );
      expect(kuResult.length, equals(1));
      expect(prefs.getStringList('seen_book_editions'), contains('sapiens_ku'));

      // User changes back to English -> zero popups
      final enResultAgain = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [multilingualBook],
        userLangCode: 'en',
      );
      expect(enResultAgain, isEmpty);

      // Reopening in Kurdish -> zero popups
      final kuResultAgain = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [multilingualBook],
        userLangCode: 'ku',
      );
      expect(kuResultAgain, isEmpty);
    });

    test('5. No repeat after edits: modifying existing content does not re-trigger announcement', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('seen_book_editions', ['book-1_en']);

      // Edited title / updated book
      final editedBook = _createMockBook(
        id: 'book-1',
        title: {'en': 'Book 1 Revised Edition'},
      );

      final result = await simulateCheckForNewBooks(
        prefs: prefs,
        books: [editedBook],
        userLangCode: 'en',
      );
      expect(result, isEmpty);
    });

    test('6. Safe migration of legacy seen_book_ids: existing users are not flooded', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate existing user who has legacy seen_book_ids with historic books
      final legacyIds = List.generate(50, (i) => 'historic-book-$i');
      await prefs.setStringList('seen_book_ids', legacyIds);
      expect(prefs.getStringList('seen_book_editions'), isNull);

      final historicBooks = List.generate(
        50,
        (i) => _createMockBook(
          id: 'historic-book-$i',
          title: {'en': 'Title $i', 'ku': 'سەردێڕ $i'},
        ),
      );

      // Upgraded app launch
      final queued = await simulateCheckForNewBooks(
        prefs: prefs,
        books: historicBooks,
        userLangCode: 'en',
      );

      // Zero popups queued on migration
      expect(queued, isEmpty);

      // seen_book_editions is seeded with all existing editions
      final migratedEditions = prefs.getStringList('seen_book_editions')!;
      expect(migratedEditions.length, equals(100)); // 50 * 2 languages
      expect(migratedEditions, contains('historic-book-0_en'));
      expect(migratedEditions, contains('historic-book-0_ku'));

      // Subsequent check remains empty
      final secondCheck = await simulateCheckForNewBooks(
        prefs: prefs,
        books: historicBooks,
        userLangCode: 'en',
      );
      expect(secondCheck, isEmpty);
    });

    test('7. No first-launch flood for 152 existing books on clean install', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('seen_book_editions'), isNull);
      expect(prefs.getStringList('seen_book_ids'), isNull);

      // Simulate all 152 existing production books
      final existing152Books = List.generate(
        152,
        (i) => _createMockBook(
          id: 'prod-book-$i',
          title: {'en': 'Book $i', 'ku': 'پەرتووک $i', 'ar': 'كتاب $i'},
        ),
      );

      final firstLaunchResult = await simulateCheckForNewBooks(
        prefs: prefs,
        books: existing152Books,
        userLangCode: 'en',
      );

      // Must be strictly 0 popups
      expect(firstLaunchResult, isEmpty);

      // Must have seeded all 152 * 3 = 456 editions
      final seenEditions = prefs.getStringList('seen_book_editions')!;
      expect(seenEditions.length, equals(456));

      // Now add 1 brand new book 153 in English
      final withBrandNewBook = [
        ...existing152Books,
        _createMockBook(
          id: 'prod-book-153',
          title: {'en': 'Brand New Book 153'},
        ),
      ];

      // Second launch -> only the 1 brand new book is announced
      final secondLaunchResult = await simulateCheckForNewBooks(
        prefs: prefs,
        books: withBrandNewBook,
        userLangCode: 'en',
      );
      expect(secondLaunchResult.length, equals(1));
      expect(secondLaunchResult.first.id, equals('prod-book-153'));
    });
  });
}
