import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
import '../services/service_locator.dart';
import '../../features/audio/audio_player_screen.dart';
import '../../models/book.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/download_service.dart';

class MiniAudioBar extends StatelessWidget {
  const MiniAudioBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider<AudioService>.value(
      value: AppLocator.audio,
      child: Consumer<AudioService>(
        builder: (context, audioService, child) {
          final localizations = AppLocalizations.of(context)!;
          final currentAppLangCode = localizations.locale.languageCode;

          String? displayBookId = audioService.currentBookId;
          
          // If the audio service is holding a book from another language, ignore it and stop it
          if (displayBookId != null && audioService.currentLangCode != currentAppLangCode) {
            if (audioService.isPlaying) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                AppLocator.audio.stop();
              });
            }
            displayBookId = null;
          }

          String? displayTitle = audioService.currentBookTitle;
          String? displayCoverUrl = audioService.currentCoverUrl;
          String? displayGlobalAudioUrl;
          double progressVal = 0.0;
          List<Map<String, dynamic>>? chaptersToPlay;
          int currentChapter = 0;
          int positionSecs = 0;
          int totalSecs = 0;

          String? displayLangCode;
          if (displayBookId != null) {
            progressVal = audioService.duration.inSeconds > 0
                ? audioService.position.inSeconds / audioService.duration.inSeconds
                : 0.0;
            chaptersToPlay = audioService.chapters;
            currentChapter = audioService.currentChapterIndex;
            positionSecs = audioService.position.inSeconds;
            totalSecs = audioService.duration.inSeconds;
            displayLangCode = audioService.currentLangCode ?? 'en';
            try {
              final book = AppLocator.db.books.firstWhere((b) => b.id == displayBookId);
              displayGlobalAudioUrl = book.getAudioUrl(displayLangCode!);
            } catch (_) {
              displayGlobalAudioUrl = '';
            }
          } else {
            // Check for last played book in progress
            final user = AppLocator.auth.currentUser;
            if (user != null && user.listeningProgress.isNotEmpty) {
              for (final entry in user.listeningProgress.entries) {
                final parts = entry.key.split('_');
                final actualBookId = parts.first;
                final langCode = parts.length > 1 ? parts[1] : 'en';

                if (langCode == currentAppLangCode && !user.completedBooks.contains(actualBookId)) {
                  try {
                    final book = AppLocator.db.books.firstWhere((b) => b.id == actualBookId);
                    displayBookId = book.id;
                    displayLangCode = langCode;
                    displayTitle = book.getTitle(langCode); 
                    displayCoverUrl = book.coverImageUrl;
                    displayGlobalAudioUrl = book.getAudioUrl(langCode);
                    chaptersToPlay = book.getChapterSummaries(langCode);
                    currentChapter = entry.value['chapterIndex'] ?? 0;
                    positionSecs = entry.value['positionSeconds'] ?? 0;
                    totalSecs = book.getDurationForLanguage(langCode); // Approximate
                    progressVal = totalSecs > 0 ? positionSecs / totalSecs : 0.0;
                    break;
                  } catch (e) {
                    // Book not found in local db list, ignore
                  }
                }
              }
            }
          }

          if (displayBookId == null) {
            return const SizedBox.shrink();
          }

          final bookId = displayBookId;
          final title = displayTitle ?? '';
          final coverUrl = displayCoverUrl ?? '';
          final globalAudioUrl = displayGlobalAudioUrl ?? '';

          return Material(
            elevation: 12,
            color: theme.colorScheme.surface,
            child: InkWell(
              onTap: () {
                if (chaptersToPlay != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AudioPlayerScreen(
                        bookId: bookId,
                        langCode: displayLangCode ?? 'en',
                        bookTitle: title,
                        coverUrl: coverUrl,
                        globalAudioUrl: globalAudioUrl,
                        chapters: chaptersToPlay!,
                        initialChapterIndex: currentChapter,
                        initialPositionSecs: positionSecs,
                        bookDurationSecs: totalSecs,
                      ),
                    ),
                  );
                }
              },
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          if (coverUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: DownloadService.isBookDownloadedSync(bookId)
                                  ? Image.file(
                                      DownloadService.getLocalCoverFileSync(bookId),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      coverUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.music_note, color: Colors.white, size: 20),
                                        );
                                      },
                                    ),
                            )
                        else
                          Icon(
                            Icons.music_note,
                            color: theme.colorScheme.secondary,
                            size: 40,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                                Text(
                                  '${_formatDuration(Duration(seconds: positionSecs))} / ${_formatDuration(Duration(seconds: totalSecs))}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Play / Pause Button
                        IconButton(
                          icon: Icon(
                            audioService.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            size: 32,
                            color: theme.colorScheme.secondary,
                          ),
                          onPressed: () {
                            bool isSameBookAndLang = audioService.currentBookId == bookId && audioService.currentLangCode == displayLangCode;

                            if (audioService.isPlaying && isSameBookAndLang) {
                              audioService.pause();
                            } else {
                              if (isSameBookAndLang) {
                                audioService.resume();
                              } else if (chaptersToPlay != null && displayLangCode != null) {
                                audioService.play(
                                  bookId, 
                                  displayLangCode!, 
                                  title, 
                                  coverUrl, 
                                  globalAudioUrl, 
                                  chaptersToPlay!, 
                                  startIndex: currentChapter, 
                                  startPosition: positionSecs,
                                  bookDurationSecs: totalSecs,
                                );
                              }
                            }
                          },
                        ),

                      ],
                    ),
                  ),
                  // Linear progress bar moved to the bottom
                  LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 2,
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                  ),
                ],
              ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
