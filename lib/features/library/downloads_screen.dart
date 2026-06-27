import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/widgets/book_card.dart';
import '../../models/book.dart';
import '../../services/download_service.dart';
import '../book/book_details_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Book> _downloadedBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  void _loadDownloads() async {
    final books = await DownloadService().getDownloadedBooks();
    if (mounted) {
      setState(() {
        _downloadedBooks = books;
        _isLoading = false;
      });
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

    final validDownloads = _downloadedBooks.where((b) => b.hasContentForLanguage(langCode)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('downloads')),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.offline_pin, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Text(
                  localizations.translate('offline_storage_enabled'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            Expanded(
              child: validDownloads.isEmpty
                  ? Center(
                      child: Text(localizations.translate('no_offline_summaries'), style: theme.textTheme.bodyLarge),
                    )
                  : ListView.builder(
                      itemCount: validDownloads.length,
                      itemBuilder: (context, index) {
                        final book = validDownloads[index];
                        return BookCard(
                          book: book,
                          progress: user != null ? user.getBookProgress(book, langCode) : 0.0,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => BookDetailsScreen(bookId: book.id),
                              ),
                            );
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
