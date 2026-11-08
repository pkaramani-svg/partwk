import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/service_locator.dart';
import 'language_selection_screen.dart';
import '../home/main_navigation.dart';

/// Zentori Studios' shared studio ident splash screen.
/// Operates without startup audio and without artificial delays.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _authCheckCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _startAppInitialization();
  }

  void _startAppInitialization() async {
    final authService = AppLocator.auth;
    // Perform necessary async initialization in parallel with the ident animation
    await Future.wait([
      authService.initialize(),
      _controller.forward().then((_) => null),
    ]).timeout(const Duration(seconds: 2), onTimeout: () {
      debugPrint('Splash animation timeout reached; transitioning to app.');
      return [];
    });

    _authCheckCompleted = true;
    if (!mounted) return;

    // Transition smoothly into the app
    _navigateNext();
  }

  void _navigateNext() {
    if (!mounted) return;
    final authService = AppLocator.auth;
    final targetWidget = authService.isAuthenticated
        ? const MainNavigation()
        : const LanguageSelectionScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetWidget,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final zentori = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.05, 0.40, curve: Curves.easeOutCubic),
          );
          final studios = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.20, 0.55, curve: Curves.easeOutCubic),
          );
          final wave = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.25, 0.85, curve: Curves.easeInOutCubic),
          );
          final lines = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.20, 0.60, curve: Curves.easeOutCubic),
          );
          final kurdish = CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
          );

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF071426), Color(0xFF0B1D35)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: zentori.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - zentori.value) * 10),
                      child: _ZentoriWord(wave: wave.value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: studios.value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - studios.value) * 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StudioLine(width: 32 * lines.value),
                          const SizedBox(width: 14),
                          const Text(
                            'STUDIOS',
                            style: TextStyle(
                              color: Color(0xFF58B9F5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 6.5,
                            ),
                          ),
                          const SizedBox(width: 14),
                          _StudioLine(width: 32 * lines.value),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: kurdish.value,
                    child: const Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'زێنتۆری ستودیۆ',
                        style: TextStyle(
                          color: Color(0xFFFFE3A3),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudioLine extends StatelessWidget {
  const _StudioLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 1.2,
        color: const Color(0xFF58B9F5).withOpacity(0.75),
      );
}

class _ZentoriWord extends StatelessWidget {
  const _ZentoriWord({required this.wave});
  final double wave;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFFF5F7FA),
      fontSize: 44,
      fontWeight: FontWeight.w600,
      letterSpacing: 8,
      height: 1,
    );
    return Stack(
      children: [
        const Text('ZENTORI', style: style),
        if (wave > 0 && wave < 1)
          ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final stop = -0.3 + wave * 1.6;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [
                  (stop - 0.28).clamp(0.0, 1.0),
                  (stop - 0.12).clamp(0.0, 1.0),
                  stop.clamp(0.0, 1.0),
                  (stop + 0.12).clamp(0.0, 1.0),
                  (stop + 0.28).clamp(0.0, 1.0),
                ],
                colors: [
                  Colors.transparent,
                  const Color(0xFF38BDF8).withOpacity(0.6),
                  const Color(0xFFE0F2FE),
                  const Color(0xFF38BDF8).withOpacity(0.6),
                  Colors.transparent,
                ],
              ).createShader(bounds);
            },
            child: const Text('ZENTORI', style: style),
          ),
      ],
    );
  }
}
