import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/service_locator.dart';
import '../../models/book.dart';
import '../../models/highlight.dart';
import '../../models/note.dart';
import '../learning/quiz_screen.dart';
import '../learning/flashcards_screen.dart';
import '../audio/audio_player_screen.dart';
import '../../services/download_service.dart';
import '../../core/services/streak_tracker.dart';
import '../../core/services/download_manager.dart';
import '../../core/services/licence_manager.dart';
import '../../core/services/network_guard.dart';
import '../auth/login_register_screen.dart';

class SummaryReaderScreen extends StatefulWidget {
  final String bookId;
  final int initialChapterIndex;
  const SummaryReaderScreen({
    Key? key,
    required this.bookId,
    this.initialChapterIndex = 0,
  }) : super(key: key);

  @override
  State<SummaryReaderScreen> createState() => _SummaryReaderScreenState();
}

class _SummaryReaderScreenState extends State<SummaryReaderScreen> {
  Book? _book;
  bool _isLoading = true;
  int _currentChapterIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Reader display settings
  double _fontSize = 16.0;
  bool _isDarkReader = false;
  bool _showSettingsPanel = false;
  ImageProvider? _coverProvider;
  String? _licenceError;
  bool _isPremiumExpired = false;

  // Highlights state
  List<Highlight> _savedHighlights = [];

  // Notes state
  final TextEditingController _noteInputController = TextEditingController();

  DateTime? _chapterStartTime;

  @override
  void initState() {
    super.initState();
    _currentChapterIndex = widget.initialChapterIndex;
    _chapterStartTime = DateTime.now();
    _loadBook();
  }
  
  void _recordLearningTime() {
    if (_chapterStartTime != null) {
      final diff = DateTime.now().difference(_chapterStartTime!);
      AppLocator.auth.addLearningTime(diff.inSeconds);
      _chapterStartTime = DateTime.now();
    }
  }

