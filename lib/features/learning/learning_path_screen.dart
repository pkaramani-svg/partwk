import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/learning_path.dart';
import '../../models/book.dart';
import '../book/book_details_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';

class LearningPathScreen extends StatefulWidget {
  final LearningPath path;
  const LearningPathScreen({Key? key, required this.path}) : super(key: key);

  @override
  State<LearningPathScreen> createState() => _LearningPathScreenState();
}

class _LearningPathScreenState extends State<LearningPathScreen> {
  List<Book> _pathBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  void _loadBooks() async {
    final allBooks = await AppLocator.db.fetchBooks();
    setState(() {
      _pathBooks = allBooks.where((b) => widget.path.bookIds.contains(b.id)).toList();
      _isLoading = false;
    });
  }

  void _showCertificate() {
    final user = AppLocator.auth.currentUser;
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amber, width: 3),
              color: theme.colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.amber, size: 72),
                const SizedBox(height: 16),
                Text(
                  localizations.translate('congratulations'),
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 24, color: Colors.amber, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  localizations.translate('cert_completion'),
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12),
                ),
                const Divider(height: 32),
                Text(localizations.translate('presented_to')),
                const SizedBox(height: 8),
                Text(
                  user?.name ?? localizations.translate('guest_reader'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.translate('completed_learning_path'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.path.getTitle(langCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(localizations.translate('download_share')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    final user = AppLocator.auth.currentUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final validPathBooks = _pathBooks.where((b) => b.hasContentForLanguage(langCode)).toList();

    // Calculate progress
    int completedCount = 0;
    for (var b in validPathBooks) {
      if (user?.completedBooks.contains(b.id) ?? false) {
        completedCount++;
      }
    }
    final progressVal = validPathBooks.isNotEmpty ? completedCount / validPathBooks.length : 0.0;
    final isCompleted = progressVal >= 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path.getTitle(langCode)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.path.getDescription(langCode),
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressVal,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(progressVal * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Certificate claim button
            if (isCompleted) ...[
              ElevatedButton.icon(
                onPressed: _showCertificate,
                icon: const Icon(Icons.workspace_premium),
                label: Text(localizations.translate('claim_cert')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Step by Step Book List
            Text(
              localizations.translate('sequence_of_books'),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: validPathBooks.length,
              itemBuilder: (context, index) {
                final book = validPathBooks[index];
                final isBookCompleted = user?.completedBooks.contains(book.id) ?? false;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline step indicator
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isBookCompleted ? Colors.teal : Colors.grey.withOpacity(0.3),
                          child: isBookCompleted
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        if (index < _pathBooks.length - 1)
                          Container(
                            width: 2,
                            height: 130,
                            color: isBookCompleted ? Colors.teal : Colors.grey.withOpacity(0.3),
                          )
                      ],
                    ),
                    const SizedBox(width: 16),
                    
                    // Book card
                    Expanded(
                      child: SizedBox(
                        height: 130,
                        child: Card(
                          child: InkWell(
                            onTap: () {
                              NetworkGuard.guardBookNavigation(context, book.id, () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BookDetailsScreen(bookId: book.id),
                                  ),
                                ).then((_) => _loadBooks()); // Refresh progress
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: DownloadService.getBookCoverWidget(
                                        book,
                                        langCode: langCode,
                                        width: 60,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          book.getTitle(langCode),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          book.getAuthor(langCode),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
