import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/book_card.dart';
import '../../models/book.dart';
import '../../models/note.dart';
import '../book/book_details_screen.dart';
import '../learning/notes_highlights_screen.dart';
import 'downloads_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/offline_availability_repository.dart';
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
  List<Book> _likedBooks = [];
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  void _loadSaved() async {
    AppLocator.auth.refreshEntitlementAuthoritatively();
    final allBooks = await AppLocator.db.fetchBooks();
    final user = AppLocator.auth.currentUser;
    if (user != null) {
      final continueIds = <String>{};
      continueIds.addAll(user.listeningProgress.keys.map((k) => k.split('_').first));
      continueIds.addAll(user.readingProgress.keys);
      continueIds.removeAll(user.completedBooks);

      final userNotes = await AppLocator.db.fetchNotes(user.id);

      if (mounted) {
        setState(() {
          _savedBooks = allBooks.where((b) => user.savedBooks.contains(b.id)).toList();
          _likedBooks = allBooks.where((b) => user.likedBooks.contains(b.id)).toList();
          _continueBooks = allBooks.where((b) => continueIds.contains(b.id)).toList();
          _notes = userNotes;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getLanguageLabel(String langCode) {
    switch (langCode) {
      case 'ku':
        return 'کوردی (Sorani)';
      case 'ar':
        return 'العربية (Arabic)';
      case 'en':
      default:
        return 'English';
    }
  }

  Future<void> _confirmDeleteEdition(DownloadedEdition edition, String currentLang, AppLocalizations localizations) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.translate('delete_download')),
        content: Text('${localizations.translate('confirm_delete_download')} "${edition.book.getTitle(currentLang)}" (${_getLanguageLabel(edition.languageCode)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(localizations.translate('cancel'))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(localizations.translate('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DownloadService().removeDownload(edition.book.id, languageCode: edition.languageCode);
      if (mounted) setState(() {});
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
    final liked = _likedBooks.where((b) => b.hasContentForLanguage(langCode)).toList();

    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localizations.translate('library')),
          actions: [
            IconButton(
              icon: const Icon(Icons.download_for_offline_rounded),
              tooltip: localizations.translate('downloaded_books'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DownloadsScreen())).then((_) => setState(() {})),
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_rename_outline_rounded),
              tooltip: localizations.translate('highlights'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotesAndHighlightsScreen())).then((_) => _loadSaved()),
            ),
          ],
        ),
        body: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: localizations.translate('continue_reading')),
                Tab(text: localizations.translate('liked')),
                Tab(text: localizations.translate('saved_summaries')),
                Tab(text: localizations.translate('notes')),
                Tab(text: localizations.translate('downloaded_books')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildBookList(continueB, localizations.translate('no_books_in_progress'), user),
                  _buildBookList(liked, localizations.translate('no_liked_books'), user),
                  _buildBookList(saved, localizations.translate('saved_library_empty'), user),
                  _buildNotesTab(context, localizations, theme, user),
                  _buildDownloadedBooksTab(context, localizations, theme, user),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesTab(BuildContext context, AppLocalizations localizations, ThemeData theme, dynamic user) {
    if (_notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.drive_file_rename_outline_rounded, size: 54, color: Colors.grey.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(localizations.translate('no_notes_saved')),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.bookTitle,
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: localizations.translate('delete'),
                      onPressed: () async {
                        await AppLocator.db.deleteNote(note.id);
                        if (user != null) {
                          final updated = await AppLocator.db.fetchNotes(user.id);
                          if (mounted) setState(() => _notes = updated);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  note.noteText,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadedBooksTab(BuildContext context, AppLocalizations localizations, ThemeData theme, dynamic user) {
    return FutureBuilder<List<DownloadedEdition>>(
      future: DownloadService().getDownloadedEditions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final editions = snapshot.data!;
        final totalSlotsUsed = editions.length;
        final quotaStr = localizations.translate('downloads_used_format')
            .replaceAll('{used}', totalSlotsUsed.toString())
            .replaceAll('{max}', '3');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.offline_pin, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            localizations.translate('offline_storage_enabled'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: totalSlotsUsed >= 3
                          ? (theme.brightness == Brightness.dark ? Colors.amber.withOpacity(0.2) : const Color(0xFFFFF3CD))
                          : (theme.brightness == Brightness.dark ? Colors.teal.withOpacity(0.2) : const Color(0xFFE8F5E9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: totalSlotsUsed >= 3 ? Colors.amber.shade700 : Colors.teal.shade700,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      quotaStr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: totalSlotsUsed >= 3
                            ? (theme.brightness == Brightness.dark ? const Color(0xFFFFD54F) : const Color(0xFF8A5300))
                            : (theme.brightness == Brightness.dark ? const Color(0xFF80CBC4) : const Color(0xFF1B5E20)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: editions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_for_offline_outlined, size: 54, color: Colors.grey.withOpacity(0.4)),
                            const SizedBox(height: 16),
                            Text(localizations.translate('no_offline_summaries'), style: theme.textTheme.bodyLarge),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: editions.length,
                        itemBuilder: (context, index) {
                          final edition = editions[index];
                          final book = edition.book;
                          final editionLang = edition.languageCode;
                          final langLabel = _getLanguageLabel(editionLang);

                          return BookCard(
                            book: book,
                            displayLanguageCode: editionLang,
                            progress: user != null ? user.getBookProgress(book, editionLang) : 0.0,
                            badge: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.teal.withOpacity(0.5)),
                              ),
                              child: Text(
                                langLabel,
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark ? const Color(0xFF80CBC4) : Colors.teal.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                tooltip: localizations.translate('delete_download'),
                                onPressed: () => _confirmDeleteEdition(edition, localizations.locale.languageCode, localizations),
                              ),
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookDetailsScreen(
                                    bookId: book.id,
                                    initialLanguageCode: editionLang,
                                  ),
                                ),
                              );
                              if (mounted) setState(() {});
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