  void _showRegisterPopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.translate('unlock_full_book'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(loc.translate('guest_restriction_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.translate('maybe_later')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                AppLocator.audio.stop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
                  (route) => false,
                );
              },
              child: Text(loc.translate('register_now')),
            ),
          ],
        );
      },
    );
  }

  void _loadBook() async {
    try {
      final books = await AppLocator.db.fetchBooks();
      var book = books.firstWhere((b) => b.id == widget.bookId);
      final user = AppLocator.auth.currentUser;
      if (user != null) {
        final hls = await AppLocator.db.fetchHighlights(user.id);
        setState(() {
          _savedHighlights = hls.where((h) => h.bookId == widget.bookId).toList();
        });
      }

      // Check offline capability and encryption
      final isDownloaded = await DownloadManager.isBookDownloaded(book.id);
      if (isDownloaded) {
        try {
          book = await DownloadManager.loadBookContent(book);
        } on LicenceInvalidException catch (e) {
          setState(() {
            _licenceError = 'Connect to the internet to download or stream this title.';
            _isLoading = false;
          });
          return;
        } on LicenceExpiredException catch (e) {
          setState(() {
            _licenceError = 'Your premium access has ended. Renew Premium to access downloaded summaries.';
            _isPremiumExpired = true;
            _isLoading = false;
          });
          return;
        } catch (e) {
          setState(() {
            _licenceError = 'Connect to the internet to download or stream this title.';
            _isLoading = false;
          });
          return;
        }
      } else {
        // If not downloaded and offline, we must block reading
        final hasNet = await NetworkGuard.hasConnection();
        if (!hasNet) {
          setState(() {
            _licenceError = 'Connect to the internet to download or stream this title.';
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        final langCode = AppLocalizations.of(context)!.locale.languageCode;
        setState(() {
          _book = book;
          _coverProvider = DownloadService.getBookCoverProvider(book, langCode: langCode);
          _isLoading = false;
        });
        AppLocator.auth.updatePresence(
          screen: 'Reading Summary',
          bookTitle: book.getTitle(langCode),
          bookId: book.id,
          activityType: 'reading',
        );
        if (AppLocator.auth.isGuest && _currentChapterIndex >= 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRegisterPopup();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _licenceError = 'Connect to the internet to download or stream this title.';
          _isLoading = false;
        });
      }
    }
  }

  void _addHighlight(String text, int colorHex) async {
    final user = AppLocator.auth.currentUser;
    if (user == null || _book == null) return;
    
    final hl = Highlight(
      id: const Uuid().v4(),
      userId: user.id,
      bookId: _book!.id,
      bookTitle: _book!.getTitle(user.selectedLanguage),
      text: text,
      colorValue: colorHex,
      createdAt: DateTime.now(),
    );

    await AppLocator.db.addHighlight(hl);
    setState(() {
      _savedHighlights.add(hl);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Highlight saved!'), duration: Duration(seconds: 1)),
    );
  }



  void _saveNote() async {
    final text = _noteInputController.text.trim();
    if (text.isEmpty || _book == null) return;

    final user = AppLocator.auth.currentUser;
    if (user == null) return;

    final note = Note(
      id: const Uuid().v4(),
      userId: user.id,
      bookId: _book!.id,
      bookTitle: _book!.getTitle(user.selectedLanguage),
      noteText: text,
      createdAt: DateTime.now(),
    );

    await AppLocator.db.addNote(note);
    final localizations = AppLocalizations.of(context)!;
    _noteInputController.clear();
    Navigator.of(context).pop(); // Dismiss sheet
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.translate('note_added'))),
    );
  }

  void _showAddNoteDialog() {
    final localizations = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 24,
              right: 24,
            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                localizations.translate('add_personal_note'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteInputController,
                decoration: InputDecoration(
                  hintText: localizations.translate('note_hint'),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveNote,
                child: Text(localizations.translate('save_note')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        );
      },
    );
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    if (_licenceError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isPremiumExpired ? Icons.lock_clock : Icons.wifi_off_outlined,
                  size: 80,
                  color: Colors.amber[800],
                ),
                const SizedBox(height: 24),
                Text(
                  _isPremiumExpired ? 'Premium Expired' : 'Offline Mode',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _licenceError!,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoading || _book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _recordLearningTime();
        await StreakTracker.checkAndShowStreakPopup(context);
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      key: _scaffoldKey,
      backgroundColor: _isDarkReader ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDarkReader ? Colors.black : Colors.white,
        foregroundColor: _isDarkReader ? Colors.white : Colors.black,
        elevation: 0.5,
        iconTheme: IconThemeData(color: _isDarkReader ? Colors.white : Colors.black),
        title: Text(
          _book!.getTitle(langCode), 
          style: TextStyle(fontSize: 16, color: _isDarkReader ? Colors.white : Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.headphones),
            tooltip: localizations.translate('listen_chapter'),
            color: _isDarkReader ? Colors.white : Colors.black,
            onPressed: () {
              final chapters = _book!.getChapterSummaries(langCode).cast<Map<String, dynamic>>();
              final globalAudioUrl = _book!.getAudioUrl(langCode);
              final coverUrl = _book!.getCoverImageUrl(langCode);
              final audioService = AppLocator.audio;
              
              final isCurrentBook = audioService.currentBookId == _book!.id && audioService.currentLangCode == langCode;
              
              int startPos = 0;
              if (isCurrentBook && audioService.currentChapterIndex == _currentChapterIndex) {
                if (!audioService.isPlaying) {
                  audioService.resume();
                }
              } else {
                var progress = AppLocator.auth.currentUser?.listeningProgress['${_book!.id}_$langCode'];
                if (progress == null) {
                  final prefix = '${_book!.id}_';
                  final matchingKey = AppLocator.auth.currentUser?.listeningProgress.keys.firstWhere(
                    (k) => k.startsWith(prefix),
                    orElse: () => '',
                  ) ?? '';
                  if (matchingKey.isNotEmpty) {
                    progress = AppLocator.auth.currentUser?.listeningProgress[matchingKey];
                  }
                }
                if (progress != null && progress['chapterIndex'] == _currentChapterIndex) {
                  startPos = progress['positionSeconds'] ?? 0;
                }
                
                audioService.play(
                  _book!.id,
                  langCode,
                  _book!.getTitle(langCode),
                  coverUrl,
                  globalAudioUrl,
                  chapters,
                  startIndex: _currentChapterIndex,
                  startPosition: startPos,
                  bookDurationSecs: _book!.getDurationForLanguage(langCode),
                );
              }
              
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => AudioPlayerScreen(
                  bookId: _book!.id, 
                  langCode: langCode,
                  bookTitle: _book!.getTitle(langCode), 
                  coverUrl: coverUrl, 
                  globalAudioUrl: globalAudioUrl,
                  chapters: chapters,
                  initialChapterIndex: _currentChapterIndex,
                  initialPositionSecs: startPos,
                  bookDurationSecs: _book!.getDurationForLanguage(langCode),
                ),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_alt, size: 26),
            tooltip: localizations.translate('quiz'),
            color: _isDarkReader ? Colors.white : Colors.black,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => QuizScreen(bookId: _book!.id)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.amp_stories, size: 24),
            tooltip: localizations.translate('flashcards'),
            color: _isDarkReader ? Colors.white : Colors.black,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FlashcardsScreen(bookId: _book!.id)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: localizations.translate('add_note'),
            color: _isDarkReader ? Colors.white : Colors.black,
            onPressed: _showAddNoteDialog,
          ),
          IconButton(
            icon: const Icon(Icons.text_fields),
            tooltip: localizations.translate('reader_settings'),
            color: _showSettingsPanel ? theme.colorScheme.secondary : (_isDarkReader ? Colors.white : Colors.black),
            onPressed: () {
              setState(() {
                _showSettingsPanel = !_showSettingsPanel;
              });
            },
          ),
        ],
      ),
      body: _buildSingleChapterView(langCode),
      ),
    );
  }

  Widget _buildSingleChapterView(String langCode) {
    final chapters = _book!.getChapterSummaries(langCode).cast<Map<String, dynamic>>();
    final localizations = AppLocalizations.of(context)!;
    if (chapters.isEmpty) {
      return Center(child: Text(localizations.translate('no_chapters_warning')));
    }

    final theme = Theme.of(context);
    final currentChapter = chapters[_currentChapterIndex];

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_showSettingsPanel) {
                setState(() {
                  _showSettingsPanel = false;
                });
              }
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Cover Area
                  Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.black, // Dark background
                    child: DownloadService.getBookCoverWidget(
                      _book!,
                      langCode: AppLocalizations.of(context)!.locale.languageCode,
                      height: 220,
                      fit: BoxFit.contain, // Show entire cover
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Chapter Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      currentChapter['title'] ?? (
                        langCode == 'ku' ? 'خاڵی سەرەکی ${_currentChapterIndex + 1}' :
                        langCode == 'ar' ? 'النقطة الرئيسية ${_currentChapterIndex + 1}' :
                        'Key Point ${_currentChapterIndex + 1}'
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _isDarkReader ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Chapter Content
                  _buildReaderContent(currentChapter['content'] ?? ''),
                ],
              ),
            ),
          ),
        ),
        if (_showSettingsPanel)
          _buildSettingsPanel(theme),
        // Bottom Navigation Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isDarkReader ? Colors.grey[900] : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
            ],
            border: Border(
              top: BorderSide(color: _isDarkReader ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.2)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentChapterIndex > 0)
                  TextButton.icon(
                    onPressed: () {
                      _recordLearningTime();
                      setState(() {
                        _currentChapterIndex--;
                      });
                    },
                    icon: Icon(Icons.arrow_back_ios, size: 16, color: _isDarkReader ? Colors.white70 : Colors.black87),
                    label: Text(localizations.translate('previous')),
                    style: TextButton.styleFrom(
                      foregroundColor: _isDarkReader ? Colors.white70 : Colors.black87,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                
                if (_currentChapterIndex < chapters.length - 1)
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (AppLocator.auth.isGuest && (_currentChapterIndex + 1) >= 2) {
                        _showRegisterPopup();
                        return;
                      }
                      _recordLearningTime();
                      await StreakTracker.trackKeypointCompleted(_book!.id, _currentChapterIndex);
                      setState(() {
                        _currentChapterIndex++;
                      });
                    },
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    label: Text(localizations.translate('next_chapter')),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () async {
                      _recordLearningTime();
                      await StreakTracker.trackKeypointCompleted(_book!.id, _currentChapterIndex);
                      await StreakTracker.trackBookCompleted(_book!.id);
                      AppLocator.auth.addCompletedBook(_book!.id);
                      if (context.mounted) {
                        await StreakTracker.checkAndShowStreakPopup(context);
                      }
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: Text(localizations.translate('finish_book')),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPanel(ThemeData theme) {
    final textColor = _isDarkReader ? Colors.white : Colors.black;
    final panelBgColor = _isDarkReader ? Colors.grey[900]! : Colors.grey[100]!;
    final borderColor = _isDarkReader ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: panelBgColor,
        border: Border(
          top: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Font Size Selector (Left side)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.remove, color: textColor, size: 20),
                onPressed: () {
                  if (_fontSize > 12.0) {
                    setState(() {
                      _fontSize -= 2.0;
                    });
                  }
                },
              ),
              Text(
                '${_fontSize.round()} A',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                icon: Icon(Icons.add, color: textColor, size: 20),
                onPressed: () {
                  if (_fontSize < 30.0) {
                    setState(() {
                      _fontSize += 2.0;
                    });
                  }
                },
              ),
            ],
          ),
          
          // Vertical Divider
          Container(
            height: 20,
            width: 1,
            color: borderColor,
          ),
          
          // Theme Selector (Right side)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Light Mode Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDarkReader = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: !_isDarkReader ? theme.colorScheme.secondary : Colors.grey.withOpacity(0.3),
                      width: !_isDarkReader ? 2.0 : 1.0,
                    ),
                  ),
                  child: const Text(
                    'Aa',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Dark Mode Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isDarkReader = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDarkReader ? theme.colorScheme.secondary : Colors.white.withOpacity(0.3),
                      width: _isDarkReader ? 2.0 : 1.0,
                    ),
                  ),
                  child: const Text(
                    'Aa',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Interactive highlight text reader
  Widget _buildReaderContent(String content) {
    final theme = Theme.of(context);

    if (AppLocator.auth.isGuest && _currentChapterIndex >= 2) {
      final loc = AppLocalizations.of(context)!;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isDarkReader ? Colors.grey[900] : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text(
              loc.translate('unlock_full_book'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isDarkReader ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              loc.translate('guest_restriction_desc'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _isDarkReader ? Colors.grey[400] : Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showRegisterPopup,
              child: Text(loc.translate('register_now')),
            ),
          ],
        ),
      );
    }

    final formattedContent = content
        .split('\n')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join('\n\n');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SelectableText(
        formattedContent,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontSize: _fontSize,
          height: 1.7,
          color: _isDarkReader ? Colors.white.withOpacity(0.9) : Colors.black87,
        ),
        onTap: () {
          if (_showSettingsPanel) {
            setState(() {
              _showSettingsPanel = false;
            });
          }
        },
        contextMenuBuilder: (BuildContext context, EditableTextState editableTextState) {
          final List<ContextMenuButtonItem> buttonItems = [
            ContextMenuButtonItem(
              label: 'Highlight',
              onPressed: () {
                final selectedText = editableTextState.textEditingValue.selection.textInside(editableTextState.textEditingValue.text);
                editableTextState.hideToolbar();
                _showHighlightOptionSheet(selectedText);
              },
            ),
          ];

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
      ),
    );
  }

  void _showHighlightOptionSheet(String selectedText) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;
    
    final titleText = langCode == 'ku' ? 'نیشانکردنی دەق' : (langCode == 'ar' ? 'إضاءة النص المحدد' : 'Highlight Selection');
    final buttonText = langCode == 'ku' ? 'نیشانکردن' : (langCode == 'ar' ? 'تحديد' : 'Highlight');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(titleText, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('"$selectedText"', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _colorOption(0xFFFFF176, 'Yellow', selectedText), // Light Yellow
                    _colorOption(0xFF81C784, 'Green', selectedText), // Light Green
                    _colorOption(0xFF64B5F6, 'Blue', selectedText), // Light Blue
                    _colorOption(0xFFF06292, 'Pink', selectedText), // Light Pink
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _addHighlight(selectedText, 0xFFFFF176); // Standard yellow
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.border_color, size: 18),
                    label: Text(buttonText),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _colorOption(int hex, String label, String selectedText) {
    return GestureDetector(
      onTap: () {
        // Save with selected color
        Navigator.of(context).pop();
        _addHighlight(selectedText, hex);
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Color(hex),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black26),
        ),
      ),
    );
  }
}
