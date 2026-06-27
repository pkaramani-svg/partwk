import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'service_locator.dart';
import 'streak_tracker.dart';
import 'download_manager.dart';
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

  bool get isGuestRestricted;
  void clearGuestRestriction();

  Future<void> init();
  Future<void> clearState();
  void play(String bookId, String langCode, String bookTitle, String coverUrl,
      String globalAudioUrl, List<Map<String, dynamic>> bookChapters,
      {int startIndex = 0, int startPosition = 0, int bookDurationSecs = 0});
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

  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  bool _isGuestRestricted = false;
  DateTime? _lastPlayTime;
  DateTime _lastSaveTime = DateTime.now();

  @override
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = AppLocator.auth.currentUser?.id ?? 'guest';
      final prefix = 'audio_${userId}_';
      
      _currentBookId = prefs.getString('${prefix}book_id');
      if (_currentBookId != null) {
        _currentLangCode = prefs.getString('${prefix}lang_code');
        _currentBookTitle = prefs.getString('${prefix}book_title');
        _currentCoverUrl = prefs.getString('${prefix}cover_url');
        _globalAudioUrl = prefs.getString('${prefix}global_url');
        _bookDurationSecs = prefs.getInt('${prefix}book_duration') ?? 0;
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

        final isLocal = DownloadService.isBookDownloadedSync(_currentBookId!) &&
            DownloadService.getLocalAudioFileSync(_currentBookId!, _currentLangCode ?? 'en').existsSync();

        if (isLocal || url.startsWith('file://')) {
          try {
            final source = await DownloadManager.loadAudioSource(
              _currentBookId!,
              _currentLangCode ?? 'en',
              mediaItem,
            );
            playlistChildren.add(source);
          } catch (e) {
            playlistChildren.add(AudioSource.uri(
              Uri.parse('asset:///assets/audio/sample.wav'),
              tag: mediaItem,
            ));
          }
        } else if (url.startsWith('http')) {
          playlistChildren.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
        } else {
          playlistChildren.add(AudioSource.uri(
              Uri.parse('asset:///assets/audio/sample.wav'),
              tag: mediaItem));
        }
      }

      final playlist = ConcatenatingAudioSource(children: playlistChildren);
      await _player.setAudioSource(playlist,
          initialIndex: _currentChapterIndex,
          initialPosition: Duration(seconds: savedPos));
    } catch (e) {}
  }

  Future<void> _saveState() async {
    if (_currentBookId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = AppLocator.auth.currentUser?.id ?? 'guest';
      final prefix = 'audio_${userId}_';
      
      prefs.setString('${prefix}book_id', _currentBookId!);
      prefs.setString('${prefix}lang_code', _currentLangCode ?? 'en');
      prefs.setString('${prefix}book_title', _currentBookTitle ?? '');
      prefs.setString('${prefix}cover_url', _currentCoverUrl ?? '');
      prefs.setString('${prefix}global_url', _globalAudioUrl ?? '');
      prefs.setInt('${prefix}book_duration', _bookDurationSecs);
      prefs.setInt('${prefix}chapter_index', _currentChapterIndex);
      prefs.setInt('${prefix}position_secs', _position.inSeconds);
      prefs.setString('${prefix}chapters', jsonEncode(_chapters));

      final lang = _currentLangCode ?? 'en';
      await AppLocator.auth.updateListeningProgress(
        _currentBookId!,
        lang,
        _currentChapterIndex,
        _position.inSeconds,
        accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds,
        localOnly: true,
      );
    } catch (e) {}
  }

  Future<void> clearState() async {
    await _player.stop();
    _currentBookId = null;
    _currentLangCode = null;
    _currentBookTitle = null;
    _currentCoverUrl = null;
    _globalAudioUrl = null;
    _bookDurationSecs = 0;
    _currentChapterIndex = 0;
    _position = Duration.zero;
    _chapters = [];
    await DownloadManager.cleanupTempPlaybackFiles();
    notifyListeners();
  }

  RealAudioService() {
    _player.playerStateStream.listen((state) {
      _isPlaying =
          state.playing && state.processingState != ProcessingState.completed;
      if (state.processingState == ProcessingState.completed) {
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

        // If guest finishes the allowed chapters, trigger the popup
        if (AppLocator.auth.isGuest &&
            _currentChapterIndex == 1 &&
            _chapters.length > 2) {
          _isGuestRestricted = true;
        }
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
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
    });

    _player.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index != _currentChapterIndex) {
        _currentChapterIndex = index;
        _saveState();
        notifyListeners();
      }
    });
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
      int bookDurationSecs = 0}) async {
    if (AppLocator.auth.isGuest && startIndex >= 2) {
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

    if (_currentBookId != null && _currentLangCode != null) {
      // Save progress before switching
      AppLocator.auth.updateListeningProgress(_currentBookId!,
          _currentLangCode!, _currentChapterIndex, _position.inSeconds,
          accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds);
    }

    stop();
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
        // Slice playlist if guest
        List<Map<String, dynamic>> playableChapters = _chapters;
        if (AppLocator.auth.isGuest && _chapters.length > 2) {
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

          final isLocal = DownloadService.isBookDownloadedSync(bookId) &&
              DownloadService.getLocalAudioFileSync(bookId, langCode).existsSync();

          if (isLocal || url.startsWith('file://')) {
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
            playlistChildren.add(AudioSource.uri(Uri.parse(url), tag: mediaItem));
          } else {
            playlistChildren.add(AudioSource.uri(
                Uri.parse('asset:///assets/audio/sample.wav'),
                tag: mediaItem));
          }
        }

        final playlist = ConcatenatingAudioSource(children: playlistChildren);

        await _player.setAudioSource(playlist,
            initialIndex: startChap, initialPosition: startPos);
      }

      await _player.setSpeed(_speed);
      _player.play();
      _lastPlayTime = DateTime.now();
    } catch (e) {
      debugPrint("Error loading audio source: $e");
    }
    _saveState();
    notifyListeners();
  }

  void _recordLearningTime() {
    if (_lastPlayTime != null) {
      final diff = DateTime.now().difference(_lastPlayTime!);
      AppLocator.auth.addLearningTime(diff.inSeconds);

      // Track seconds listened in the second half of the book
      if (_chapters.isNotEmpty &&
          _currentChapterIndex >= _chapters.length / 2) {
        _accumulatedSecondHalfSeconds += diff.inSeconds;
      }

      _lastPlayTime = null;
    }
  }

  @override
  void pause() {
    _player.pause();
    _recordLearningTime();
    if (_currentBookId != null && _currentLangCode != null) {
      AppLocator.auth.updateListeningProgress(_currentBookId!,
          _currentLangCode!, _currentChapterIndex, _position.inSeconds,
          accumulatedSecondHalfSeconds: _accumulatedSecondHalfSeconds);
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
    if (_currentBookId != null && _currentLangCode != null) {
      AppLocator.auth.updateListeningProgress(_currentBookId!,
          _currentLangCode!, _currentChapterIndex, _position.inSeconds);
    }
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
    if (AppLocator.auth.isGuest && nextIndex >= 2) {
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
    _player.dispose();
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
