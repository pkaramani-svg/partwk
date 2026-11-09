import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/book.dart';
import '../../models/category.dart';
import '../book/book_details_screen.dart';
import '../book/summary_reader_screen.dart';
import '../audio/audio_player_screen.dart';
import '../profile/paywall_screen.dart';
import '../profile/achievements_screen.dart';
import '../../core/constants/daily_quotes.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';
import '../../core/services/popup_service.dart';
import 'main_navigation.dart';
import '../profile/settings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../core/services/user_notification_service.dart';
import 'new_releases_carousel.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<NewReleasesCarouselState> _newReleasesKey = GlobalKey<NewReleasesCarouselState>();
  List<Book> _allBooks = [];
  List<Book> _filteredSuggestions = [];
  List<Category> _categories = [];
  List<Map<String, String>> _allQuotes = [];
  List<Book> _trendingBooks = [];
  String _selectedMood = 'Ambitious';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final books = await AppLocator.db.fetchBooks();
    final categories = await AppLocator.db.fetchCategories();
    final trending = await AppLocator.db.fetchTrendingBooks(books);
    
    List<Map<String, String>> localQuotes = [];
    try {
      final quotesJsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/audio/quotes.json')
          .timeout(const Duration(milliseconds: 100));
      final List<dynamic> decoded = jsonDecode(quotesJsonString);
      localQuotes = decoded.map((e) => Map<String, String>.from(e.map((k, v) => MapEntry(k.toString(), v.toString())))).toList();
    } catch (e) {
      debugPrint('Error loading quotes: $e');
    }

    if (mounted) {
      setState(() {
        _allBooks = books;
        _filteredSuggestions = books; // Default shows all
        _categories = categories;
        _allQuotes = localQuotes;
        _trendingBooks = trending;
        _isLoading = false;
      });
      _checkForNewBooks(books, categories);
      PopupService.checkAndShowPopups(context);
    }
  }

  String _getDialogText(String key, String langCode) {
    const Map<String, Map<String, String>> strings = {
      'title': {
        'en': 'New Book Available!',
        'ku': 'پەرتووکی نوێ بەردەستە!',
        'ar': 'كتاب جديد متوفر!',
      },
      'by': {
        'en': 'By',
        'ku': 'نووسینی',
        'ar': 'بقلم',
      },
      'category': {
        'en': 'Category',
        'ku': 'پۆل',
        'ar': 'الفئة',
      },
      'languages': {
        'en': 'Languages',
        'ku': 'زمانەکان',
        'ar': 'اللغات',
      },
      'read_listen': {
        'en': 'Read / Listen',
        'ku': 'خوێندنەوە / گوێگرتن',
        'ar': 'قراءة / استماع',
      },
      'close': {
        'en': 'Close',
        'ku': 'داخستن',
        'ar': 'إغلاق',
      },
    };
    return strings[key]?[langCode] ?? strings[key]?['en'] ?? '';
  }

  void _checkForNewBooks(List<Book> books, List<Category> categories) async {
    if (!mounted) return;
    
    final prefs = await SharedPreferences.getInstance();
    final List<String>? seenEditions = prefs.getStringList('seen_book_editions');
    final List<String>? legacySeenBookIds = prefs.getStringList('seen_book_ids');
    
    const supportedLangs = ['en', 'ku', 'ar'];

    // 1. First-Launch / Safe Migration Guard:
    // If seen_book_editions has not been initialized yet:
    if (seenEditions == null) {
      final Set<String> initialEditions = {};
      
      // Seed all visible, published editions across all current books
      for (final b in books) {
        if (!b.isPublished) continue;
        for (final lang in supportedLangs) {
          if (b.hasContentForLanguage(lang)) {
            initialEditions.add('${b.id}_$lang');
          }
        }
      }
      
      await prefs.setStringList('seen_book_editions', initialEditions.toList());
      
      // Preserve/initialize legacy list as well
      if (legacySeenBookIds == null) {
        await prefs.setStringList('seen_book_ids', books.map((b) => b.id).toList());
      }
      return;
    }
    
    // 2. Identify the active language of the user
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final langCode = localizations?.locale.languageCode ?? 'en';
    
    // 3. Find books with unseen editions for the user's current language
    final List<Book> eligibleBooks = [];
    final List<String> newlySeenEditions = [];
    
    for (final book in books) {
      if (!book.isPublished) continue;
      
      // Must have visible, non-hidden content for the user's active language
      if (!book.hasContentForLanguage(langCode)) continue;
      
      final editionKey = '${book.id}_$langCode';
      if (!seenEditions.contains(editionKey)) {
        eligibleBooks.add(book);
        newlySeenEditions.add(editionKey);
      }
    }
    
    if (eligibleBooks.isEmpty) return;
    
    // 4. Update seen book editions so we don't pop up again
    final updatedEditions = List<String>.from(seenEditions)..addAll(newlySeenEditions);
    await prefs.setStringList('seen_book_editions', updatedEditions);
    
    if (legacySeenBookIds != null) {
      final updatedLegacyIds = Set<String>.from(legacySeenBookIds)
        ..addAll(eligibleBooks.map((b) => b.id));
      await prefs.setStringList('seen_book_ids', updatedLegacyIds.toList());
    }
    
    // 5. Show the eligible books popup queue after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showNewBookDialogsQueue(eligibleBooks, categories, langCode);
      }
    });
  }

  void _showNewBookDialogsQueue(List<Book> remainingBooks, List<Category> categories, String langCode) {
    if (remainingBooks.isEmpty) return;
    final book = remainingBooks.first;
    final theme = Theme.of(context);
    
    // Find Category
    final category = categories.firstWhere(
      (c) => book.categoryIds.contains(c.id),
      orElse: () => Category(id: '', name: {'en': ''}, iconName: 'book'),
    );
    final categoryName = category.getName(langCode);

    // Language availability text
    final hasEn = book.hasContentForLanguage('en');
    final hasKu = book.hasContentForLanguage('ku');
    final hasAr = book.hasContentForLanguage('ar');
    final availableInAll3 = hasEn && hasKu && hasAr;
    
    String langInfo;
    if (langCode == 'ku') {
      if (availableInAll3) {
        langInfo = 'بەردەستە بە زمانەکانی کوردی، عەرەبی و ئینگلیزی';
      } else {
        final List<String> langs = [];
        if (hasKu) langs.add('کوردی');
        if (hasAr) langs.add('عەرەبی');
        if (hasEn) langs.add('ئینگلیزی');
        langInfo = 'بەردەستە بە زمانی ${langs.join(' و ')}';
      }
    } else if (langCode == 'ar') {
      if (availableInAll3) {
        langInfo = 'متوفر باللغات الكردية، العربية والإنجليزية';
      } else {
        final List<String> langs = [];
        if (hasKu) langs.add('الكردية');
        if (hasAr) langs.add('العربية');
        if (hasEn) langs.add('الإنجليزية');
        langInfo = 'متوفر باللغة ${langs.join(' و ')}';
      }
    } else {
      if (availableInAll3) {
        langInfo = 'Available in English, Kurdish & Arabic';
      } else {
        final List<String> langs = [];
        if (hasEn) langs.add('English');
        if (hasKu) langs.add('Kurdish');
        if (hasAr) langs.add('Arabic');
        langInfo = 'Available in ${langs.join(', ')}';
      }
    }

    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          elevation: 10,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // New Book Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Text(
                        _getDialogText('title', langCode).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Book Cover with premium shadow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DownloadService.getBookCoverWidget(
                          book,
                          langCode: langCode,
                          height: 180,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Localized Title
                    Text(
                      book.getTitle(langCode),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    
                    // Author
                    Text(
                      '${_getDialogText('by', langCode)} ${book.getAuthor(langCode)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Category & Languages row/wrap
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (categoryName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              categoryName,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Languages info text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.translate,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            langInfo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade700),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: Text(
                              _getDialogText('close', langCode),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop(true);
                              NetworkGuard.guardBookNavigation(context, book.id, () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailsScreen(bookId: book.id),
                                  ),
                                );
                              });
                            },
                            child: Text(
                              _getDialogText('read_listen', langCode),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
              ),
            ],
          ),
        );
      },
    ).then((userClickedAction) {
      if (userClickedAction != true) {
        final nextQueue = remainingBooks.sublist(1);
        if (nextQueue.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showNewBookDialogsQueue(nextQueue, categories, langCode);
          });
        }
      }
    });
  }

  void _selectMood(String moodKey) {
    setState(() {
      _selectedMood = moodKey;
      // Filter recommendations based on mood criteria
      if (moodKey == 'Tired') {
        // Tired users get shorter summaries or mindset content
        _filteredSuggestions = _allBooks.where((b) => b.duration <= 600 || b.tags.contains('productivity')).toList();
      } else if (moodKey == 'Curious') {
        // Curious users get history and culture
        _filteredSuggestions = _allBooks.where((b) => b.categoryIds.contains('cat-history-big-ideas') || b.tags.contains('history') || b.tags.contains('science')).toList();
      } else if (moodKey == 'Stressed') {
        // Stressed users get mindset and productivity
        _filteredSuggestions = _allBooks.where((b) => b.categoryIds.contains('cat-personal-development') || b.tags.contains('focus')).toList();
      } else {
        // Ambitious users get leadership and focus
        _filteredSuggestions = _allBooks;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    final user = AppLocator.auth.currentUser;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final validBooks = _allBooks.where((b) => b.hasContentForLanguage(langCode)).toList();
    final validSuggestions = _filteredSuggestions.where((b) => b.hasContentForLanguage(langCode)).toList();

    // Segmentations for HomeScreen lists
    // 1. New Releases: 21 days (3 weeks) worth of books, falling back to 40 most recent books in system
    final List<Book> uniqueNewReleases = () {
      final threeWeeksAgo = DateTime.now().subtract(const Duration(days: 21));
      var releasesList = validBooks.where((b) => b.createdAt.isAfter(threeWeeksAgo)).toList();
      releasesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (releasesList.isEmpty) {
        releasesList = List<Book>.from(validBooks)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      return releasesList.take(40).toList();
    }();

    // 2. Trending: Dynmically computed trending books based on real user actions
    final uniqueTrending = _trendingBooks.take(40).toList();

    // 3. Recommended: personalized based on user interaction categories and interests
    final List<Book> uniqueRecommended = () {
      final userReadBookIds = <String>{};
      if (user != null) {
        userReadBookIds.addAll(user.savedBooks);
        userReadBookIds.addAll(user.completedBooks);
        userReadBookIds.addAll(user.likedBooks);
        userReadBookIds.addAll(user.readingProgress.keys);
      }

      final userCategories = <String>{};
      for (final bookId in userReadBookIds) {
        final b = validBooks.firstWhere((book) => book.id == bookId, orElse: () => validBooks.first);
        if (b.id == bookId) {
          userCategories.addAll(b.categoryIds);
        }
      }

      final candidateBooks = validBooks.where((b) {
        final matchesCategory = b.categoryIds.any((catId) => userCategories.contains(catId));
        final notYetRead = !userReadBookIds.contains(b.id);
        return matchesCategory && notYetRead;
      }).toList();

      if (candidateBooks.length < 20 && user != null && user.interests.isNotEmpty) {
        final interestCandidates = validBooks.where((b) =>
            b.categoryIds.any((catId) => user.interests.contains(catId)) &&
            !userReadBookIds.contains(b.id) &&
            !candidateBooks.contains(b)
        ).toList();
        candidateBooks.addAll(interestCandidates);
      }

      if (candidateBooks.length < 20) {
        final generalCandidates = validBooks.where((b) =>
            !userReadBookIds.contains(b.id) && !candidateBooks.contains(b)
        ).toList();
        candidateBooks.addAll(generalCandidates);
      }

      if (candidateBooks.isEmpty) {
        candidateBooks.addAll(validBooks);
      }

      final daysSinceEpoch = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
      final math.Random r = math.Random(daysSinceEpoch + 200);
      final listCopy = List<Book>.from(candidateBooks);
      listCopy.shuffle(r);
      return listCopy.toSet().toList().take(20).toList();
    }();

    final bool isUserPremium = user != null && user.isPremium && !AppLocator.auth.isGuest;
    final List<Book> basePool = isUserPremium
        ? validBooks
        : validBooks.where((b) => !b.isPremium && b.isPublished && !b.hiddenLanguages.contains(langCode)).toList();

    final Book? featuredSpecialBook = () {
      if (basePool.isEmpty) {
        return validBooks.isNotEmpty ? validBooks.firstWhere((b) => !b.isPremium && b.isPublished && !b.hiddenLanguages.contains(langCode), orElse: () => validBooks.first) : null;
      }

      // Collect user's read/liked/saved book IDs to analyze preferences
      final userReadBookIds = <String>{};
      if (user != null) {
        userReadBookIds.addAll(user.savedBooks);
        userReadBookIds.addAll(user.completedBooks);
        userReadBookIds.addAll(user.likedBooks);
        userReadBookIds.addAll(user.readingProgress.keys);
      }

      // 1. Identify categories from books the user has interacted with
      final userCategories = <String>{};
      for (final bookId in userReadBookIds) {
        final b = basePool.firstWhere((book) => book.id == bookId, orElse: () => basePool.first);
        if (b.id == bookId) {
          userCategories.addAll(b.categoryIds);
        }
      }

      // 2. Filter candidate books from matching categories that the user hasn't completed/read yet
      final candidateBooks = basePool.where((b) {
        final matchesCategory = b.categoryIds.any((catId) => userCategories.contains(catId));
        final notYetRead = !userReadBookIds.contains(b.id);
        return matchesCategory && notYetRead;
      }).toList();

      // 3. Fallback candidates to user's interests if candidate list is empty
      if (candidateBooks.isEmpty && user != null && user.interests.isNotEmpty) {
        candidateBooks.addAll(
          basePool.where((b) => b.categoryIds.any((catId) => user.interests.contains(catId)) && !userReadBookIds.contains(b.id))
        );
      }

      // 4. Default fallback: pick a popular book they haven't read yet
      if (candidateBooks.isEmpty) {
        candidateBooks.addAll(
          basePool.where((b) => !userReadBookIds.contains(b.id))
        );
      }

      // 5. If everything has been read or list is empty, default to basePool
      if (candidateBooks.isEmpty) {
        candidateBooks.addAll(basePool);
      }

      // 6. Seeded random selection that changes daily to keep the dashboard fresh
      final daysSinceEpoch = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
      final seedIndex = daysSinceEpoch % candidateBooks.length;
      return candidateBooks[seedIndex];
    }();

    // Seeded random book for Daily Digest that changes daily
    final daysSinceEpoch = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final Book? dailyDigestBook = () {
      if (validBooks.isEmpty) return null;
      if (!isUserPremium) {
        final freeBooks = validBooks.where((b) => !b.isPremium && b.isPublished && !b.hiddenLanguages.contains(langCode)).toList();
        if (freeBooks.isNotEmpty) {
          final seed = daysSinceEpoch % freeBooks.length;
          return freeBooks[seed];
        }
        return validBooks.first;
      }
      final random = math.Random(daysSinceEpoch);
      return validBooks[random.nextInt(validBooks.length)];
    }();

    // Dynamically build the combined quotes list from assets and database
    final List<Map<String, String>> combinedQuotes = [];
    combinedQuotes.addAll(_allQuotes);

    for (var book in _allBooks) {
      final quotesEn = book.getKeyQuotes('en');
      final quotesKu = book.getKeyQuotes('ku');
      final quotesAr = book.getKeyQuotes('ar');
      
      final maxLen = [quotesEn.length, quotesKu.length, quotesAr.length].reduce(math.max);
      for (int i = 0; i < maxLen; i++) {
        combinedQuotes.add({
          'en': i < quotesEn.length ? quotesEn[i] : (quotesEn.isNotEmpty ? quotesEn.first : ''),
          'ku': i < quotesKu.length ? quotesKu[i] : (quotesKu.isNotEmpty ? quotesKu.first : ''),
          'ar': i < quotesAr.length ? quotesAr[i] : (quotesAr.isNotEmpty ? quotesAr.first : ''),
          'author': book.getAuthor('en').isNotEmpty ? book.getAuthor('en') : book.getTitle('en'),
        });
      }
    }

    // Shuffle the combined quotes list deterministically with a fixed seed (e.g. 1001)
    // so it doesn't change on rebuild, but cycles through all without repeats!
    if (combinedQuotes.isNotEmpty) {
      final math.Random r = math.Random(1001);
      combinedQuotes.shuffle(r);
    }

    Map<String, String> activeQuote;
    if (combinedQuotes.isNotEmpty) {
      activeQuote = combinedQuotes[daysSinceEpoch % combinedQuotes.length];
    } else {
      activeQuote = DailyQuotes.getTodaysQuote();
    }

    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: AppLocator.auth,
          builder: (context, _) {
            final user = AppLocator.auth.currentUser;
            return GestureDetector(
              onTap: () {
                NavigationController.selectTab(3);
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondary,
                    backgroundImage: user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty
                        ? (user.profilePictureUrl!.startsWith('assets/')
                            ? AssetImage(user.profilePictureUrl!) as ImageProvider
                            : NetworkImage(user.profilePictureUrl!))
                        : null,
                    child: user?.profilePictureUrl == null || user!.profilePictureUrl!.isEmpty
                        ? Text(
                            user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${localizations.translate('home')}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        user?.name ?? 'Guest Reader',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          // Quick premium upgrade if free
          if (user != null && !user.isPremium)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ElevatedButton(
                onPressed: () async {
                  final hasInternet = await NetworkGuard.hasConnection();
                  if (!hasInternet) {
                    if (context.mounted) {
                      NetworkGuard.showOfflineDialog(context, message: 'Please connect to the internet to upgrade to PRO.');
                    }
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaywallScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('PRO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: localizations.translate('settings'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0) {
            if (notification is ScrollStartNotification && notification.dragDetails != null) {
              _newReleasesKey.currentState?.handleExternalScrollStart();
            } else if (notification is ScrollEndNotification) {
              _newReleasesKey.currentState?.handleExternalScrollEnd();
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Daily Digest Section
            if (dailyDigestBook != null) ...[
              Text(
                localizations.translate('daily_digest'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  NetworkGuard.guardBookNavigation(context, dailyDigestBook.id, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookDetailsScreen(bookId: dailyDigestBook.id),
                      ),
                    );
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 220,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.black, // Dark background to frame the contain image
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: DownloadService.getBookCoverWidget(
                            dailyDigestBook,
                            langCode: langCode,
                            height: 220,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    localizations.translate('digest').toUpperCase(),
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  (() {
                                    final secs = dailyDigestBook.getDurationForLanguage(langCode);
                                    if (secs == 0) {
                                      if (langCode == 'ku') return 'تەنها دەق';
                                      if (langCode == 'ar') return 'نص فقط';
                                      return 'Text only';
                                    }
                                    return '${(secs / 60).round()} ${localizations.translate('min_read')}';
                                  })(),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              dailyDigestBook.getTitle(langCode),
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dailyDigestBook.getAuthor(langCode),
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dailyDigestBook.getDescription(langCode),
                              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 2. New Releases Section
            if (uniqueNewReleases.isNotEmpty) ...[
              Text(
                localizations.translate('new_releases'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              NewReleasesCarousel(
                key: _newReleasesKey,
                books: uniqueNewReleases,
                langCode: langCode,
                theme: theme,
              ),
              const SizedBox(height: 24),
            ],

            // 3. Recommended For You Section
            if (uniqueRecommended.isNotEmpty) ...[
              Text(
                localizations.translate('recommended_for_you'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHorizontalBookList(context, uniqueRecommended, langCode, theme),
              const SizedBox(height: 24),
            ],

            // 4. Special Featured Book Section
            if (featuredSpecialBook != null) ...[
              _buildSpecialFeaturedBook(context, featuredSpecialBook, _categories, langCode, localizations, theme),
              const SizedBox(height: 24),
            ],

            // 4. Trending Summaries Section
            if (uniqueTrending.isNotEmpty) ...[
              Text(
                localizations.translate('trending'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHorizontalBookList(context, uniqueTrending, langCode, theme),
              const SizedBox(height: 24),
            ],

            // 5. Mood Suggestions Section ("How are you feeling today?")
            Text(
              localizations.translate('mood_suggestions'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Ambitious', 'Tired', 'Curious', 'Stressed'].map((mood) {
                  final isSelected = _selectedMood == mood;
                  String displayMood = mood;
                  if (mood == 'Ambitious') displayMood = localizations.translate('mood_ambitious');
                  if (mood == 'Tired') displayMood = localizations.translate('mood_tired');
                  if (mood == 'Curious') displayMood = localizations.translate('mood_curious');
                  if (mood == 'Stressed') displayMood = localizations.translate('mood_stressed');

                  return GestureDetector(
                    onTap: () => _selectMood(mood),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.secondary : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.secondary : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        displayMood,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: validSuggestions.length,
                itemBuilder: (context, index) {
                  final book = validSuggestions[index];
                  return GestureDetector(
                    onTap: () {
                      NetworkGuard.guardBookNavigation(context, book.id, () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookDetailsScreen(bookId: book.id),
                          ),
                        );
                      });
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsetsDirectional.only(end: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: DownloadService.getBookCoverWidget(
                              book,
                              langCode: langCode,
                              height: 180,
                              width: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.getTitle(langCode),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            book.getAuthor(langCode),
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // 3. One Idea Per Day Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        localizations.translate('one_idea_per_day'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activeQuote[langCode] ?? activeQuote['en']!,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '- ${activeQuote['author']}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Learning Streak Box Section
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 40, color: Colors.orangeAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.translate('streak_title'),
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            localizations.translate('streak_desc'),
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${user?.streakCount ?? 0} ${localizations.translate('days_streak')}',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHorizontalBookList(
    BuildContext context,
    List<Book> books,
    String langCode,
    ThemeData theme,
  ) {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return GestureDetector(
            onTap: () {
              NetworkGuard.guardBookNavigation(context, book.id, () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BookDetailsScreen(bookId: book.id),
                  ),
                );
              });
            },
            child: Container(
              width: 120,
              margin: const EdgeInsetsDirectional.only(end: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: DownloadService.getBookCoverWidget(
                        book,
                        langCode: langCode,
                        height: 175,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.getTitle(langCode),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.getAuthor(langCode),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpecialFeaturedBook(
    BuildContext context,
    Book book,
    List<Category> categories,
    String langCode,
    AppLocalizations localizations,
    ThemeData theme,
  ) {
    final category = categories.firstWhere(
      (c) => book.categoryIds.contains(c.id),
      orElse: () => Category(id: '', name: {'en': ''}, iconName: 'book'),
    );
    final categoryName = category.getName(langCode);

    final coverUrl = book.getCoverImageUrl(langCode);
    final globalAudioUrl = book.getAudioUrl(langCode);
    final chapters = book.getChapterSummaries(langCode);

    final heading = langCode == 'ku'
        ? 'پێشنیاری تایبەتی خوێنەران'
        : (langCode == 'ar' ? 'ترشيح القراء المميز' : 'Featured Reader Pick');

    final readText = langCode == 'ku' ? 'خوێندنەوە' : (langCode == 'ar' ? 'قراءة' : 'Read');
    final listenText = langCode == 'ku' ? 'گوێگرتن' : (langCode == 'ar' ? 'استماع' : 'Listen');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  theme.cardTheme.color ?? theme.colorScheme.surface,
                  (theme.cardTheme.color ?? theme.colorScheme.surface).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: DownloadService.getBookCoverWidget(
                          book,
                          langCode: langCode,
                          height: 160,
                          width: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categoryName.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                categoryName,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            book.getTitle(langCode),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            book.getAuthor(langCode),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.getDescription(langCode),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade400,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.secondary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          NetworkGuard.guardBookNavigation(context, book.id, () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SummaryReaderScreen(bookId: book.id),
                              ),
                            );
                          });
                        },
                        child: Text(
                          readText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                        ),
                        onPressed: () {
                          NetworkGuard.guardBookNavigation(context, book.id, () {
                            final audioService = AppLocator.audio;
                            final isCurrentBook = audioService.currentBookId == book.id && audioService.currentLangCode == langCode;

                            int initialIndex = 0;
                            int startPos = 0;

                            if (isCurrentBook) {
                              initialIndex = audioService.currentChapterIndex;
                              startPos = audioService.position.inSeconds;
                              if (!audioService.isPlaying) {
                                audioService.resume();
                              }
                            } else {
                              var progress = AppLocator.auth.currentUser?.listeningProgress['${book.id}_$langCode'];
                              if (progress == null) {
                                final prefix = '${book.id}_';
                                final matchingKey = AppLocator.auth.currentUser?.listeningProgress.keys.firstWhere(
                                  (k) => k.startsWith(prefix),
                                  orElse: () => '',
                                ) ?? '';
                                if (matchingKey.isNotEmpty) {
                                  progress = AppLocator.auth.currentUser?.listeningProgress[matchingKey];
                                }
                              }
                              if (progress != null) {
                                initialIndex = progress['chapterIndex'] ?? 0;
                                startPos = progress['positionSeconds'] ?? 0;
                              }

                              audioService.play(
                                book.id,
                                langCode,
                                book.getTitle(langCode),
                                coverUrl,
                                globalAudioUrl,
                                chapters,
                                startIndex: initialIndex,
                                startPosition: startPos,
                                bookDurationSecs: book.getDurationForLanguage(langCode),
                                isPremium: book.isPremium,
                              );
                            }

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AudioPlayerScreen(
                                  bookId: book.id,
                                  langCode: langCode,
                                  bookTitle: book.getTitle(langCode),
                                  coverUrl: coverUrl,
                                  globalAudioUrl: globalAudioUrl,
                                  chapters: chapters,
                                  initialChapterIndex: initialIndex,
                                  initialPositionSecs: startPos,
                                  bookDurationSecs: book.getDurationForLanguage(langCode),
                                  isPremium: book.isPremium,
                                ),
                              ),
                            );
                          });
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              listenText,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
