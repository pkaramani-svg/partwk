import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_locator.dart';
import 'streak_tracker.dart';
import 'download_manager.dart';
import 'network_guard.dart';
import '../../services/download_service.dart';

abstract class AudioService extends ChangeNotifier {
  bool get isPlaying;
  double get speed;
  Duration get position;
  Duration get duration;
  String? get currentBookId;
  String? get currentLangCode;
  String? get currentBookTitle;
  String? get currentCoverUrl;
  int get currentChapterIndex;
  List<Map<String, dynamic>> get chapters;

  Duration? get sleepTimerRemaining;

  bool get isCurrentBookPremium;
  bool get isGuestRestricted;
  void clearGuestRestriction();

  Future<void> init();
  Future<void> clearState();
  void play(String bookId, String langCode, String bookTitle, String coverUrl,
      String globalAudioUrl, List<Map<String, dynamic>> bookChapters,
      {int startIndex = 0, int startPosition = 0, int bookDurationSecs = 0, bool isPremium = false});
  void pause();
  void resume();
  void stop();
  void setSpeed(double speed);
  void seek(Duration position);
  void nextChapter();
  void previousChapter();

  void setSleepTimer(Duration duration);
  void clearSleepTimer();
}

class RealAudioService extends AudioService {
  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _currentBookId;
  String? _currentLangCode;
  String? _currentBookTitle;
  String? _currentCoverUrl;
  String? _globalAudioUrl;
  int _currentChapterIndex = 0;
  List<Map<String, dynamic>> _chapters = [];
  int _bookDurationSecs = 0;
  int _accumulatedSecondHalfSeconds = 0;
  String? _playbackOwnerId;
  int _playbackGeneration = 0;
  final List<StreamSubscription<dynamic>> _playerSubscriptions = [];

  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _isGuestRestricted = false;
  bool _isCurrentBookPremium = false;
  DateTime? _lastPlayTime;
  DateTime _lastSaveTime = DateTime.now();

