import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/book.dart';
import 'summary_reader_screen.dart';
import '../audio/audio_player_screen.dart';
import '../profile/paywall_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/licence_manager.dart';
import '../../core/services/network_guard.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BookDetailsScreen extends StatefulWidget {
  final String bookId;
  const BookDetailsScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  Book? _book;
  List<Book> _relatedBooks = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  bool _isLicenceValid = false;
  bool _isLicenceExpired = false;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _loadBookDetails();
  }

  void _loadBookDetails() async {
    try {
      final books = await AppLocator.db.fetchBooks();
      Book book;
      try {
        book = books.firstWhere((b) => b.id == widget.bookId);
      } catch (_) {
        final downloaded = await DownloadService().getDownloadedBooks();
        book = downloaded.firstWhere((b) => b.id == widget.bookId);
      }
      
      final seenIds = <String>{widget.bookId};
      final currentEngTitle = (book.title['en'] ?? book.getTitle('en')).trim().toLowerCase();
      final seenEnglishTitles = <String>{currentEngTitle};
      final List<Book> related = [];
      
      for (final b in books) {
        if (b.id == widget.bookId) continue;
        final engTitle = (b.title['en'] ?? b.getTitle('en')).trim().toLowerCase();
        if (!seenIds.contains(b.id) && !seenEnglishTitles.contains(engTitle)) {
          seenIds.add(b.id);
          seenEnglishTitles.add(engTitle);
          related.add(b);
        }
      }

      final isDownloaded = await DownloadService().isBookDownloaded(widget.bookId);
      bool isLicenceValid = false;
      bool isLicenceExpired = false;
      if (isDownloaded) {
        isLicenceValid = await LicenceManager.isLicenceValid(widget.bookId);
        final licence = await LicenceManager.loadLicence(widget.bookId);
        if (licence != null) {
          isLicenceExpired = DateTime.parse(licence.licenceExpiryDate).isBefore(DateTime.now());
        }
      }
      final hasInternet = await NetworkGuard.hasConnection();

      if (isDownloaded && isLicenceValid) {
        try {
          book = await DownloadManager.loadBookContent(book);
        } catch (e) {
          print("Failed to load decrypted book content: $e");
        }
      }
      
      if (mounted) {
        setState(() {
          _book = book;
          _relatedBooks = related;
          _isDownloaded = isDownloaded;
          _isLicenceValid = isLicenceValid;
          _isLicenceExpired = isLicenceExpired;
          _hasInternet = hasInternet;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print("ERROR IN _loadBookDetails: $e\n$stack");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load book details. Please check your connection.')),
        );
      }
    }
  }

  void _toggleSave() async {
    if (_book == null) return;
    final user = AppLocator.auth.currentUser;
    final localizations = AppLocalizations.of(context)!;
    if (user != null) {
      if (user.savedBooks.contains(_book!.id)) {
        await AppLocator.auth.removeSavedBook(_book!.id);
        _showToast(localizations.translate('removed_from_library'));
      } else {
        await AppLocator.auth.addSavedBook(_book!.id);
        _showToast(localizations.translate('saved_to_library'));
      }
      setState(() {});
    }
  }

  void _toggleLike() async {
    if (_book == null) return;
    final user = AppLocator.auth.currentUser;
    final localizations = AppLocalizations.of(context)!;
    if (user != null) {
      if (user.likedBooks.contains(_book!.id)) {
        await AppLocator.auth.removeLikedBook(_book!.id);
        _showToast(localizations.translate('removed_from_liked'));
      } else {
        await AppLocator.auth.addLikedBook(_book!.id);
        _showToast(localizations.translate('added_to_liked'));
      }
      setState(() {});
    }
  }

  void _shareBook() {
    if (_book == null) return;
    
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    final bookTitle = _book!.getTitle(langCode);
    final bookAuthor = _book!.getAuthor(langCode);

    final shareText = langCode == 'ku'
        ? "سەیری ئەم کورتەکراوە سەرنجڕاکێشەی کتێبی '$bookTitle' بکە لە نووسینی $bookAuthor لەسەر ئەپی پەرتوک!"
        : (langCode == 'ar'
            ? "شاهد هذا الملخص الرائع لكتاب '$bookTitle' للكاتب $bookAuthor على تطبيق پەرتوک!"
            : "Check out this amazing book summary of '$bookTitle' by $bookAuthor on Partwk!");

    final shareLink = "https://partwk.com/book/${_book!.id}?lang=$langCode";
    final fullMessage = "$shareText\n$shareLink";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) {
        final theme = Theme.of(context);
        final title = langCode == 'ku' ? 'هاوبەشکردنی کتێب' : (langCode == 'ar' ? 'مشاركة الكتاب' : 'Share Book');
        final copyText = langCode == 'ku' ? 'کۆپی' : (langCode == 'ar' ? 'نسخ' : 'Copy');
        final copiedMsg = langCode == 'ku' ? 'بەستەرەکە کۆپی کرا!' : (langCode == 'ar' ? 'تم نسخ الرابط!' : 'Link copied to clipboard!');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shareAppButton(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.green,
                      label: 'WhatsApp',
                      onTap: () async {
                        final url = "https://wa.me/?text=${Uri.encodeComponent(fullMessage)}";
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        Navigator.of(context).pop();
                      },
                    ),
                    _shareAppButton(
                      icon: Icons.telegram,
                      color: Colors.blue,
                      label: 'Telegram',
                      onTap: () async {
                        final url = "https://t.me/share/url?url=${Uri.encodeComponent(shareLink)}&text=${Uri.encodeComponent(shareText)}";
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        Navigator.of(context).pop();
                      },
                    ),
                    _shareAppButton(
                      icon: Icons.mail_outline,
                      color: Colors.redAccent,
                      label: 'Email',
                      onTap: () async {
                        final url = "mailto:?subject=${Uri.encodeComponent(bookTitle)}&body=${Uri.encodeComponent(fullMessage)}";
                        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Colors.grey, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          shareLink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: fullMessage));
                          Navigator.of(context).pop();
                          _showToast(copiedMsg);
                        },
                        child: Text(
                          copyText,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shareAppButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showMarkCompleteDialog() {
    if (_book == null) return;
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    final dialogTitle = langCode == 'ku' ? 'تەواوکردنی ئەم کورتەکراوەیە؟' :
                        langCode == 'ar' ? 'تحديد هذا الملخص كمكتمل؟' :
                        'Mark this summary as complete?';

    final markButtonText = langCode == 'ku' ? 'تەواوکردن' :
                           langCode == 'ar' ? 'تحديد كمكتمل' :
                           'Mark Complete';

    final cancelButtonText = langCode == 'ku' ? 'پاشگەزبوونەوە' :
                             langCode == 'ar' ? 'إلغاء' :
                             'Cancel';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelButtonText),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AppLocator.auth.addCompletedBook(_book!.id, source: 'manual');
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
              ),
              child: Text(markButtonText),
            ),
          ],
        );
      },
    );
  }

  void _showMarkIncompleteDialog() {
    if (_book == null) return;
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    final dialogTitle = langCode == 'ku' ? 'تەواونەکردنی ئەم کورتەکراوەیە؟' :
                        langCode == 'ar' ? 'تحديد هذا الملخص كغير مكتمل؟' :
                        'Mark this summary as incomplete?';

    final confirmButtonText = langCode == 'ku' ? 'تەواونەکراو' :
                              langCode == 'ar' ? 'تأكيد' :
                              'Confirm';

    final cancelButtonText = langCode == 'ku' ? 'پاشگەزبوونەوە' :
                             langCode == 'ar' ? 'إلغاء' :
                             'Cancel';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(dialogTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelButtonText),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AppLocator.auth.removeCompletedBook(_book!.id);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmButtonText),
            ),
          ],
        );
      },
    );
  }

  void _downloadBook() async {
    if (_book == null) return;
    final user = AppLocator.auth.currentUser;
    // Require premium subscription to download
    if (_book!.isPremium && (user == null || !user.isPremium)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    
    bool success = await DownloadService().downloadBook(_book!, langCode, (progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
        });
      }
    });

    if (mounted) {
      if (success) {
        try {
          final decrypted = await DownloadManager.loadBookContent(_book!);
          final isLicenceValid = await LicenceManager.isLicenceValid(widget.bookId);
          setState(() {
            _book = decrypted;
            _isLicenceValid = isLicenceValid;
          });
        } catch (e) {
          print("Failed to load decrypted book content after download: $e");
        }
      }
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });
      if (success) {
        _showToast(localizations.translate('downloaded_success'));
      } else {
        _showToast(localizations.translate('downloaded_failed'));
      }
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _compareBook() {
    if (_book == null || _relatedBooks.isEmpty) return;
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    
    Book otherBook = _relatedBooks.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.translate('comparison'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _book!.getTitle(langCode),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('VS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<Book>(
                                        value: otherBook,
                                        isExpanded: true,
                                        alignment: Alignment.center,
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.teal),
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                        selectedItemBuilder: (context) {
                                          return _relatedBooks.map((b) {
                                            return Center(
                                              child: Text(
                                                b.getTitle(langCode),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList();
                                        },
                                        items: _relatedBooks.map((b) {
                                          return DropdownMenuItem<Book>(
                                            value: b,
                                            child: Text(
                                              b.getTitle(langCode),
                                              style: const TextStyle(fontWeight: FontWeight.normal),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (newBook) {
                                          if (newBook != null) {
                                            setBottomSheetState(() {
                                              otherBook = newBook;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              _buildComparisonRow(localizations.translate('author'), _book!.getAuthor(langCode), otherBook.getAuthor(langCode)),
                              _buildComparisonRow(
                                localizations.translate('duration'),
                                _book!.getDurationForLanguage(langCode) > 0
                                    ? '${(_book!.getDurationForLanguage(langCode) / 60).round()} ${localizations.translate('mins_suffix')}'
                                    : localizations.translate('text_only'),
                                otherBook.getDurationForLanguage(langCode) > 0
                                    ? '${(otherBook.getDurationForLanguage(langCode) / 60).round()} ${localizations.translate('mins_suffix')}'
                                    : localizations.translate('text_only'),
                              ),
                              _buildComparisonRow(localizations.translate('key_objective'), _book!.getDescription(langCode), otherBook.getDescription(langCode)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonRow(String parameter, String val1, String val2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(parameter, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(val1, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
              const SizedBox(width: 16),
              Expanded(child: Text(val2, style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBadges(ThemeData theme) {
    final List<Widget> badges = [];
    final langCode = AppLocalizations.of(context)!.locale.languageCode;

    if (_isDownloading) {
      return Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _downloadProgress < 0.99
                      ? (langCode == 'ku' ? 'خەریکی داگرتنە... (${(_downloadProgress * 100).round()}% )' :
                         langCode == 'ar' ? 'جاري التحميل... (${(_downloadProgress * 100).round()}% )' :
                         'Downloading... (${(_downloadProgress * 100).round()}%)')
                      : (langCode == 'ku' ? 'خەریکی ئامادەکردنی فایلی ئۆفلاینە...' :
                         langCode == 'ar' ? 'جاري معالجة الملف للاستخدام دون اتصال...' :
                         'Processing file for offline use...'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isDownloaded) {
      badges.add(_badge('Downloaded', Colors.teal, Icons.download_done));
      if (_isLicenceValid) {
        badges.add(_badge('Offline Available', Colors.green, Icons.offline_pin));
      } else if (_isLicenceExpired) {
        badges.add(_badge('Licence Expired', Colors.red, Icons.error_outline));
      } else {
        badges.add(_badge('Licence Invalid', Colors.amber[800]!, Icons.lock));
      }
    } else {
      if (!_hasInternet) {
        badges.add(_badge('Needs Internet', Colors.amber[900]!, Icons.wifi_off));
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: badges,
      ),
    );
  }

  Widget _badge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    final user = AppLocator.auth.currentUser;

    if (_isLoading || _book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isSaved = user?.savedBooks.contains(_book!.id) ?? false;
    final isLiked = user?.likedBooks.contains(_book!.id) ?? false;
    final isCompleted = user?.completedBooks.contains(_book!.id) ?? false;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Cover Area with Hero
            Stack(
              children: [
                // Blurred background for natural edges
                Container(
                  height: 460,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: DownloadService.getBookCoverProvider(_book!, langCode: langCode),
                      fit: BoxFit.contain,
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
                    child: Container(color: Colors.black.withOpacity(0.4)),
                  ),
                ),
                // Gradient for text readability
                Container(
                  height: 460,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.black.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                // The actual uncropped book cover
                Positioned(
                  top: 95,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Hero(
                      tag: 'book-cover-${_book!.id}',
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DownloadService.getBookCoverWidget(
                            _book!,
                            langCode: langCode,
                            height: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 48,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  top: 48,
                  right: 16,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: IconButton(
                          icon: const Icon(Icons.share, color: Colors.white),
                          onPressed: _shareBook,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: IconButton(
                          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.redAccent : Colors.white),
                          onPressed: _toggleLike,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: IconButton(
                          icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                          onPressed: _toggleSave,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: IconButton(
                          icon: _isDownloading
                              ? SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(
                                    value: _downloadProgress > 0 ? _downloadProgress : null, 
                                    strokeWidth: 3, 
                                    color: Colors.white
                                  )
                                )
                              : Icon(_isDownloaded ? Icons.offline_pin : Icons.download, color: _isDownloaded ? Colors.teal : Colors.white),
                          onPressed: _isDownloaded ? null : _downloadBook,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          onSelected: (value) {
                            if (value == 'complete') {
                              _showMarkCompleteDialog();
                            } else if (value == 'incomplete') {
                              _showMarkIncompleteDialog();
                            }
                          },
                          itemBuilder: (context) {
                            final user = AppLocator.auth.currentUser;
                            final isCompleted = user?.completedBooks.contains(_book!.id) ?? false;
                            return [
                              if (!isCompleted)
                                PopupMenuItem(
                                  value: 'complete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(langCode == 'ku' ? 'نیشانەکردن وەک تەواو' :
                                             langCode == 'ar' ? 'تحديد كمكتمل' : 'Mark as Complete'),
                                      ),
                                    ],
                                  ),
                                )
                              else ...[
                                PopupMenuItem(
                                  value: 'status_completed',
                                  enabled: false,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(langCode == 'ku' ? 'تەواوکراوە' :
                                             langCode == 'ar' ? 'مكتمل' : 'Completed'),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'incomplete',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.undo, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(langCode == 'ku' ? 'نیشانەکردن وەک نەتەواو' :
                                             langCode == 'ar' ? 'تحديد كغير مكتمل' : 'Mark as Not Complete'),
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            ];
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_book!.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                localizations.translate('premium').toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 10),
                                  const SizedBox(width: 4),
                                  Text(
                                    localizations.translate('completed').toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _book!.getTitle(langCode),
                        style: theme.textTheme.displayMedium?.copyWith(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'by ${_book!.getAuthor(langCode)}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8), fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            _book!.getDurationForLanguage(langCode) > 0 ? Icons.headphones : Icons.article,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (() {
                              final secs = _book!.getDurationForLanguage(langCode);
                              if (secs == 0) {
                                if (langCode == 'ku') return 'تەنها دەق';
                                if (langCode == 'ar') return 'نص فقط';
                                return 'Text only';
                              }
                              final mins = (secs / 60).round();
                              if (langCode == 'ku') return '$mins خولەک دەنگ';
                              if (langCode == 'ar') return '$mins دقيقة صوت';
                              return '$mins mins audio';
                            })(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.format_list_bulleted,
                            color: Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            localizations
                                .translate('keypoints_count')
                                .replaceAll('{count}', _book!.getKeypointsCount(langCode).toString()),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),

            if (!_book!.hasContentForLanguage(langCode))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          langCode == 'ar'
                              ? 'هذا الملخص غير متوفر باللغة العربية. يرجى تغيير لغة التطبيق للوصول إليه.'
                              : langCode == 'ku'
                                  ? 'ئەم کورتەکراوەیە بە زمانی کوردی بەردەست نییە. تکایە زمانی ئەپەکە بگۆڕە بۆ بینینی.'
                                  : 'This summary is not available in English. Please switch the app language to access it.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildOfflineBadges(theme),
              // Read / Listen buttons
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.menu_book),
                        label: Text(localizations.translate('read'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: () async {
                          final user = AppLocator.auth.currentUser;
                          if (_book!.isPremium && (user == null || !user.isPremium)) {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                            return;
                          }
                          final isDownloaded = await DownloadManager.isBookDownloaded(_book!.id);
                          final hasNet = await NetworkGuard.hasConnection();
                          if (!hasNet && !isDownloaded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Connect to the internet to download or stream this title.')),
                            );
                            return;
                          }
                          if (isDownloaded) {
                            final isValid = await LicenceManager.isLicenceValid(_book!.id);
                            if (!isValid) {
                              final isExpired = user != null && (user.subscriptionStatus != 'premium' && user.subscriptionStatus != 'pro' && !user.hasFamilyPremium);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isExpired
                                      ? 'Your premium access has ended. Renew Premium to access downloaded summaries.'
                                      : 'Connect to the internet to validate your offline licence.'),
                                ),
                              );
                              return;
                            }
                          }
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => SummaryReaderScreen(bookId: _book!.id)),
                          );
                          _loadBookDetails();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary, // Orange
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(localizations.translate('listen'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: () async {
                          final user = AppLocator.auth.currentUser;
                          if (_book!.isPremium && (user == null || !user.isPremium)) {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                            return;
                          }
                          final isDownloaded = await DownloadManager.isBookDownloaded(_book!.id);
                          final hasNet = await NetworkGuard.hasConnection();
                          if (!hasNet && !isDownloaded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Connect to the internet to download or stream this title.')),
                            );
                            return;
                          }
                          if (isDownloaded) {
                            final isValid = await LicenceManager.isLicenceValid(_book!.id);
                            if (!isValid) {
                              final isExpired = user != null && (user.subscriptionStatus != 'premium' && user.subscriptionStatus != 'pro' && !user.hasFamilyPremium);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isExpired
                                      ? 'Your premium access has ended. Renew Premium to access downloaded summaries.'
                                      : 'Connect to the internet to validate your offline licence.'),
                                ),
                              );
                              return;
                            }
                          }
                          // Start playing globally
                          final chapters = _book!.getChapterSummaries(langCode);
                          final globalAudioUrl = _book!.getAudioUrl(langCode);
                          final coverUrl = _book!.getCoverImageUrl(langCode);
                          AppLocator.audio.play(_book!.id, langCode, _book!.getTitle(langCode), coverUrl, globalAudioUrl, chapters, bookDurationSecs: _book!.getDurationForLanguage(langCode));
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => AudioPlayerScreen(bookId: _book!.id, langCode: langCode, bookTitle: _book!.getTitle(langCode), coverUrl: coverUrl, globalAudioUrl: globalAudioUrl, chapters: chapters, bookDurationSecs: _book!.getDurationForLanguage(langCode))),
                          );
                          _loadBookDetails();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Blue
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ],

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.translate('overview'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_book!.getDescription(langCode), style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _compareBook,
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(localizations.translate('comparison')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Related Books
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localizations.translate('related_summaries'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _relatedBooks.length,
                      itemBuilder: (context, index) {
                        final rel = _relatedBooks[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => BookDetailsScreen(bookId: rel.id)),
                            );
                          },
                          child: Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 180,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: DownloadService.getBookCoverWidget(
                                      rel,
                                      langCode: langCode,
                                      height: 180,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(rel.getTitle(langCode), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
