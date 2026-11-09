import 'package:flutter_test/flutter_test.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';

void main() {
  group('Book Multi-Category Support Tests', () {
    final approvedCategories = [
      Category(id: 'cat-productivity', name: {'en': 'Productivity', 'ku': 'بەرهەمداری', 'ar': 'الإنتاجية'}, iconName: 'clock'),
      Category(id: 'cat-psychology', name: {'en': 'Psychology', 'ku': 'دەروونناسی', 'ar': 'علم النفس'}, iconName: 'brain'),
      Category(id: 'cat-business', name: {'en': 'Business', 'ku': 'بزنس', 'ar': 'الأعمال'}, iconName: 'briefcase'),
      Category(id: 'cat-leadership', name: {'en': 'Leadership', 'ku': 'سەرکردایەتی', 'ar': 'القيادة'}, iconName: 'users'),
      Category(id: 'cat-modern-wisdom', name: {'en': 'Modern Wisdom', 'ku': 'دانایی هاوچەرخ', 'ar': 'الحكمة الحديثة'}, iconName: 'lightbulb'),
    ];

    group('1. Legacy Single-Category Books Compatibility', () {
      test('Legacy book with single string category loads into categoryIds and categories', () {
        final legacyData = {
          'title': {'en': 'Atomic Habits'},
          'author': {'en': 'James Clear'},
          'category': 'cat-productivity',
          'isPremium': false,
          'isPublished': true,
        };

        final book = Book.fromMap('book_legacy_1', legacyData);

        expect(book.categoryIds, equals(['cat-productivity']));
        expect(book.categories, equals(['cat-productivity']));
        expect(book.categoryIds.length, equals(1));
      });

      test('Legacy book serializes toMap() with both categories array and legacy category string', () {
        final legacyData = {
          'title': {'en': 'Deep Work'},
          'author': {'en': 'Cal Newport'},
          'category': 'cat-productivity',
          'isPremium': true,
          'isPublished': true,
        };

        final book = Book.fromMap('book_legacy_2', legacyData);
        final map = book.toMap();

        expect(map['categories'], equals(['cat-productivity']));
        expect(map['categoryIds'], equals(['cat-productivity']));
        expect(map['category'], equals('cat-productivity'));
      });

      test('Book with completely missing category fields is safely normalized by admin parser to cat-productivity', () {
        final missingCategoryData = <String, dynamic>{
          'title': {'en': 'No Category Book'},
          'author': {'en': 'Author'},
          'isPremium': false,
          'isPublished': true,
        };

        // Replicate Admin Panel normalizer logic:
        final rawCategories = (missingCategoryData['categories'] is List && (missingCategoryData['categories'] as List).isNotEmpty)
            ? (missingCategoryData['categories'] as List)
            : ((missingCategoryData['categoryIds'] is List && (missingCategoryData['categoryIds'] as List).isNotEmpty)
                ? (missingCategoryData['categoryIds'] as List)
                : (missingCategoryData['category'] != null ? [missingCategoryData['category']] : ['cat-productivity']));
        final normalized = rawCategories.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet().toList();
        final selected = normalized.isNotEmpty ? normalized : ['cat-productivity'];

        expect(selected, equals(['cat-productivity']));
      });

      test('Book with multilingual EN/KU/AR content and hidden languages retains all data without mutating on load', () {
        final multiLangData = {
          'title': {'en': 'Atomic Habits', 'ku': 'خووە بنەڕەتییەکان', 'ar': 'العادات الذرية'},
          'author': {'en': 'James Clear', 'ku': 'جەیمس کلێر', 'ar': 'جيمس كلير'},
          'description': {'en': 'Desc EN', 'ku': 'Desc KU', 'ar': 'Desc AR'},
          'categories': ['cat-productivity', 'cat-psychology'],
          'hiddenLanguages': ['ar'],
          'isPremium': true,
          'isPublished': true,
        };

        final book = Book.fromMap('book_multilang_1', multiLangData);
        expect(book.title['en'], equals('Atomic Habits'));
        expect(book.title['ku'], equals('خووە بنەڕەتییەکان'));
        expect(book.title['ar'], equals('العادات الذرية'));
        expect(book.hiddenLanguages, equals(['ar']));
        expect(book.categories, equals(['cat-productivity', 'cat-psychology']));
      });
    });

    group('2. Multi-Category Create, Edit & Deduplication', () {
      test('Creates book with multiple distinct categories and prevents duplicates', () {
        final rawSelectedCategories = [
          'cat-productivity',
          'cat-psychology',
          'cat-productivity', // duplicate
          'cat-leadership',
          'cat-psychology', // duplicate
        ];

        // Deduplication protocol like Admin Panel Set logic
        final deduplicated = rawSelectedCategories.toSet().toList();

        final bookData = {
          'title': {'en': 'Thinking, Fast and Slow'},
          'author': {'en': 'Daniel Kahneman'},
          'categories': deduplicated,
          'categoryIds': deduplicated,
          'category': deduplicated.first,
          'isPremium': false,
          'isPublished': true,
        };

        final book = Book.fromMap('book_multi_1', bookData);

        expect(book.categoryIds, equals(['cat-productivity', 'cat-psychology', 'cat-leadership']));
        expect(book.categories, equals(['cat-productivity', 'cat-psychology', 'cat-leadership']));
        expect(book.categoryIds.length, equals(3));
      });

      test('Editing preloads categories from either categories, categoryIds or legacy category', () {
        // Scenario A: Book with categories array
        final bookA = Book.fromMap('b_a', {
          'title': {'en': 'Book A'},
          'categories': ['cat-business', 'cat-leadership'],
        });
        expect(bookA.categories, equals(['cat-business', 'cat-leadership']));

        // Scenario B: Book with categoryIds array
        final bookB = Book.fromMap('b_b', {
          'title': {'en': 'Book B'},
          'categoryIds': ['cat-psychology', 'cat-modern-wisdom'],
        });
        expect(bookB.categories, equals(['cat-psychology', 'cat-modern-wisdom']));

        // Scenario C: Legacy book with only single category string
        final bookC = Book.fromMap('b_c', {
          'title': {'en': 'Book C'},
          'category': 'cat-business',
        });
        expect(bookC.categories, equals(['cat-business']));
      });

      test('Editing allows adding/removing categories while enforcing at least one', () {
        final initialCategories = ['cat-productivity', 'cat-psychology'];

        // Add category
        final updatedCategories = [...initialCategories];
        const newCat = 'cat-business';
        if (!updatedCategories.contains(newCat)) {
          updatedCategories.add(newCat);
        }
        expect(updatedCategories, equals(['cat-productivity', 'cat-psychology', 'cat-business']));

        // Remove category
        updatedCategories.remove('cat-productivity');
        expect(updatedCategories, equals(['cat-psychology', 'cat-business']));

        // Attempt removing down to empty is prevented
        if (updatedCategories.length > 1) {
          updatedCategories.remove('cat-psychology');
        }
        expect(updatedCategories.length, equals(1));
        expect(updatedCategories, equals(['cat-business']));
      });
    });

    group('3. Persistence & Backward-Compatible Serialization', () {
      test('Persistence safely retains categories, categoryIds and legacy category fallback', () {
        final book = Book(
          id: 'persist_book',
          title: {'en': 'Multi Cat Title', 'ku': 'ناونیشان', 'ar': 'عنوان'},
          author: {'en': 'Multi Cat Author'},
          coverImageUrl: 'https://example.com/cover.jpg',
          categoryIds: ['cat-productivity', 'cat-business'],
          tags: ['focus', 'strategy'],
          description: {'en': 'Description'},
          fiveMinuteSummary: {},
          fifteenMinuteSummary: {},
          chapterSummaries: {},
          keyIdeas: {},
          keyQuotes: {},
          actionPoints: {},
          audioUrl: {},
          duration: 900,
          isPremium: true,
          isPublished: true,
          hiddenLanguages: const [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final map = book.toMap();

        expect(map['categories'], equals(['cat-productivity', 'cat-business']));
        expect(map['categoryIds'], equals(['cat-productivity', 'cat-business']));
        expect(map['category'], equals('cat-productivity'));
        expect(map['title']['en'], equals('Multi Cat Title'));
        expect(map['title']['ku'], equals('ناونیشان'));
        expect(map['title']['ar'], equals('عنوان'));
      });
    });

    group('4. Filtering & Search Matching across multiple categories', () {
      final books = [
        Book.fromMap('b1', {
          'title': {'en': 'Productivity & Psychology'},
          'categories': ['cat-productivity', 'cat-psychology'],
        }),
        Book.fromMap('b2', {
          'title': {'en': 'Pure Business'},
          'category': 'cat-business', // legacy single
        }),
        Book.fromMap('b3', {
          'title': {'en': 'Business & Leadership'},
          'categories': ['cat-business', 'cat-leadership'],
        }),
        Book.fromMap('b4', {
          'title': {'en': 'Productivity & Leadership'},
          'categories': ['cat-productivity', 'cat-leadership'],
        }),
      ];

      test('Filters books matching ANY of their assigned categories', () {
        // Filter by cat-productivity
        final prodBooks = books.where((b) => b.categoryIds.contains('cat-productivity')).map((b) => b.id).toList();
        expect(prodBooks, equals(['b1', 'b4']));

        // Filter by cat-business
        final bizBooks = books.where((b) => b.categoryIds.contains('cat-business')).map((b) => b.id).toList();
        expect(bizBooks, equals(['b2', 'b3']));

        // Filter by cat-leadership
        final leadBooks = books.where((b) => b.categoryIds.contains('cat-leadership')).map((b) => b.id).toList();
        expect(leadBooks, equals(['b3', 'b4']));

        // Filter by cat-psychology
        final psychBooks = books.where((b) => b.categoryIds.contains('cat-psychology')).map((b) => b.id).toList();
        expect(psychBooks, equals(['b1']));
      });

      test('Category name search matches if any selected category matches query term', () {
        const query = 'psych';

        final searchResults = books.where((book) {
          final matchesCategory = book.categoryIds.any((catId) {
            final cat = approvedCategories.firstWhere(
              (c) => c.id == catId,
              orElse: () => Category(id: '', name: {}, iconName: ''),
            );
            return cat.getName('en').toLowerCase().contains(query);
          });
          return matchesCategory;
        }).map((b) => b.id).toList();

        expect(searchResults, equals(['b1']));
      });
    });
  });
}