  @override
  Future<void> init() async {
    try {
      final ownerId = AppLocator.auth.currentUser?.id;
      final generation = _playbackGeneration;
      final prefs = await SharedPreferences.getInstance();
      if (generation != _playbackGeneration || AppLocator.auth.currentUser?.id != ownerId) return;
      final userId = ownerId ?? 'guest';
      final prefix = 'audio_${userId}_';
      
      _currentBookId = prefs.getString('${prefix}book_id');
      if (_currentBookId != null) {
        _playbackOwnerId = ownerId;
        _currentLangCode = prefs.getString('${prefix}lang_code');
        _currentBookTitle = prefs.getString('${prefix}book_title');
        _currentCoverUrl = prefs.getString('${prefix}cover_url');
        _globalAudioUrl = prefs.getString('${prefix}global_url');
        _bookDurationSecs = prefs.getInt('${prefix}book_duration') ?? 0;
        _isCurrentBookPremium = prefs.getBool('${prefix}is_premium') ?? false;
        _currentChapterIndex = prefs.getInt('${prefix}chapter_index') ?? 0;
        int savedPos = prefs.getInt('${prefix}position_secs') ?? 0;

        final chaptersJson = prefs.getString('${prefix}chapters');
        if (chaptersJson != null) {
          final List<dynamic> decoded = jsonDecode(chaptersJson);
          _chapters = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        if (_chapters.isNotEmpty) {
          _loadPlaylistSilently(savedPos);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading audio state: $e');
    }
  }

  Future<void> _loadPlaylistSilently(int savedPos) async {
    final generation = _playbackGeneration;
    final ownerId = _playbackOwnerId;
    try {
      final List<AudioSource> playlistChildren = [];
      for (int idx = 0; idx < _chapters.length; idx++) {
        final ch = _chapters[idx];
        String? url = ch['audioUrl'] as String?;
        if (url == null || url.isEmpty) {
          url = _globalAudioUrl ?? '';
        }
        final String chapterTitle = ch['title'] is Map
            ? (ch['title'][_currentLangCode ?? 'en'] ?? _getFallbackChapterTitle(idx, _currentLangCode))
            : _getFallbackChapterTitle(idx, _currentLangCode);
        final mediaItem = MediaItem(
          id: '${_currentBookId}_$idx',
          album: _currentBookTitle ?? '',
          title: chapterTitle,
          artUri: _currentCoverUrl != null && _currentCoverUrl!.isNotEmpty
              ? Uri.parse(_currentCoverUrl!)
              : null,
        );

        final lang = _currentLangCode ?? 'en';
        final isLocal = DownloadService.isEditionDownloadedSync(_currentBookId!, lang) &&
            DownloadService.getLocalAudioFileIfExists(_currentBookId!, lang) != null;

        if (url.startsWith('http')) {
          if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS') &&
              !['10.0.2.2', '127.0.0.1', 'localhost'].contains(Uri.parse(url).host)) {
            throw StateError('External audio is disabled in isolated tests.');
          }
          playlistChildren.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
        } else if (isLocal || url.startsWith('file://')) {
          try {
            final source = await DownloadManager.loadAudioSource(
              _currentBookId!,
              lang,
              mediaItem,
            );
            playlistChildren.add(source);
          } catch (e) {
            playlistChildren.add(AudioSource.uri(
              Uri.parse('asset:///assets/audio/sample.wav'),
              tag: mediaItem,
            ));
          }
        } else {
          playlistChildren.add(AudioSource.uri(
              Uri.parse('asset:///assets/audio/sample.wav'),
              tag: mediaItem));
        }
      }

      final playlist = ConcatenatingAudioSource(children: playlistChildren);
      if (generation != _playbackGeneration || ownerId != AppLocator.auth.currentUser?.id) return;
      await _player.setAudioSource(playlist,
          initialIndex: _currentChapterIndex,
          initialPosition: Duration(seconds: savedPos));
    } catch (e, stack) {
      debugPrint('Error restoring audio playlist: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _saveState() async {
    final bookId = _currentBookId;
    final ownerId = _playbackOwnerId;
    final generation = _playbackGeneration;
    if (bookId == null || ownerId == null || AppLocator.auth.currentUser?.id != ownerId) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_playbackGeneration != generation || _playbackOwnerId != ownerId || AppLocator.auth.currentUser?.id != ownerId) return;
      final prefix = 'audio_${ownerId}_';
      
      prefs.setString('${prefix}book_id', bookId);
      prefs.setString('${prefix}lang_code', _currentLangCode ?? 'en');
      prefs.setString('${prefix}book_title', _currentBookTitle ?? '');
      prefs.setString('${prefix}cover_url', _currentCoverUrl ?? '');
      prefs.setString('${prefix}global_url', _globalAudioUrl ?? '');
      prefs.setInt('${prefix}book_duration', _bookDurationSecs);
      prefs.setBool('${prefix}is_premium', _isCurrentBookPremium);
      prefs.setInt('${prefix}chapter_index', _currentChapterIndex);
      prefs.setInt('${prefix}position_secs', _position.inSeconds);
      prefs.setString('${prefix}chapters', jsonEncode(_chapters));

      final lang = _currentLangCode ?? 'en';
      await AppLocator.auth.updateListeningProgress(
        bookId,
        lang,
        _currentChapterIndex,
        _position.inSeconds,
        accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds,
        localOnly: true,
        expectedUserId: ownerId,
      );
    } catch (e, stack) {
      debugPrint('Error saving audio state: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> clearState() async {
    final ownerId = _playbackOwnerId;
    final bookId = _currentBookId;
    final language = _currentLangCode;
    if (ownerId != null && ownerId == AppLocator.auth.currentUser?.id && bookId != null && language != null) {
      await AppLocator.auth.updateListeningProgress(bookId, language, _currentChapterIndex, _position.inSeconds,
          accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds, expectedUserId: ownerId);
    }
    _playbackGeneration++;
    _playbackOwnerId = null;
    await _player.stop();
    _currentBookId = null;
    _currentLangCode = null;
    _currentBookTitle = null;
    _currentCoverUrl = null;
    _globalAudioUrl = null;
    _bookDurationSecs = 0;
    _isCurrentBookPremium = false;
    _currentChapterIndex = 0;
    _position = Duration.zero;
    _chapters = [];
    await DownloadManager.cleanupTempPlaybackFiles();
    notifyListeners();
  }

  RealAudioService() {
    _playerSubscriptions.add(_player.playerStateStream.listen((state) {
      _isPlaying =
          state.playing && state.processingState != ProcessingState.completed;
      if (state.processingState == ProcessingState.completed && _playbackOwnerId != null &&
          _playbackOwnerId == AppLocator.auth.currentUser?.id) {
        _recordLearningTime();
        if (_currentChapterIndex < _chapters.length - 1) {
          if (_currentBookId != null) {
            StreakTracker.trackKeypointCompleted(_currentBookId!, _currentChapterIndex);
          }
          nextChapter();
        } else {
          // Reached end of the whole book
          if (_currentBookId != null) {
            StreakTracker.trackKeypointCompleted(_currentBookId!, _currentChapterIndex);
            // Require user to have listened to at least 80% of the second half of the book
            double requiredSeconds = (_bookDurationSecs / 2) * 0.8;
            if (_accumulatedSecondHalfSeconds >= requiredSeconds) {
              StreakTracker.trackBookCompleted(_currentBookId!);
              AppLocator.auth.addCompletedBook(_currentBookId!);
            }
          }
          stop();
        }

        // If guest finishes the allowed chapters on a premium book, trigger the popup
        if (_isCurrentBookPremium &&
            AppLocator.auth.isGuest &&
            _currentChapterIndex == 1 &&
            _chapters.length > 2) {
          _isGuestRestricted = true;
        }
      }
      notifyListeners();
    }));

    _playerSubscriptions.add(_player.positionStream.listen((pos) {
      _position = pos;

      if (DateTime.now().difference(_lastSaveTime).inSeconds > 5) {
        _saveState();
        _lastSaveTime = DateTime.now();
      }

      // Auto-stop if sleep timer reached
      if (_sleepTimerEndTime != null) {
        if (DateTime.now().isAfter(_sleepTimerEndTime!)) {
          pause();
          clearSleepTimer();
        } else {
          notifyListeners(); // Tick for UI updates
        }
      } else {
        notifyListeners();
      }
    }));

    _playerSubscriptions.add(_player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    }));

    _playerSubscriptions.add(_player.currentIndexStream.listen((index) {
      if (index != null && index != _currentChapterIndex) {
        _currentChapterIndex = index;
        _saveState();
        notifyListeners();
      }
    }));
  }

  @override
  bool get isPlaying => _isPlaying;
  @override
  double get speed => _speed;
  @override
  Duration get position => _position;
  @override
  Duration get duration => _duration;
  @override
  String? get currentBookId => _currentBookId;
  @override
  String? get currentLangCode => _currentLangCode;
  @override
  String? get currentBookTitle => _currentBookTitle;
  @override
  String? get currentCoverUrl => _currentCoverUrl;
  @override
  int get currentChapterIndex => _currentChapterIndex;
  @override
  List<Map<String, dynamic>> get chapters => _chapters;

  @override
  Duration? get sleepTimerRemaining {
    if (_sleepTimerEndTime == null) return null;
    final remaining = _sleepTimerEndTime!.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  @override
  bool get isCurrentBookPremium => _isCurrentBookPremium;

  @override
  bool get isGuestRestricted => _isGuestRestricted;

  @override
  void clearGuestRestriction() {
    _isGuestRestricted = false;
    notifyListeners();
  }

  @override
  void play(String bookId, String langCode, String bookTitle, String coverUrl,
      String globalAudioUrl, List<Map<String, dynamic>> bookChapters,
      {int startIndex = 0,
      int startPosition = 0,
      int bookDurationSecs = 0,
      bool isPremium = false}) async {
    _isCurrentBookPremium = isPremium;
    if (_isCurrentBookPremium && AppLocator.auth.isGuest && startIndex >= 2) {
      _isGuestRestricted = true;
      notifyListeners();
      return;
    }

    if (_currentBookId == bookId &&
        _currentLangCode == langCode &&
        _chapters.length == bookChapters.length) {
      // If same book and same chapters, just check if we need to change chapter
      if (startIndex != _currentChapterIndex) {
        _isPlaying = false;
        notifyListeners();
        await _player.pause();
        await _player.seek(Duration.zero, index: startIndex);
      }
      resume();
      return;
    }

    if (_playbackOwnerId != null && _playbackOwnerId == AppLocator.auth.currentUser?.id && _currentBookId != null && _currentLangCode != null) {
      // Save progress before switching
      AppLocator.auth.updateListeningProgress(_currentBookId!,
          _currentLangCode!, _currentChapterIndex, _position.inSeconds,
          accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds, expectedUserId: _playbackOwnerId);
    }

    stop();
    _playbackOwnerId = AppLocator.auth.currentUser?.id;
    final generation = _playbackGeneration;
    _currentBookId = bookId;
    _currentLangCode = langCode;
    _currentBookTitle = bookTitle;
    _currentCoverUrl = coverUrl;
    _chapters = bookChapters;
    _bookDurationSecs = bookDurationSecs;

    AppLocator.auth.updatePresence(
      screen: 'Listening Audiobook',
      bookTitle: bookTitle,
      bookId: bookId,
      activityType: 'listening',
    );
    _accumulatedSecondHalfSeconds = 0;

    int startChap = startIndex;
    Duration startPos = Duration(seconds: startPosition);

    // Load saved progress if the user didn't explicitly request a specific start position
    if (startIndex == 0 && startPosition == 0) {
      var progress =
          AppLocator.auth.currentUser?.listeningProgress['${bookId}_$langCode'];
      if (progress == null) {
        final prefix = '${bookId}_';
        final matchingKey = AppLocator.auth.currentUser?.listeningProgress.keys.firstWhere(
          (k) => k.startsWith(prefix),
          orElse: () => '',
        ) ?? '';
        if (matchingKey.isNotEmpty) {
          progress = AppLocator.auth.currentUser?.listeningProgress[matchingKey];
        }
      }
      if (progress != null) {
        startChap = progress['chapterIndex'] ?? 0;
        startPos = Duration(seconds: progress['positionSeconds'] ?? 0);
        _accumulatedSecondHalfSeconds =
            progress['accumulatedSecondHalfSeconds'] ?? 0;
      }
    }

    _currentChapterIndex = startChap;

    try {
      if (_chapters.isEmpty) {
        // Fallback for testing empty books
        await _player.setAsset('assets/audio/sample.wav');
      } else {
        // Slice playlist if guest on a premium book
        List<Map<String, dynamic>> playableChapters = _chapters;
        if (_isCurrentBookPremium && AppLocator.auth.isGuest && _chapters.length > 2) {
          playableChapters = _chapters.sublist(0, 2);
        }

        final List<AudioSource> playlistChildren = [];
        for (int idx = 0; idx < playableChapters.length; idx++) {
          final ch = playableChapters[idx];
          String? url = ch['audioUrl'] as String?;
          if (url == null || url.isEmpty) {
            url = globalAudioUrl;
          }

          final String chapterTitle = ch['title'] is Map
              ? (ch['title'][langCode] ?? _getFallbackChapterTitle(idx, langCode))
              : _getFallbackChapterTitle(idx, langCode);

          final mediaItem = MediaItem(
            id: '${bookId}_$idx',
            album: bookTitle,
            title: chapterTitle,
            artUri: coverUrl.isNotEmpty ? Uri.parse(coverUrl) : null,
          );

          final isLocal = DownloadService.isEditionDownloadedSync(bookId, langCode) &&
              DownloadService.getLocalAudioFileIfExists(bookId, langCode) != null;
          final hasNet = await NetworkGuard.hasConnection();

          if (isLocal && (!hasNet || url.isEmpty || url.startsWith('file://'))) {
            try {
              final source = await DownloadManager.loadAudioSource(
                bookId,
                langCode,
                mediaItem,
              );
              playlistChildren.add(source);
            } catch (e) {
              debugPrint('Failed to decrypt audio source: $e');
              rethrow;
            }
          } else if (url.startsWith('http')) {
            if (const bool.fromEnvironment('USE_FIREBASE_EMULATORS') &&
                !['10.0.2.2', '127.0.0.1', 'localhost'].contains(Uri.parse(url).host)) {
              throw StateError('External audio is disabled in isolated tests.');
            }
            playlistChildren.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
          } else if (isLocal) {
            final source = await DownloadManager.loadAudioSource(
              bookId,
              langCode,
              mediaItem,
            );
            playlistChildren.add(source);
          } else {
            playlistChildren.add(AudioSource.uri(
                Uri.parse('asset:///assets/audio/sample.wav'),
                tag: mediaItem));
          }
        }

        final playlist = ConcatenatingAudioSource(children: playlistChildren);

        if (_playbackGeneration != generation || _playbackOwnerId != AppLocator.auth.currentUser?.id) return;
        await _player.setAudioSource(playlist,
            initialIndex: startChap, initialPosition: startPos);
      }

      if (_playbackGeneration != generation || _playbackOwnerId != AppLocator.auth.currentUser?.id) return;
      await _player.setSpeed(_speed);
      if (_playbackGeneration != generation || _playbackOwnerId != AppLocator.auth.currentUser?.id) return;
      _player.play();
      _lastPlayTime = DateTime.now();
    } catch (e) {
      debugPrint("Error loading audio source: $e");
    }
    _saveState();
    notifyListeners();
  }

  void _recordLearningTime() {
    if (_lastPlayTime != null && _playbackOwnerId != null && _playbackOwnerId == AppLocator.auth.currentUser?.id) {
      final diff = DateTime.now().difference(_lastPlayTime!);
      AppLocator.auth.addLearningTime(diff.inSeconds);

      // Track seconds listened in the second half of the book
      if (_chapters.isNotEmpty &&
          _currentChapterIndex >= _chapters.length / 2) {
        _accumulatedSecondHalfSeconds += diff.inSeconds;
      }

      _lastPlayTime = null;
    }
    if (_playbackOwnerId != AppLocator.auth.currentUser?.id) _lastPlayTime = null;
  }

  @override
  void pause() {
    _player.pause();
    _recordLearningTime();
    if (_playbackOwnerId != null && _playbackOwnerId == AppLocator.auth.currentUser?.id && _currentBookId != null && _currentLangCode != null) {
      AppLocator.auth.updateListeningProgress(_currentBookId!,
          _currentLangCode!, _currentChapterIndex, _position.inSeconds,
          accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds, expectedUserId: _playbackOwnerId);
    }
  }

  @override
  void resume() {
    _player.play();
    _lastPlayTime = DateTime.now();
  }

  @override
  void stop() {
    _recordLearningTime();
    if (_playbackOwnerId != null && _playbackOwnerId == AppLocator.auth.currentUser?.id && _currentBookId != null && _currentLangCode != null) {
      AppLocator.auth.updateListeningProgress(_currentBookId!,
          _currentLangCode!, _currentChapterIndex, _position.inSeconds, expectedUserId: _playbackOwnerId);
    }
    _playbackGeneration++;
    _playbackOwnerId = null;
    _player.stop();
    _currentBookId = null;
    _currentLangCode = null;
    _currentBookTitle = null;
    _currentCoverUrl = null;
    _chapters = [];
    _currentChapterIndex = 0;
    DownloadManager.cleanupTempPlaybackFiles();
    notifyListeners();
  }

  @override
  void setSpeed(double speed) {
    _speed = speed;
    _player.setSpeed(speed);
    notifyListeners();
  }

  @override
  void seek(Duration position) {
    _player.seek(position);
  }

  @override
  void nextChapter() {
    int nextIndex = _currentChapterIndex + 1;
    if (_isCurrentBookPremium && AppLocator.auth.isGuest && nextIndex >= 2) {
      _isGuestRestricted = true;
      notifyListeners();
      return;
    }

    if (_player.hasNext) {
      _player.seekToNext();
    }
  }

  @override
  void previousChapter() {
    if (_player.hasPrevious) {
      _player.seekToPrevious();
    } else {
      _player.seek(Duration.zero);
    }
  }

  @override
  void setSleepTimer(Duration duration) {
    clearSleepTimer();
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      pause();
      clearSleepTimer();
    });
    notifyListeners();
  }

  @override
  void clearSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final subscription in _playerSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    super.dispose();
  }

  String _getFallbackChapterTitle(int idx, String? langCode) {
    final indexStr = '${idx + 1}';
    if (langCode == 'ku') {
      return 'خاڵی سەرەکی $indexStr';
    } else if (langCode == 'ar') {
      return 'النقطة الرئيسية $indexStr';
    } else {
      return 'Key Point $indexStr';
    }
  }
}
