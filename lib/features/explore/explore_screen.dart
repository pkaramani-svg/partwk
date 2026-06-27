import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/category.dart';
import '../../models/learning_path.dart';
import '../../models/book.dart';
import '../learning/learning_path_screen.dart';
import '../book/book_details_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({Key? key}) : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<Category> _categories = [];
  List<LearningPath> _paths = [];
  List<Book> _books = [];
  List<FeaturedPlaylist> _featuredPlaylists = [];
  String? _selectedCategoryId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final cats = await AppLocator.db.fetchCategories();
    final paths = await AppLocator.db.fetchLearningPaths();
    final books = await AppLocator.db.fetchBooks();
    final playlists = _generatePlaylists(books);
    if (mounted) {
      setState(() {
        _categories = cats;
        _paths = paths;
        _books = books;
        _featuredPlaylists = playlists;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final langBooks = _books.where((b) => b.hasContentForLanguage(langCode)).toList();
    final filteredBooks = _selectedCategoryId == null
        ? langBooks
        : langBooks.where((b) => b.categoryIds.contains(_selectedCategoryId)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('explore')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category horizontal slider
            Text(
              localizations.translate('categories'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _selectedCategoryId == null ? theme.colorScheme.secondary : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Text(
                        langCode == 'ku' ? 'هەمووی' : (langCode == 'ar' ? 'الكل' : 'All'),
                        style: TextStyle(
                          color: _selectedCategoryId == null ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ..._categories.map((cat) {
                    final isSelected = _selectedCategoryId == cat.id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategoryId = cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.secondary : theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Text(
                          cat.getName(langCode),
                          style: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Filtered Books List
            Text(
              _selectedCategoryId == null 
                  ? localizations.translate('trending') ?? 'Trending Summaries' 
                  : _categories.firstWhere((c) => c.id == _selectedCategoryId).getName(langCode),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filteredBooks.length,
                itemBuilder: (context, index) {
                  final book = filteredBooks[index];
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
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 180,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.black12,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: DownloadService.getBookCoverWidget(
                                book,
                                langCode: langCode,
                                height: 180,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            book.getTitle(langCode),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
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

            // Playlists / Collections
            if (_featuredPlaylists.isNotEmpty) ...[
              Text(
                langCode == 'ku' ? 'لیستە هەڵبژێردراوەکان' : (langCode == 'ar' ? 'قوائم التشغيل المميزة' : 'Featured Playlists'),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPlaylistCard(
                      context,
                      playlist: _featuredPlaylists[0],
                      langCode: langCode,
                    ),
                  ),
                  if (_featuredPlaylists.length > 1) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPlaylistCard(
                        context,
                        playlist: _featuredPlaylists[1],
                        langCode: langCode,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 28),

            // Structured Learning Paths
            Text(
              localizations.translate('learning_paths'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paths.length,
              itemBuilder: (context, index) {
                final path = _paths[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.school, color: theme.colorScheme.secondary),
                    ),
                    title: Text(
                      path.getTitle(langCode),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          path.getDescription(langCode),
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (() {
                            final count = path.bookIds.length;
                            if (langCode == 'ku') {
                              return '$count کورتەکراوە • بڕوانامەی لەگەڵە';
                            } else if (langCode == 'ar') {
                              return '$count ملخصات • تتضمن شهادة';
                            } else {
                              return '$count summaries • Certificate included';
                            }
                          })(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LearningPathScreen(path: path),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(
    BuildContext context, {
    required FeaturedPlaylist playlist,
    required String langCode,
  }) {
    final theme = Theme.of(context);
    final color = playlist.color;
    return GestureDetector(
      onTap: () => _showPlaylistBottomSheet(context, playlist, langCode),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(playlist.icon, color: color, size: 32),
            const SizedBox(height: 16),
            Text(
              playlist.getTitle(langCode),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              (() {
                final count = playlist.books.length;
                if (langCode == 'ku') return '$count کورتەکراوە';
                if (langCode == 'ar') return '$count ملخصات';
                return '$count summaries';
              })(),
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  List<FeaturedPlaylist> _generatePlaylists(List<Book> books) {
    if (books.isEmpty) return [];

    final List<FeaturedPlaylist> candidates = [];

    // 1. Mindset & Growth
    final mindsetBooks = books.where((b) => 
      b.categoryIds.contains('cat-personal-development') || 
      b.categoryIds.contains('cat-psychology')
    ).toList();
    if (mindsetBooks.length >= 2) {
      candidates.add(FeaturedPlaylist(
        title: {
          'en': 'Mindset & Growth',
          'ku': 'بیرکردنەوە و گەشەکردن',
          'ar': 'العقلية والنمو',
        },
        description: {
          'en': 'Reprogram your brain, habits, and mindset for continuous self-improvement.',
          'ku': 'مێشک، خووەکان و شێوازی بیرکردنەوەت ڕێکبخەرەوە بۆ باشتربوونی بەردەوام.',
          'ar': 'أعد برمجة عقلك وعاداتك وطريقة تفكيرك لتحقيق التطوير الذاتي المستمر.',
        },
        color: Colors.deepPurpleAccent,
        icon: Icons.psychology,
        books: mindsetBooks..shuffle(),
      ));
    }

    // 2. Productivity & Success
    final productivityBooks = books.where((b) => 
      b.categoryIds.contains('cat-productivity') || 
      b.categoryIds.contains('cat-health-wellness')
    ).toList();
    if (productivityBooks.length >= 2) {
      candidates.add(FeaturedPlaylist(
        title: {
          'en': 'Peak Productivity',
          'ku': 'لووتکەی بەرهەمهێنان',
          'ar': 'قمة الإنتاجية',
        },
        description: {
          'en': 'Master your focus, energy, time, habits, and physical wellness.',
          'ku': 'کۆنترۆڵی سەرنج، وزە، کات، خووەکان و تەندروستی جەستەییت بکە.',
          'ar': 'سيطر على تركيزك، طاقتك، وقتك، عاداتك وعافيتك الجسدية.',
        },
        color: Colors.teal,
        icon: Icons.bolt,
        books: productivityBooks..shuffle(),
      ));
    }

    // 3. Leader's Edge
    final leadershipBooks = books.where((b) => 
      b.categoryIds.contains('cat-business') || 
      b.categoryIds.contains('cat-leadership') ||
      b.categoryIds.contains('cat-entrepreneurship')
    ).toList();
    if (leadershipBooks.length >= 2) {
      candidates.add(FeaturedPlaylist(
        title: {
          'en': "Leader's Edge",
          'ku': 'سەرکردایەتی نایاب',
          'ar': 'تميز القادة',
        },
        description: {
          'en': 'Sharpen your strategic thinking, leadership, business skill, and startup drive.',
          'ku': 'بیرکردنەوەی ستراتیژی، کارامەییەکانی سەرکردایەتی و کارسازی خۆت پێش بخە.',
          'ar': 'طور تفكيرك الاستراتيجي، ومهاراتك القيادية، وقدراتك الريادية.',
        },
        color: Colors.blueAccent,
        icon: Icons.insights,
        books: leadershipBooks..shuffle(),
      ));
    }

    // 4. Modern Wisdom
    final wisdomBooks = books.where((b) => 
      b.categoryIds.contains('cat-modern-wisdom') || 
      b.categoryIds.contains('cat-history-big-ideas') ||
      b.categoryIds.contains('cat-communication')
    ).toList();
    if (wisdomBooks.length >= 2) {
      candidates.add(FeaturedPlaylist(
        title: {
          'en': 'Modern Wisdom',
          'ku': 'دانایی هاوچەرخ',
          'ar': 'الحكمة الحديثة',
        },
        description: {
          'en': 'Explore deep human insights, communication, philosophy, and historical lessons.',
          'ku': 'قووڵبەرەوە لە تێگەیشتنەکانی مرۆڤ، پەیوەندی، فەلسەفە و وانە مێژووییەکان.',
          'ar': 'استكشف رؤى بشرية عميقة، مهارات التواصل، الفلسفة والدروس التاريخية.',
        },
        color: Colors.amber,
        icon: Icons.menu_book,
        books: wisdomBooks..shuffle(),
      ));
    }

    // 5. Daily Picks (Random sample)
    final dailyBooks = List<Book>.from(books)..shuffle();
    final selectedDaily = dailyBooks.take(5).toList();
    if (selectedDaily.length >= 2) {
      candidates.add(FeaturedPlaylist(
        title: {
          'en': 'Daily Curations',
          'ku': 'هەڵبژاردەی ڕۆژانە',
          'ar': 'مختارات اليوم',
        },
        description: {
          'en': 'A handpicked random selection of essential ideas for today.',
          'ku': 'کۆمەڵێک بیرۆکەی گرنگی هەڵبژێردراو بە شێوەیەکی هەڕەمەکی بۆ ئەمڕۆ.',
          'ar': 'مجموعة مختارة بعناية وعشوائية من الأفكار الأساسية لهذا اليوم.',
        },
        color: Colors.pinkAccent,
        icon: Icons.auto_awesome,
        books: selectedDaily,
      ));
    }

    // Fallback if we don't have enough categorized candidate playlists
    while (candidates.length < 2 && books.isNotEmpty) {
      final fallbackBooks = List<Book>.from(books)..shuffle();
      final fallbackTitle = candidates.isEmpty
          ? {
              'en': 'Featured Choices',
              'ku': 'هەڵبژاردە نایابەکان',
              'ar': 'خيارات مميزة',
            }
          : {
              'en': 'Top Reads',
              'ku': 'باشترین خوێندنەوەکان',
              'ar': 'أهم القراءات',
            };
      final fallbackDesc = {
        'en': 'Curated summaries chosen from our premium catalog.',
        'ku': 'پوختەی کتێبی هەڵبژێردراو لە لیستی کتێبە نایابەکانمانەوە.',
        'ar': 'ملخصات منسقة ومختارة من كتالوجنا المتميز.',
      };

      candidates.add(FeaturedPlaylist(
        title: fallbackTitle,
        description: fallbackDesc,
        color: candidates.isEmpty ? Colors.indigoAccent : Colors.orangeAccent,
        icon: Icons.thumb_up,
        books: fallbackBooks.take(4).toList(),
      ));
    }

    // Shuffle candidates and pick 2
    candidates.shuffle();
    return candidates.take(2).toList();
  }

  void _showPlaylistBottomSheet(BuildContext context, FeaturedPlaylist playlist, String langCode) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(playlist.icon, color: playlist.color, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            playlist.getTitle(langCode),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playlist.getDescription(langCode),
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: playlist.books.length,
                  itemBuilder: (context, index) {
                    final book = playlist.books[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: DownloadService.getBookCoverWidget(
                          book,
                          langCode: langCode,
                          width: 45,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        book.getTitle(langCode),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        book.getAuthor(langCode),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context); // Close bottom sheet
                        NetworkGuard.guardBookNavigation(context, book.id, () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BookDetailsScreen(bookId: book.id),
                            ),
                          );
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FeaturedPlaylist {
  final Map<String, String> title;
  final Map<String, String> description;
  final Color color;
  final IconData icon;
  final List<Book> books;

  FeaturedPlaylist({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.books,
  });

  String getTitle(String langCode) => title[langCode] ?? title['en'] ?? '';
  String getDescription(String langCode) => description[langCode] ?? description['en'] ?? '';
}
