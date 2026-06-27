import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/service_locator.dart';
import '../profile/settings_screen.dart';
import '../auth/login_register_screen.dart';
import '../../services/download_service.dart';
import '../book/summary_reader_screen.dart';
import '../../core/services/streak_tracker.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String coverUrl;
  final String globalAudioUrl;
  final List<Map<String, dynamic>> chapters;
  final String langCode;
  final int initialChapterIndex;
  final int initialPositionSecs;
  final int bookDurationSecs;

  const AudioPlayerScreen({
    Key? key,
    required this.bookId,
    required this.langCode,
    required this.bookTitle,
    required this.coverUrl,
    required this.globalAudioUrl,
    required this.chapters,
    this.initialChapterIndex = 0,
    this.initialPositionSecs = 0,
    this.bookDurationSecs = 0,
  }) : super(key: key);

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _diskController;
  String _selectedVoice = 'Standard Narrator';

  bool _isTextPanelOpen = false;
  int _lastActiveSegmentIndex = -1;
  final List<GlobalKey> _segmentKeys = [];
  final ScrollController _textScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _diskController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );

    // Sync disk spin with playing state
    if (AppLocator.audio.isPlaying && AppLocator.audio.currentBookId == widget.bookId && AppLocator.audio.currentLangCode == widget.langCode) {
      _diskController.repeat();
    }

    AppLocator.audio.addListener(_audioServiceListener);
  }

  void _audioServiceListener() {
    if (AppLocator.audio.isGuestRestricted) {
      AppLocator.audio.clearGuestRestriction();
      _showRegisterPopup();
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
                Navigator.pop(context); // Close dialog
                AppLocator.audio.stop();
                // Navigate to Login Register Screen
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

  @override
  void dispose() {
    AppLocator.audio.removeListener(_audioServiceListener);
    _diskController.dispose();
    _textScrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showChaptersList(BuildContext context, AudioService audioService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Chapters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final isPlayingThisChapter = audioService.currentChapterIndex == index;
                    return ListTile(
                      leading: Icon(
                        isPlayingThisChapter ? Icons.volume_up : Icons.format_list_numbered,
                        color: isPlayingThisChapter ? Theme.of(context).colorScheme.secondary : Colors.grey,
                      ),
                      title: Text(
                        widget.chapters[index]['title'] ?? _getChapterFallback(index, widget.langCode),
                        style: TextStyle(
                          fontWeight: isPlayingThisChapter ? FontWeight.bold : FontWeight.normal,
                          color: isPlayingThisChapter ? Theme.of(context).colorScheme.secondary : null,
                        ),
                      ),
                      onTap: () {
                        if (AppLocator.audio.currentBookId != widget.bookId || AppLocator.audio.currentChapterIndex != index || AppLocator.audio.currentLangCode != widget.langCode) {
                          AppLocator.audio.play(widget.bookId, widget.langCode, widget.bookTitle, widget.coverUrl, widget.globalAudioUrl, widget.chapters, startIndex: index, bookDurationSecs: widget.bookDurationSecs);
                        }
                        Navigator.pop(context);
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

  void _showSleepTimerDialog(BuildContext context, AudioService audioService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Sleep Timer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.timer_off),
                title: const Text('Off'),
                onTap: () {
                  audioService.clearSleepTimer();
                  Navigator.pop(context);
                },
              ),
              _buildTimerOption(context, audioService, '5 Minutes', const Duration(minutes: 5)),
              _buildTimerOption(context, audioService, '10 Minutes', const Duration(minutes: 10)),
              _buildTimerOption(context, audioService, '15 Minutes', const Duration(minutes: 15)),
              _buildTimerOption(context, audioService, '30 Minutes', const Duration(minutes: 30)),
              _buildTimerOption(context, audioService, '60 Minutes', const Duration(minutes: 60)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimerOption(BuildContext context, AudioService audioService, String title, Duration duration) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(title),
      onTap: () {
        audioService.setSleepTimer(duration);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sleep timer set for $title')));
      },
    );
  }

  bool _hasSegments(AudioService audioService) {
    if (widget.chapters.isEmpty || audioService.currentChapterIndex >= widget.chapters.length) {
      return false;
    }
    final ch = widget.chapters[audioService.currentChapterIndex];
    final segs = ch['segments'];
    if (segs != null && segs is List && segs.isNotEmpty) {
      return true;
    }
    final content = ch['content'];
    return content != null && content is String && content.trim().isNotEmpty;
  }

  List<dynamic> _getSegmentsForChapter(Map<String, dynamic> ch, int chapterDurationSecs, int chapterIndex) {
    final segs = ch['segments'];
    if (segs != null && segs is List && segs.isNotEmpty) {
      return segs;
    }
    final content = ch['content'] as String? ?? '';
    final paragraphs = content
        .split(RegExp(r'\r?\n\r?\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    
    List<String> finalParagraphs = paragraphs;
    if (paragraphs.length <= 1) {
      final singleLines = content
          .split('\n')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (singleLines.length > 1) {
        finalParagraphs = singleLines;
      }
    }

    if (finalParagraphs.isEmpty) return [];

    // Calculate total character length
    final int totalChars = finalParagraphs.fold<int>(0, (prev, element) => prev + element.length);
    if (totalChars == 0) {
      return finalParagraphs.map((p) => {
        'text': p,
        'startTime': 0,
        'endTime': 0,
      }).toList();
    }

    // First, calculate raw contiguous end times based on character lengths
    final List<int> rawEndTimes = [];
    int accum = 0;
    for (int i = 0; i < finalParagraphs.length; i++) {
      final double ratio = finalParagraphs[i].length / totalChars;
      final int duration = (chapterDurationSecs * ratio).round();
      accum += duration;
      rawEndTimes.add(accum);
    }
    // Force the last end time to match exact chapter duration
    if (rawEndTimes.isNotEmpty) {
      rawEndTimes[rawEndTimes.length - 1] = chapterDurationSecs;
    }

    // Construct segments with a start offset buffer to prevent playing previous paragraph's tail
    int prevEnd = 0;
    final List<Map<String, dynamic>> generatedSegments = [];
    for (int i = 0; i < finalParagraphs.length; i++) {
      final paragraph = finalParagraphs[i];
      final rawEnd = rawEndTimes[i];
      final duration = rawEnd - prevEnd;
      
      // Calculate buffer offset to shift start time forward (dynamic by chapter type)
      int offset = 0;
      if (i > 0) {
        final maxOffset = (duration * 0.25).round();
        final limit = chapterIndex == 0 ? 3 : 2;
        offset = maxOffset > limit ? limit : maxOffset;
      }
      
      final startTime = prevEnd + offset;
      
      // Adjust the previous segment's endTime to match this segment's startTime
      // to keep highlighting continuous.
      if (i > 0 && generatedSegments.isNotEmpty) {
        generatedSegments[i - 1]['endTime'] = startTime;
      }
      
      generatedSegments.add({
        'text': paragraph,
        'startTime': startTime,
        'endTime': rawEnd,
      });
      
      prevEnd = rawEnd;
    }

    return generatedSegments;
  }

  void _syncSegmentKeys(List<dynamic> segments) {
    if (_segmentKeys.length != segments.length) {
      _segmentKeys.clear();
      for (int i = 0; i < segments.length; i++) {
        _segmentKeys.add(GlobalKey());
      }
      _lastActiveSegmentIndex = -1;
    }
  }

  void _toggleTextPanel() {
    setState(() {
      _isTextPanelOpen = !_isTextPanelOpen;
    });
    if (_isTextPanelOpen && _lastActiveSegmentIndex >= 0 && _lastActiveSegmentIndex < _segmentKeys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final keyContext = _segmentKeys[_lastActiveSegmentIndex].currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 300),
            alignment: 0.3,
          );
        }
      });
    }
  }

  Widget _buildExpandableTextPanel({
    required bool hasSegments,
    required List<dynamic> segments,
    required int activeSegmentIndex,
    required ThemeData theme,
    required AudioService audioService,
  }) {
    final bool isRtl = widget.langCode == 'ar' || widget.langCode == 'ku' || widget.langCode == 'ckb' || widget.langCode == 'sorani';
    final TextDirection textDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
    final localizations = AppLocalizations.of(context)!;

    return Directionality(
      textDirection: textDirection,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            if (!_isTextPanelOpen) _toggleTextPanel();
          } else if (details.primaryVelocity! > 0) {
            if (_isTextPanelOpen) _toggleTextPanel();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isTextPanelOpen ? MediaQuery.of(context).size.height * 0.45 : 64.0,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _toggleTextPanel,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isTextPanelOpen ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: theme.colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isTextPanelOpen
                                ? localizations.translate('hide_text')
                                : localizations.translate('show_text'),
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isTextPanelOpen)
                Expanded(
                  child: ListView.builder(
                    controller: _textScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: segments.length,
                    itemBuilder: (context, idx) {
                      final seg = segments[idx];
                      final isActive = idx == activeSegmentIndex;
                      final isCompleted = idx < activeSegmentIndex;

                      return _buildSegmentWidget(
                        segment: seg,
                        index: idx,
                        isActive: isActive,
                        isCompleted: isCompleted,
                        isRtl: isRtl,
                        theme: theme,
                        audioService: audioService,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentWidget({
    required dynamic segment,
    required int index,
    required bool isActive,
    required bool isCompleted,
    required bool isRtl,
    required ThemeData theme,
    required AudioService audioService,
  }) {
    final startTimeVal = (segment['startTime'] as num?)?.round() ?? -1;
    final bool hasTimestamp = startTimeVal >= 0;

    final textColor = !hasTimestamp
        ? theme.textTheme.bodyLarge?.color
        : isActive
            ? theme.colorScheme.secondary
            : isCompleted
                ? theme.textTheme.bodyLarge?.color?.withOpacity(0.4)
                : theme.textTheme.bodyLarge?.color;

    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      height: 1.6,
      color: textColor,
      fontWeight: (isActive && hasTimestamp) ? FontWeight.bold : FontWeight.normal,
    );

    const double indicatorWidth = 4.0;
    const double spacingWidth = 8.0;

    Widget segmentContent = Column(
      crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (segment['title'] != null && (segment['title'] as String).isNotEmpty) ...[
          Text(
            segment['title'] as String,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          segment['text'] as String? ?? '',
          style: textStyle,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
        ),
      ],
    );

    if (isActive && hasTimestamp) {
      segmentContent = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isRtl) ...[
              Container(
                width: indicatorWidth,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: spacingWidth),
            ],
            Expanded(child: segmentContent),
            if (isRtl) ...[
              const SizedBox(width: spacingWidth),
              Container(
                width: indicatorWidth,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return InkWell(
      key: _segmentKeys[index],
      onTap: !hasTimestamp
          ? null
          : () {
              audioService.seek(Duration(seconds: startTimeVal));
              setState(() {
                _lastActiveSegmentIndex = index;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.only(
          left: isRtl ? 16 : ((isActive && hasTimestamp) ? 0 : 12),
          right: isRtl ? ((isActive && hasTimestamp) ? 0 : 12) : 16,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: (isActive && hasTimestamp) ? theme.colorScheme.secondary.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: segmentContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    return ChangeNotifierProvider<AudioService>.value(
      value: AppLocator.audio,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await StreakTracker.checkAndShowStreakPopup(context);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(localizations.translate('listen_audio')),
            elevation: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 28),
                onPressed: () async {
                  await StreakTracker.checkAndShowStreakPopup(ctx);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ),
            actions: [
              Consumer<AudioService>(
                builder: (context, audioService, _) {
                  final isTimerActive = audioService.sleepTimerRemaining != null;
                  return Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_book_outlined),
                        tooltip: 'Read Summary',
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => SummaryReaderScreen(
                                bookId: widget.bookId,
                                initialChapterIndex: audioService.currentChapterIndex,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted),
                        tooltip: localizations.translate('chapters'),
                        onPressed: () => _showChaptersList(context, audioService),
                      ),
                      if (isTimerActive)
                        Text(
                          _formatDuration(audioService.sleepTimerRemaining!),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                        ),
                      IconButton(
                        icon: Icon(isTimerActive ? Icons.timer : Icons.bedtime_outlined),
                        color: isTimerActive ? theme.colorScheme.secondary : null,
                      tooltip: 'Sleep Timer',
                      onPressed: () => _showSleepTimerDialog(context, audioService),
                    ),
                  ],
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            )
          ],
        ),
        body: Consumer<AudioService>(
          builder: (context, audioService, child) {
            final isPlaying = audioService.isPlaying && audioService.currentBookId == widget.bookId;
            
            // Toggle disk animation
            if (isPlaying) {
              _diskController.repeat();
            } else {
              _diskController.stop();
            }

            final progressVal = audioService.duration.inSeconds > 0
                ? audioService.position.inSeconds / audioService.duration.inSeconds
                : 0.0;

            final hasSegments = _hasSegments(audioService);
            List<dynamic> segments = [];
            int activeSegmentIndex = -1;

            if (hasSegments) {
              final ch = widget.chapters[audioService.currentChapterIndex];
              final int chDuration = ch['duration'] is int
                  ? ch['duration'] as int
                  : (ch['duration'] as num?)?.toInt() ?? 0;
              final int durationToUse = chDuration > 0
                  ? chDuration
                  : (audioService.duration.inSeconds > 0
                      ? audioService.duration.inSeconds
                      : (widget.bookDurationSecs > 0
                          ? (widget.chapters.isNotEmpty ? (widget.bookDurationSecs / widget.chapters.length).round() : widget.bookDurationSecs)
                          : 180));
              segments = _getSegmentsForChapter(ch, durationToUse, audioService.currentChapterIndex);
              _syncSegmentKeys(segments);

              final currentSeconds = audioService.position.inSeconds;
              for (int i = 0; i < segments.length; i++) {
                final seg = segments[i];
                final start = (seg['startTime'] as num?)?.round() ?? 0;
                final end = (seg['endTime'] as num?)?.round() ?? 0;
                if (currentSeconds >= start && currentSeconds < end) {
                  activeSegmentIndex = i;
                  break;
                }
              }

              // Auto-scroll when active segment changes
              if (activeSegmentIndex != _lastActiveSegmentIndex) {
                _lastActiveSegmentIndex = activeSegmentIndex;
                if (_isTextPanelOpen && activeSegmentIndex >= 0 && activeSegmentIndex < _segmentKeys.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final keyContext = _segmentKeys[activeSegmentIndex].currentContext;
                    if (keyContext != null) {
                      Scrollable.ensureVisible(
                        keyContext,
                        duration: const Duration(milliseconds: 300),
                        alignment: 0.3,
                      );
                    }
                  });
                }
              }
            }

            if (hasSegments) {
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: _isTextPanelOpen ? 4 : 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          // Book Cover with animated size based on panel opening
                          if (widget.coverUrl.isNotEmpty)
                            Center(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: _isTextPanelOpen ? 0 : (screenHeight < 700 ? 160 : (screenHeight < 800 ? 200 : 280)),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _isTextPanelOpen
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 24,
                                            offset: const Offset(0, 12),
                                          ),
                                        ],
                                ),
                                child: _isTextPanelOpen
                                    ? const SizedBox.shrink()
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: DownloadService.isBookDownloadedSync(widget.bookId)
                                              ? Image.file(
                                                  DownloadService.getLocalCoverFileSync(widget.bookId),
                                                  height: _isTextPanelOpen ? 0 : (screenHeight < 700 ? 160 : (screenHeight < 800 ? 200 : 280)),
                                                  fit: BoxFit.contain,
                                                )
                                              : Image.network(
                                                  widget.coverUrl,
                                                  height: _isTextPanelOpen ? 0 : (screenHeight < 700 ? 160 : (screenHeight < 800 ? 200 : 280)),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      height: _isTextPanelOpen ? 0 : (screenHeight < 700 ? 160 : (screenHeight < 800 ? 200 : 280)),
                                                      color: Colors.grey[900],
                                                      alignment: Alignment.center,
                                                      child: const Icon(Icons.music_note, color: Colors.white, size: 80),
                                                    );
                                                  },
                                                ),
                                        ),
                              ),
                            ),
                          SizedBox(height: _isTextPanelOpen ? 0 : (screenHeight < 700 ? 12 : 24)),

                          // Title and Author info
                          Text(
                            widget.bookTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showChaptersList(context, audioService),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.chapters.isNotEmpty && audioService.currentChapterIndex < widget.chapters.length
                                      ? widget.chapters[audioService.currentChapterIndex]['title'] ?? _getChapterFallback(audioService.currentChapterIndex, widget.langCode)
                                      : localizations.translate('chapter'),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, size: 18, color: theme.colorScheme.secondary),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: _isTextPanelOpen ? 0 : 8),
                          
                          const Spacer(),

                          // Progress seek slider
                          Slider(
                            value: progressVal.clamp(0.0, 1.0),
                            onChanged: (val) {
                              final newSec = (val * audioService.duration.inSeconds).round();
                              audioService.seek(Duration(seconds: newSec));
                            },
                            activeColor: theme.colorScheme.secondary,
                            inactiveColor: theme.colorScheme.secondary.withOpacity(0.2),
                          ),
                          
                          // Duration label numbers
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(audioService.position),
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Text(
                                  _formatDuration(audioService.duration),
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: _isTextPanelOpen ? 0 : 16),

                          // Playback media keys with Wrap to prevent overflow
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous, size: 32),
                                onPressed: () {
                                  audioService.previousChapter();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.replay_10, size: 28),
                                onPressed: () {
                                  audioService.seek(audioService.position - const Duration(seconds: 15));
                                },
                              ),
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: theme.colorScheme.secondary,
                                child: IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    size: 32,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    bool isSameBookAndLang = audioService.currentBookId == widget.bookId && audioService.currentLangCode == widget.langCode;
                                    if (isPlaying && isSameBookAndLang) {
                                      audioService.pause();
                                      StreakTracker.checkAndShowStreakPopup(context);
                                    } else {
                                      if (isSameBookAndLang) {
                                        audioService.resume();
                                      } else {
                                        audioService.play(
                                          widget.bookId, 
                                          widget.langCode, 
                                          widget.bookTitle, 
                                          widget.coverUrl, 
                                          widget.globalAudioUrl, 
                                          widget.chapters,
                                          startIndex: widget.initialChapterIndex,
                                          startPosition: widget.initialPositionSecs,
                                          bookDurationSecs: widget.bookDurationSecs,
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10, size: 28),
                                onPressed: () {
                                  audioService.seek(audioService.position + const Duration(seconds: 15));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_next, size: 32),
                                onPressed: () {
                                  audioService.nextChapter();
                                },
                              ),
                            ],
                          ),
                          
                          const Spacer(),

                          // Playback Speed controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.speed, size: 20),
                              const SizedBox(width: 8),
                              DropdownButton<double>(
                                value: audioService.speed,
                                items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((double val) {
                                  return DropdownMenuItem<double>(
                                    value: val,
                                    child: Text('${val}x'),
                                  );
                                }).toList(),
                                onChanged: (double? newSpeed) {
                                  if (newSpeed != null) {
                                    audioService.setSpeed(newSpeed);
                                  }
                                },
                                underline: const SizedBox(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildExpandableTextPanel(
                    hasSegments: hasSegments,
                    segments: segments,
                    activeSegmentIndex: activeSegmentIndex,
                    theme: theme,
                    audioService: audioService,
                  ),
                ],
              );
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    if (widget.coverUrl.isNotEmpty)
                      Center(
                        child: Container(
                          height: screenHeight < 700 ? 130 : (screenHeight < 800 ? 180 : 250),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: DownloadService.isBookDownloadedSync(widget.bookId)
                                ? Image.file(
                                    DownloadService.getLocalCoverFileSync(widget.bookId),
                                    height: screenHeight < 700 ? 130 : (screenHeight < 800 ? 180 : 250),
                                    fit: BoxFit.contain,
                                  )
                                : Image.network(
                                    widget.coverUrl,
                                    height: screenHeight < 700 ? 130 : (screenHeight < 800 ? 180 : 250),
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: screenHeight < 700 ? 130 : (screenHeight < 800 ? 180 : 250),
                                        color: Colors.grey[900],
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.music_note, color: Colors.white, size: 80),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                    SizedBox(height: screenHeight < 700 ? 12 : 24),

                    Text(
                      widget.bookTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showChaptersList(context, audioService),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.chapters.isNotEmpty && audioService.currentChapterIndex < widget.chapters.length
                                ? widget.chapters[audioService.currentChapterIndex]['title'] ?? _getChapterFallback(audioService.currentChapterIndex, widget.langCode)
                                : localizations.translate('chapter'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_down, size: 18, color: theme.colorScheme.secondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    const Spacer(),

                    Slider(
                      value: progressVal.clamp(0.0, 1.0),
                      onChanged: (val) {
                        final newSec = (val * audioService.duration.inSeconds).round();
                        audioService.seek(Duration(seconds: newSec));
                      },
                      activeColor: theme.colorScheme.secondary,
                      inactiveColor: theme.colorScheme.secondary.withOpacity(0.2),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(audioService.position),
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            _formatDuration(audioService.duration),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 32),
                          onPressed: () {
                            audioService.previousChapter();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay_10, size: 28),
                          onPressed: () {
                            audioService.seek(audioService.position - const Duration(seconds: 15));
                          },
                        ),
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.secondary,
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 32,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              bool isSameBookAndLang = audioService.currentBookId == widget.bookId && audioService.currentLangCode == widget.langCode;
                              if (isPlaying && isSameBookAndLang) {
                                audioService.pause();
                                StreakTracker.checkAndShowStreakPopup(context);
                              } else {
                                if (isSameBookAndLang) {
                                  audioService.resume();
                                } else {
                                  audioService.play(
                                    widget.bookId, 
                                    widget.langCode, 
                                    widget.bookTitle, 
                                    widget.coverUrl, 
                                    widget.globalAudioUrl, 
                                    widget.chapters,
                                    startIndex: widget.initialChapterIndex,
                                    startPosition: widget.initialPositionSecs,
                                    bookDurationSecs: widget.bookDurationSecs,
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10, size: 28),
                          onPressed: () {
                            audioService.seek(audioService.position + const Duration(seconds: 15));
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 32),
                          onPressed: () {
                            audioService.nextChapter();
                          },
                        ),
                      ],
                    ),
                    
                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.speed, size: 20),
                        const SizedBox(width: 8),
                        DropdownButton<double>(
                          value: audioService.speed,
                          items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((double val) {
                            return DropdownMenuItem<double>(
                              value: val,
                              child: Text('${val}x'),
                            );
                          }).toList(),
                          onChanged: (double? newSpeed) {
                            if (newSpeed != null) {
                              audioService.setSpeed(newSpeed);
                            }
                          },
                          underline: const SizedBox(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (widget.chapters.isNotEmpty && audioService.currentChapterIndex < widget.chapters.length)
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              widget.chapters[audioService.currentChapterIndex]['content'] ?? '',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    ),
  );
}

  String _getChapterFallback(int idx, String langCode) {
    final indexStr = '${idx + 1}';
    if (langCode == 'ku') return 'خاڵی سەرەکی $indexStr';
    if (langCode == 'ar') return 'النقطة الرئيسية $indexStr';
    return 'Key Point $indexStr';
  }
}
