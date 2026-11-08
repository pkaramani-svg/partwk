import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../localization/app_localizations.dart';
import '../../services/download_service.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final double progress; // 0.0 to 1.0
  final Widget? trailing;
  final Widget? badge;
  final String? displayLanguageCode;

  const BookCard({
    Key? key,
    required this.book,
    required this.onTap,
    this.progress = 0.0,
    this.trailing,
    this.badge,
    this.displayLanguageCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context);
    final langCode = displayLanguageCode ?? locale?.locale.languageCode ?? 'en';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image
                Hero(
                  tag: 'book-cover-${book.id}',
                  child: SizedBox(
                    width: 90,
                    child: ClipRRect(
                      borderRadius: const BorderRadiusDirectional.horizontal(
                        start: Radius.circular(16),
                      ).resolve(Directionality.of(context)),
                      child: DownloadService.getBookCoverWidget(
                        book,
                        langCode: langCode,
                        width: 90,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (badge != null) badge!,
                                // Premium Badge
                                if (book.isPremium)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.tertiary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PREMIUM',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.tertiary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'FREE',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            // Audio duration
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  book.getDurationForLanguage(langCode) > 0
                                      ? Icons.headset
                                      : Icons.article,
                                  size: 13,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  (() {
                                    final secs = book.getDurationForLanguage(langCode);
                                    if (secs == 0) {
                                      if (langCode == 'ku') return 'تەنها دەق';
                                      if (langCode == 'ar') return 'نص فقط';
                                      return 'Text';
                                    }
                                    return '${(secs / 60).round()}m';
                                  })(),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          book.getTitle(langCode),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Author
                        Text(
                          book.getAuthor(langCode),
                          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Reading progress bar
                        if (progress > 0.0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: progress >= 1.0 ? Colors.green.withOpacity(0.1) : theme.colorScheme.secondary.withOpacity(0.1),
                                    color: progress >= 1.0 ? Colors.green : theme.colorScheme.secondary,
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (progress >= 1.0)
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.green, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      langCode == 'ku' ? 'تەواوکراوە' :
                                      langCode == 'ar' ? 'مكتمل' : 'Completed',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Center(child: trailing!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
