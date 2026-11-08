import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../core/services/offline_availability_repository.dart';
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
  List<DownloadedEdition> _downloadedEditions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  void _loadDownloads() async {
    final editions = await DownloadService().getDownloadedEditions();
    if (mounted) {
      setState(() {
        _downloadedEditions = editions;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final user = AppLocator.auth.currentUser;
    final currentAppLang = localizations.locale.languageCode;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalSlotsUsed = _downloadedEditions.length;

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.offline_pin, color: Colors.teal, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          localizations.translate('offline_storage_enabled') ?? 'Offline Storage Enabled',
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
                    '$totalSlotsUsed / 3 downloads used',
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
            const SizedBox(height: 20),
            
            Expanded(
              child: _downloadedEditions.isEmpty
                  ? Center(
                      child: Text(localizations.translate('no_offline_summaries'), style: theme.textTheme.bodyLarge),
                    )
                  : ListView.builder(
                      itemCount: _downloadedEditions.length,
                      itemBuilder: (context, index) {
                        final edition = _downloadedEditions[index];
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
                              tooltip: 'Delete edition download',
                              onPressed: () => _confirmDeleteEdition(edition, currentAppLang, localizations),
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
                            _loadDownloads();
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

  void _confirmDeleteEdition(DownloadedEdition edition, String appLang, AppLocalizations localizations) {
    final book = edition.book;
    final editionLang = edition.languageCode;
    final editionName = '${book.getTitle(editionLang)} (${_getLanguageLabel(editionLang)})';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          appLang == 'ku' ? 'سڕینەوەی داگرتن' : (appLang == 'ar' ? 'إزالة التنزيل' : 'Remove Download'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          appLang == 'ku'
              ? 'ئایا دڵنیایت لە سڕینەوەی "$editionName"؟ بە سڕینەوەی یەک شوێن ئازاد دەبێت لە کۆی ٣ دانە.'
              : (appLang == 'ar'
                  ? 'هل أنت متأكد من إزالة "$editionName"؟ سيؤدي ذلك إلى تفريغ مساحة واحدة من أصل 3.'
                  : 'Are you sure you want to remove "$editionName"? This will immediately free 1 offline slot.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(localizations.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await DownloadService().removeDownload(edition.bookId, languageCode: edition.languageCode);
              _loadDownloads();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(appLang == 'ku' ? 'سڕینەوە' : (appLang == 'ar' ? 'إزالة' : 'Remove')),
          ),
        ],
      ),
    );
  }
}
