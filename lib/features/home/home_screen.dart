import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/book_card.dart';
import '../../models/book.dart';
import '../../models/user.dart';
import '../../models/category.dart';
import '../book/book_details_screen.dart';
import '../profile/paywall_screen.dart';
import '../profile/achievements_screen.dart';
import '../../core/constants/daily_quotes.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Book> _allBooks = [];
  List<Book> _filteredSuggestions = [];
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
    if (mounted) {
      setState(() {
        _allBooks = books;
        _filteredSuggestions = books; // Default shows all
        _isLoading = false;
      });
      _checkForNewBooks(books, categories);
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
    final List<String>? seenBookIds = prefs.getStringList('seen_book_ids');
    
    // First-launch guard
    if (seenBookIds == null) {
      final allIds = books.map((b) => b.id).toList();
      await prefs.setStringList('seen_book_ids', allIds);
      return;
    }
    
    // Find unseen books
    final unseenBooks = books.where((b) => !seenBookIds.contains(b.id)).toList();
    if (unseenBooks.isEmpty) return;
    
    // Update local list of seen books so we don't pop up again
    final updatedIds = List<String>.from(seenBookIds);
    for (final b in unseenBooks) {
      updatedIds.add(b.id);
    }
    await prefs.setStringList('seen_book_ids', updatedIds);
    
    // Get the user's active language code
    if (!mounted) return;
    final localizations = AppLocalizations.of(context);
    final langCode = localizations?.locale.languageCode ?? 'en';
    
    // Find eligible books for the popup
    final eligibleBooks = unseenBooks.where((book) {
      final hasEn = book.hasContentForLanguage('en');
      final hasKu = book.hasContentForLanguage('ku');
      final hasAr = book.hasContentForLanguage('ar');
      final availableInAll3 = hasEn && hasKu && hasAr;
      
      if (availableInAll3) return true;
      return book.hasContentForLanguage(langCode);
    }).toList();
    
    if (eligibleBooks.isEmpty) return;
    
    // Show the first eligible book popup after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showNewBookDialog(eligibleBooks.first, categories, langCode);
      }
    });
  }

  void _showNewBookDialog(Book book, List<Category> categories, String langCode) {
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

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
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
                            onPressed: () => Navigator.of(context).pop(),
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
                              Navigator.of(context).pop();
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
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
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

    // Seeded random book for Daily Digest that changes daily
    final daysSinceEpoch = DateTime.now().difference(DateTime(2024, 1, 1)).inDays;
    final Book? dailyDigestBook = () {
      if (validBooks.isEmpty) return null;
      final user = AppLocator.auth.currentUser;
      final isPremium = user != null && user.isPremium;
      if (!isPremium) {
        return validBooks.firstWhere(
          (b) => b.id == 'atomic-habits',
          orElse: () => validBooks.firstWhere(
            (b) => !b.isPremium,
            orElse: () => validBooks.first,
          ),
        );
      }
      final random = math.Random(daysSinceEpoch);
      return validBooks[random.nextInt(validBooks.length)];
    }();

    // Dynamically build the unlimited quotes list from the database
    final List<Map<String, String>> dbQuotes = [];
    for (var book in _allBooks) {
      final quotesEn = book.getKeyQuotes('en');
      final quotesKu = book.getKeyQuotes('ku');
      final quotesAr = book.getKeyQuotes('ar');
      
      final maxLen = [quotesEn.length, quotesKu.length, quotesAr.length].reduce(math.max);
      for (int i = 0; i < maxLen; i++) {
        dbQuotes.add({
          'en': i < quotesEn.length ? quotesEn[i] : (quotesEn.isNotEmpty ? quotesEn.first : ''),
          'ku': i < quotesKu.length ? quotesKu[i] : (quotesKu.isNotEmpty ? quotesKu.first : ''),
          'ar': i < quotesAr.length ? quotesAr[i] : (quotesAr.isNotEmpty ? quotesAr.first : ''),
          'author': book.getAuthor('en').isNotEmpty ? book.getAuthor('en') : book.getTitle('en'),
        });
      }
    }

    Map<String, String> activeQuote;
    if (dbQuotes.isNotEmpty) {
      activeQuote = dbQuotes[daysSinceEpoch % dbQuotes.length];
    } else {
      activeQuote = DailyQuotes.getTodaysQuote();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0] : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
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
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.translate('notifications_enabled'))),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
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

            // 2. Mood Suggestions Section ("How are you feeling today?")
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
    );
  }
}
