import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/book.dart';
import '../../services/download_service.dart';
import '../../core/services/network_guard.dart';
import '../book/book_details_screen.dart';

/// A gentle, premium automatic scrolling carousel applied exclusively to the
/// New Releases section on the Home screen.
class NewReleasesCarousel extends StatefulWidget {
  final List<Book> books;
  final String langCode;
  final ThemeData theme;

  const NewReleasesCarousel({
    super.key,
    required this.books,
    required this.langCode,
    required this.theme,
  });

  @override
  State<NewReleasesCarousel> createState() => NewReleasesCarouselState();
}

class NewReleasesCarouselState extends State<NewReleasesCarousel>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;

  Timer? _idleTimer;
  Timer? _pauseTimer;

  bool _isForward = true; // true: toward maxScrollExtent, false: toward 0.0
  bool _isAutoScrolling = false;
  bool _isUserInteracting = false;
  bool _isExternalScrolling = false;

  // Visible for testing
  ScrollController get scrollController => _scrollController;
  bool get isAutoScrolling => _isAutoScrolling;
  bool get isForward => _isForward;
  bool get isUserInteracting => _isUserInteracting;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleInitialStart();
      }
    });
  }

  @override
  void didUpdateWidget(covariant NewReleasesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books && widget.books.length < 2) {
      _pauseAutoScroll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pauseAutoScroll();
    } else {
      _scheduleResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimers();
    _isAutoScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _pauseTimer?.cancel();
    _pauseTimer = null;
  }

  bool _isReducedMotionEnabled() {
    if (!mounted) return true;
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) return false;
    return mediaQuery.disableAnimations || mediaQuery.accessibleNavigation;
  }

  bool _isRouteActive() {
    if (!mounted) return false;
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  void _scheduleInitialStart() {
    _cancelTimers();
    if (!mounted || _isReducedMotionEnabled() || !_isRouteActive()) return;

    // After Home has been visible and idle for 3 seconds
    _idleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _startScrollJourney();
      }
    });
  }

  /// Called after user interaction ceases; waits 4-5 seconds then resumes
  /// from the current scroll position without resetting to the beginning.
  void _scheduleResume() {
    _cancelTimers();
    if (!mounted || _isReducedMotionEnabled() || !_isRouteActive()) return;
    if (_isUserInteracting || _isExternalScrolling) return;

    _idleTimer = Timer(const Duration(milliseconds: 4500), () {
      if (mounted) {
        _startScrollJourney();
      }
    });
  }

  /// Pauses any active auto-scroll animation and cancels pending timers.
  void pauseAutoScroll() {
    _pauseAutoScroll();
  }

  /// Resumes auto-scroll after inactivity delay.
  void resumeAutoScrollAfterDelay() {
    _scheduleResume();
  }

  /// Called when the parent vertical Home scroll begins.
  void handleExternalScrollStart() {
    _isExternalScrolling = true;
    _pauseAutoScroll();
  }

  /// Called when the parent vertical Home scroll ends.
  void handleExternalScrollEnd() {
    _isExternalScrolling = false;
    _scheduleResume();
  }

  void _pauseAutoScroll() {
    _cancelTimers();
    if (_isAutoScrolling && _scrollController.hasClients) {
      _isAutoScrolling = false;
      try {
        final current = _scrollController.offset;
        _scrollController.jumpTo(current);
      } catch (_) {}
    }
  }

  void _startScrollJourney() {
    if (!mounted) return;
    if (_isReducedMotionEnabled() || !_isRouteActive()) return;
    if (_isUserInteracting || _isExternalScrolling) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;

    // If there are too few covers to scroll, do nothing cleanly.
    if (maxExtent <= 20.0) return;

    final currentOffset = _scrollController.offset;
    final targetOffset = _isForward ? maxExtent : 0.0;
    final distance = (targetOffset - currentOffset).abs();

    // If already at or very close to the destination edge, pause for 2 seconds
    // and reverse direction.
    if (distance < 2.0) {
      _isForward = !_isForward;
      _pauseTimer?.cancel();
      _pauseTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _startScrollJourney();
        }
      });
      return;
    }

    // Target roughly 18-25 seconds for a full journey from one end to the other,
    // adjusted naturally to the real scrollable distance.
    const fullJourneyTargetSeconds = 21.5;
    final speed = (maxExtent / fullJourneyTargetSeconds).clamp(20.0, 55.0);

    final durationSeconds = distance / speed;
    final duration = Duration(milliseconds: (durationSeconds * 1000).round());

    _isAutoScrolling = true;

    _scrollController
        .animateTo(
      targetOffset,
      duration: duration,
      curve: Curves.linear,
    )
        .then((_) {
      if (!mounted) return;
      _isAutoScrolling = false;

      if (_isUserInteracting || _isExternalScrolling || !_isRouteActive()) {
        return;
      }

      // Check if we reached the target edge
      final finalOffset = _scrollController.offset;
      final reachedEnd = (_isForward && finalOffset >= maxExtent - 2.0) ||
          (!_isForward && finalOffset <= 2.0);

      if (reachedEnd) {
        // Pause for 2 seconds at the beginning and end
        _isForward = !_isForward;
        _pauseTimer?.cancel();
        _pauseTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _startScrollJourney();
          }
        });
      }
    }).catchError((_) {
      _isAutoScrolling = false;
    });
  }

  void _onPointerDown() {
    _isUserInteracting = true;
    _pauseAutoScroll();
  }

  void _onPointerUp() {
    _isUserInteracting = false;
    _scheduleResume();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 240,
      child: Listener(
        onPointerDown: (_) => _onPointerDown(),
        onPointerUp: (_) => _onPointerUp(),
        onPointerCancel: (_) => _onPointerUp(),
        behavior: HitTestBehavior.translucent,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification &&
                notification.dragDetails != null) {
              _isUserInteracting = true;
              _pauseAutoScroll();
            } else if (notification is ScrollEndNotification) {
              _isUserInteracting = false;
              _scheduleResume();
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.books.length,
            itemBuilder: (context, index) {
              final book = widget.books[index];
              return GestureDetector(
                onTap: () {
                  _pauseAutoScroll();
                  NetworkGuard.guardBookNavigation(context, book.id, () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BookDetailsScreen(bookId: book.id),
                      ),
                    );
                    if (mounted) {
                      _scheduleResume();
                    }
                  });
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsetsDirectional.only(end: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: DownloadService.getBookCoverWidget(
                            book,
                            langCode: widget.langCode,
                            height: 175,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.getTitle(widget.langCode),
                        style: widget.theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.getAuthor(widget.langCode),
                        style: widget.theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
