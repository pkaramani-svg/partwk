import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/book_card.dart';
import '../../models/book.dart';
import '../book/book_details_screen.dart';
import '../learning/notes_highlights_screen.dart';
import 'downloads_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';

class SavedLibraryScreen extends StatefulWidget {
  final int initialIndex;
  const SavedLibraryScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<SavedLibraryScreen> createState() => _SavedLibraryScreenState();
}

class _SavedLibraryScreenState extends State<SavedLibraryScreen> {
  List<Book> _savedBooks = [];
  List<Book> _continueBooks = [];
  List<Book> _finishedBooks = [];
  List<Book> _likedBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  void _loadSaved() async {
    final allBooks = await AppLocator.db.fetchBooks();
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      final continueIds = <String>{};
      continueIds.addAll(user.listeningProgress.keys.map((k) => k.split('_').first));
      continueIds.addAll(user.readingProgress.keys);
      continueIds.removeAll(user.completedBooks);

      setState(() {
        _savedBooks = allBooks.where((b) => user.savedBooks.contains(b.id)).toList();
        _finishedBooks = allBooks.where((b) => user.completedBooks.contains(b.id)).toList();
        _likedBooks = allBooks.where((b) => user.likedBooks.contains(b.id)).toList();
        _continueBooks = allBooks.where((b) => continueIds.contains(b.id)).toList();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final user = AppLocator.auth.currentUser;
    final langCode = localizations.locale.languageCode;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final saved = _savedBooks.where((b) => b.hasContentForLanguage(langCode)).toList();
    final continueB = _continueBooks.where((b) => b.hasContentForLanguage(langCode)).toList();
    final finished = _finishedBooks.where((b) => b.hasContentForLanguage(langCode)).toList();
    final liked = _likedBooks.where((b) => b.hasContentForLanguage(langCode)).toList();

    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localizations.translate('library') ?? 'My Library'),
          actions: [
            IconButton(
              icon: const Icon(Icons.offline_pin_outlined),
              tooltip: localizations.translate('downloads'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_outlined),
              tooltip: localizations.translate('highlights'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotesAndHighlightsScreen())),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: localizations.translate('continue_reading')),
              Tab(text: localizations.translate('liked')),
              Tab(text: localizations.translate('saved_summaries')),
              Tab(text: localizations.translate('completed')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBookList(continueB, localizations.translate('no_books_in_progress'), user),
            _buildBookList(liked, localizations.translate('no_liked_books'), user),
            _buildBookList(saved, localizations.translate('saved_library_empty'), user),
            _buildBookList(finished, localizations.translate('no_finished_books'), user),
          ],
        ),
      ),
    );
  }

  Widget _buildBookList(List<Book> books, String emptyMessage, dynamic user) {
    final langCode = AppLocalizations.of(context)!.locale.languageCode;
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections_bookmark_outlined, size: 54, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(emptyMessage),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return BookCard(
          book: book,
          progress: user != null ? user.getBookProgress(book, langCode) : 0.0,
          onTap: () {
            NetworkGuard.guardBookNavigation(context, book.id, () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BookDetailsScreen(bookId: book.id),
                ),
              ).then((value) => _loadSaved());
            });
          },
        );
      },
    );
  }
}
