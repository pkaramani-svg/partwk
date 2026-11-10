import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/services/protected_text_service.dart';
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
import '../profile/paywall_screen.dart';
import '../../core/widgets/partwk_toolbar_button.dart';

class SummaryReaderScreen extends StatefulWidget {
  final String bookId;
  final int initialChapterIndex;
  final String? languageCode;
  const SummaryReaderScreen({
    Key? key,
    required this.bookId,
    this.initialChapterIndex = 0,
    this.languageCode,
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
  String? _errorTitle;
  IconData? _errorIcon;
  String? _actionButtonText;
  VoidCallback? _customErrorAction;
  bool _isPremiumExpired = false;

  // Highlights state
  List<Highlight> _savedHighlights = [];
  String? _selectedText;

  // Notes state
  final TextEditingController _noteInputController = TextEditingController();

  DateTime? _chapterStartTime;

  @override
  void initState() {
    super.initState();
    final audioService = AppLocator.audio;
    if (audioService.isPlaying && audioService.currentBookId == widget.bookId) {
      _currentChapterIndex = audioService.currentChapterIndex;
    } else {
      _currentChapterIndex = widget.initialChapterIndex;
    }
    _chapterStartTime = DateTime.now();
    _loadBook();
    audioService.addListener(_onAudioServiceChanged);
  }

  void _onAudioServiceChanged() {
    final audioService = AppLocator.audio;
    if (audioService.isPlaying && audioService.currentBookId == widget.bookId) {
      if (_currentChapterIndex != audioService.currentChapterIndex) {
        if (mounted) {
          setState(() {
            _currentChapterIndex = audioService.currentChapterIndex;
          });
        }
      }
    }
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
      await AppLocator.auth.refreshEntitlementAuthoritatively();
      final books = await AppLocator.db.fetchBooks();
      var book = books.firstWhere((b) => b.id == widget.bookId);
      final user = AppLocator.auth.currentUser;
      if (user != null) {
        final hls = await AppLocator.db.fetchHighlights(user.id);
        setState(() {
          _savedHighlights = hls.where((h) => h.bookId == widget.bookId).toList();
        });
      }

      final activeLang = widget.languageCode ?? AppLocalizations.of(context)!.locale.languageCode;
      final hasNet = await NetworkGuard.hasConnection();

      if (!hasNet) {
        // App is genuinely offline: only load if exact edition is downloaded
        final isDownloaded = await DownloadManager.isEditionDownloaded(book.id, activeLang);
        if (isDownloaded) {
          try {
            book = await DownloadManager.loadBookContent(book, languageCode: activeLang);
          } on LicenceInvalidException catch (_) {
            setState(() {
              _licenceError = 'Connect to the internet to stream or download this edition.';
              _isLoading = false;
            });
            return;
          } on LicenceExpiredException catch (_) {
            setState(() {
              _licenceError = 'Your premium access has ended. Renew Premium to access downloaded summaries.';
              _isPremiumExpired = true;
              _isLoading = false;
            });
            return;
          } catch (_) {
            setState(() {
              _licenceError = 'Connect to the internet to stream or download this edition.';
              _isLoading = false;
            });
            return;
          }
        } else {
          setState(() {
            _licenceError = 'Connect to the internet to stream or download this edition.';
            _isLoading = false;
          });
          return;
        }
      } else {
        // App is online: load currently selected language from normal online source
        if (book.isPremium) {
          if (!mounted) return;
          book = await ProtectedTextService.hydrate(book, activeLang);
        }
      }

      if (mounted) {
        setState(() {
          _book = book;
          _coverProvider = DownloadService.getBookCoverProvider(book, langCode: activeLang);
          _isLoading = false;
        });
        AppLocator.auth.updatePresence(
          screen: 'Reading Summary',
          bookTitle: book.getTitle(activeLang),
          bookId: book.id,
          activityType: 'reading',
        );
        if (book.isPremium && AppLocator.auth.isGuest && _currentChapterIndex >= 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showRegisterPopup();
          });
        }
      }
    } on ContentPermissionDeniedException catch (e) {
      if (mounted) {
        setState(() {
          _errorTitle = 'Premium Access Required';
          _licenceError = e.message;
          _errorIcon = Icons.workspace_premium;
          _actionButtonText = 'Upgrade to Premium';
          _customErrorAction = () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const PaywallScreen()),
            );
          };
          _isLoading = false;
        });
      }
    } on ContentUnauthenticatedException catch (e) {
      if (mounted) {
        setState(() {
          _errorTitle = 'Sign In Required';
          _licenceError = e.message;
          _errorIcon = Icons.account_circle_outlined;
          _actionButtonText = 'Sign In';
          _customErrorAction = () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginRegisterScreen()),
            );
          };
          _isLoading = false;
        });
      }
    } on UnpublishedLanguageException catch (e) {
      if (mounted) {
        setState(() {
          _errorTitle = 'Language Unavailable';
          _licenceError = e.message;
          _errorIcon = Icons.translate;
          _actionButtonText = 'Go Back';
          _customErrorAction = null;
          _isLoading = false;
        });
      }
    } on ContentUnavailableException catch (e) {
      if (mounted) {
        setState(() {
          _errorTitle = 'Content Unavailable';
          _licenceError = e.message;
          _errorIcon = Icons.error_outline;
          _actionButtonText = 'Go Back';
          _customErrorAction = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final hasNet = await NetworkGuard.hasConnection();
        setState(() {
          if (!hasNet) {
            _errorTitle = 'Offline Mode';
            _licenceError = 'Connect to the internet to download or stream this title.';
            _errorIcon = Icons.wifi_off_outlined;
          } else {
            _errorTitle = 'Error Loading Title';
            _licenceError = 'Unable to load book text. Please try again.';
            _errorIcon = Icons.error_outline;
          }
          _actionButtonText = 'Go Back';
          _customErrorAction = null;
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
    AppLocator.audio.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final langCode = localizations.locale.languageCode;

    if (_licenceError != null) {
      final title = _errorTitle ?? (_isPremiumExpired ? 'Premium Expired' : 'Offline Mode');
      final icon = _errorIcon ?? (_isPremiumExpired ? Icons.lock_clock : Icons.wifi_off_outlined);
      final actionLabel = _actionButtonText ?? 'Go Back';
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: AppLocalizations.of(context)?.translate('back') ?? 'Back',
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
                  icon,
                  size: 80,
                  color: Colors.amber[800],
                ),
                const SizedBox(height: 24),
                Text(
                  title,
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
                  onPressed: _customErrorAction ?? () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(actionLabel),
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
        automaticallyImplyLeading: false,
        backgroundColor: _isDarkReader ? Colors.black : Colors.white,
        foregroundColor: _isDarkReader ? Colors.white : Colors.black,
        elevation: 0.5,
        titleSpacing: 16,
        title: Builder(
          builder: (context) {
            final chapters = _book!.getChapterSummaries(langCode);
            final currentChapterTitle = (chapters.isNotEmpty && _currentChapterIndex < chapters.length)
                ? (chapters[_currentChapterIndex]['title']?.toString() ?? '')
                : '';

            return Row(
              children: [
                PartwkToolbarButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: localizations.translate('back'),
                  size: 40,
                  iconSize: 22,
                  isDark: _isDarkReader,
                  onPressed: () async {
                    _recordLearningTime();
                    await StreakTracker.checkAndShowStreakPopup(context);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _book!.getTitle(langCode),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _isDarkReader ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (currentChapterTitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            currentChapterTitle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _isDarkReader ? Colors.grey[400] : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PartwkToolbarButton(
                  icon: Icons.headphones_rounded,
                  tooltip: localizations.translate('listen_chapter'),
                  size: 40,
                  isDark: _isDarkReader,
                  onPressed: () => _startAudioFromReader(langCode),
                ),
                const SizedBox(width: 8),
                PartwkToolbarButton(
                  icon: Icons.text_format_rounded,
                  tooltip: localizations.translate('reader_settings'),
                  size: 40,
                  isDark: _isDarkReader,
                  isActive: _showSettingsPanel,
                  onPressed: () {
                    setState(() {
                      _showSettingsPanel = !_showSettingsPanel;
                    });
                  },
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: localizations.translate('more_options'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _isDarkReader ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  color: _isDarkReader ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 8,
                  offset: const Offset(0, 48),
                  onSelected: (value) {
                    if (value == 'quiz') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => QuizScreen(bookId: _book!.id)),
                      );
                    } else if (value == 'flashcards') {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => FlashcardsScreen(bookId: _book!.id)),
                      );
                    } else if (value == 'note') {
                      _showAddNoteDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'quiz',
                      child: Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 20,
                            color: _isDarkReader ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            localizations.translate('quiz'),
                            style: TextStyle(
                              color: _isDarkReader ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'flashcards',
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 20,
                            color: _isDarkReader ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            localizations.translate('flashcards'),
                            style: TextStyle(
                              color: _isDarkReader ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'note',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 20,
                            color: _isDarkReader ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            localizations.translate('add_note'),
                            style: TextStyle(
                              color: _isDarkReader ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: IgnorePointer(
                    child: PartwkToolbarButton(
                      icon: Icons.more_horiz_rounded,
                      tooltip: localizations.translate('more_options'),
                      size: 40,
                      isDark: _isDarkReader,
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: _buildSingleChapterView(langCode),
      ),
    );
  }

  void _startAudioFromReader(String langCode) {
    final chapters = _book!.getChapterSummaries(langCode).cast<Map<String, dynamic>>();
    final globalAudioUrl = _book!.getAudioUrl(langCode);
    final coverUrl = _book!.getCoverImageUrl(langCode);
    final audioService = AppLocator.audio;
    
    final isCurrentBook = audioService.currentBookId == _book!.id && audioService.currentLangCode == langCode;
    
    int initialIndex = _currentChapterIndex;
    int startPos = 0;

    if (isCurrentBook) {
      initialIndex = audioService.currentChapterIndex;
      startPos = audioService.position.inSeconds;
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
        isPremium: _book!.isPremium,
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
        initialChapterIndex: initialIndex,
        initialPositionSecs: startPos,
        bookDurationSecs: _book!.getDurationForLanguage(langCode),
        isPremium: _book!.isPremium,
      ),
    ));
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
                    onPressed: () => _updateChapterIndex(_currentChapterIndex - 1, chapters, langCode),
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
                      if (_book!.isPremium && AppLocator.auth.isGuest && (_currentChapterIndex + 1) >= 2) {
                        _showRegisterPopup();
                        return;
                      }
                      await StreakTracker.trackKeypointCompleted(_book!.id, _currentChapterIndex);
                      _updateChapterIndex(_currentChapterIndex + 1, chapters, langCode);
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
    final loc = AppLocalizations.of(context)!;

    if ((_book?.isPremium == true) && AppLocator.auth.isGuest && _currentChapterIndex >= 2) {
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

    final langCode = loc.locale.languageCode;

    final isRtl = langCode == 'ku' || langCode == 'ar';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: SelectionArea(
          onSelectionChanged: (SelectedContent? selection) {
            _selectedText = selection?.plainText;
          },
          contextMenuBuilder: (BuildContext context, SelectableRegionState selectableRegionState) {
            final List<ContextMenuButtonItem> buttonItems = [
              ContextMenuButtonItem(
                label: loc.translate('define'),
                onPressed: () {
                  selectableRegionState.hideToolbar();
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    _showDefinitionPopup(_selectedText!);
                  }
                },
              ),
              ContextMenuButtonItem(
                label: loc.translate('highlight'),
                onPressed: () {
                  selectableRegionState.hideToolbar();
                  if (_selectedText != null && _selectedText!.isNotEmpty) {
                    _showHighlightOptionSheet(_selectedText!);
                  }
                },
              ),
            ];

            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
          child: Text(
            formattedContent,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: _fontSize,
              height: 1.7,
              color: _isDarkReader ? Colors.white.withOpacity(0.9) : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  void _showDefinitionPopup(String selectedText) {
    final words = selectedText.trim().split(RegExp(r'\s+'));
    final rawWord = words.isNotEmpty ? words.first : selectedText;
    final cleanWord = rawWord.trim().replaceAll(RegExp(r'[^\w\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF\u0720-\u072F]'), '');
    if (cleanWord.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final loc = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final langCode = loc.locale.languageCode;

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320, maxHeight: 280),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _isDarkReader ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FutureBuilder<String?>(
              future: AppLocator.db.getDefinition(cleanWord, langCode),
              builder: (context, snapshot) {
                final isLoading = snapshot.connectionState == ConnectionState.waiting;
                final definition = snapshot.data;

                return Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              cleanWord,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _isDarkReader ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 20, color: _isDarkReader ? Colors.white60 : Colors.black54),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: isLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _buildDefinitionContent(definition, theme, loc),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefinitionContent(String? definition, ThemeData theme, AppLocalizations loc) {
    if (definition == null || definition.isEmpty) {
      return Text(
        loc.translate('definition_not_found'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.redAccent,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (definition.startsWith('{') && definition.endsWith('}')) {
      try {
        final Map<String, dynamic> data = jsonDecode(definition);
        if (data['is_structured'] == true) {
          final word = data['word'] as String;
          final dialect = data['dialect_tag'] as String;
          final pos = data['part_of_speech'] as String;
          final defCkb = data['definition_ckb'] as String;
          final synonyms = List<String>.from(data['synonyms'] ?? []);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      pos.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dialect,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _isDarkReader ? Colors.grey[400] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                defCkb,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _isDarkReader ? Colors.grey[200] : Colors.black87,
                  height: 1.6,
                  fontSize: 15,
                ),
              ),
              if (synonyms.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  loc.translate('synonyms') ?? 'هاوواتاکان',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isDarkReader ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: synonyms.map((syn) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        syn,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _isDarkReader ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        }
      } catch (_) {}
    }

    return Text(
      definition,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _isDarkReader ? Colors.grey[300] : Colors.black87,
        height: 1.5,
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

  void _updateChapterIndex(int newIndex, List<Map<String, dynamic>> chapters, String langCode) {
    _recordLearningTime();
    setState(() {
      _currentChapterIndex = newIndex;
    });

    // Synchronize audio playback to this index if audio is playing for this book
    final audioService = AppLocator.audio;
    if (audioService.isPlaying && audioService.currentBookId == _book!.id) {
      audioService.removeListener(_onAudioServiceChanged);
      
      final globalAudioUrl = _book!.getAudioUrl(langCode);
      final coverUrl = _book!.getCoverImageUrl(langCode);
      
      audioService.play(
        _book!.id,
        langCode,
        _book!.getTitle(langCode),
        coverUrl,
        globalAudioUrl,
        chapters,
        startIndex: newIndex,
        startPosition: 0,
        bookDurationSecs: _book!.getDurationForLanguage(langCode),
      );
      
      audioService.addListener(_onAudioServiceChanged);
    }
  }
}
