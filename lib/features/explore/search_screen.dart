import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/book_card.dart';
import '../../models/book.dart';
import '../../models/category.dart';
import '../book/book_details_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Book> _allBooks = [];
  List<Book> _results = [];
  List<Category> _categories = [];
  bool _isLoading = true;

  final List<String> _popularTags = [
    'tag_focus', 'tag_productivity', 'tag_success', 'tag_history', 'tag_kurdish', 'tag_science', 'tag_philosophy'
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() async {
    final books = await AppLocator.db.fetchBooks();
    final categories = await AppLocator.db.fetchCategories();
    if (mounted) {
      setState(() {
        _allBooks = books;
        _results = books; // Show all initially
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = _allBooks;
      });
      return;
    }

    final q = query.toLowerCase();
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    setState(() {
      _results = _allBooks.where((book) {
        final title = book.getTitle(langCode).toLowerCase();
        final author = book.getAuthor(langCode).toLowerCase();
        final desc = book.getDescription(langCode).toLowerCase();
        final matchesTags = book.tags.any((tag) => tag.toLowerCase().contains(q));
        final matchesCategory = book.categoryIds.any((catId) {
          final cat = _categories.firstWhere((c) => c.id == catId, orElse: () => Category(id: '', name: {}, iconName: ''));
          return cat.getName(langCode).toLowerCase().contains(q);
        });

        return title.contains(q) ||
            author.contains(q) ||
            desc.contains(q) ||
            matchesTags ||
            matchesCategory;
      }).toList();
    });
  }

  void _applyTag(String tagKey) {
    final localizations = AppLocalizations.of(context)!;
    final queryText = localizations.translate(tagKey);
    _searchController.text = queryText;
    _performSearch(queryText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final user = AppLocator.auth.currentUser;
    final langCode = localizations.locale.languageCode;
    
    final validResults = _results.where((b) => b.hasContentForLanguage(langCode)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('search')),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextField(
              controller: _searchController,
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: localizations.translate('search'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // Content Area
            Expanded(
              child: _searchController.text.isEmpty
                  ? SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.translate('popular_searches') ?? 'Popular Searches',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _popularTags.map((tag) {
                              return GestureDetector(
                                onTap: () => _applyTag(tag),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondary.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.15)),
                                  ),
                                  child: Text(
                                    '#${localizations.translate(tag)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            localizations.translate('category') ?? 'Categories',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              return GestureDetector(
                                onTap: () {
                                  _searchController.text = cat.getName(langCode);
                                  _performSearch(cat.getName(langCode));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: theme.cardTheme.color,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat.getName(langCode),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            localizations.translate('trending') ?? 'Popular Books',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 280,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: validResults.take(6).length,
                              separatorBuilder: (context, index) => const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final book = validResults[index];
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
                          const SizedBox(height: 40),
                        ],
                      ),
                    )
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : validResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 60, color: Colors.grey.withOpacity(0.5)),
                                  const SizedBox(height: 16),
                                  Text(
                                    localizations.translate('no_summaries_found'),
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: validResults.length,
                              itemBuilder: (context, index) {
                                final book = validResults[index];
                                return BookCard(
                                  book: book,
                                  progress: user != null ? user.getBookProgress(book, langCode) : 0.0,
                                  onTap: () {
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
      ),
    );
  }
}
