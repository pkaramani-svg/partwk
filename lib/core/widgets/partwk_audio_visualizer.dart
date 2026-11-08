import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A subtle, high-performance playback visualizer for Partwk.
///
/// Note on Audio Amplitude / Metering:
/// The Partwk audio pipeline uses `just_audio: ^0.9.36` backed by native ExoPlayer (Android)
/// and AVPlayer (iOS), streaming and playing encrypted or cached MP3/AAC audio files.
/// `just_audio` does not expose raw PCM byte streams or real-time amplitude metering.
/// Precomputing waveform envelopes across the remote library would require modifying
/// storage/Firestore schemas without authorization.
/// Therefore, per specifications, this widget operates as a subtle, lightweight
/// playback-state visualizer:
/// - Smoothly animates rhythmic voice-like micro-bars during active playback (`isPlaying = true`).
/// - Immediately settles into a resting state and stops animation ticker when paused or buffering (`isPlaying = false`), consuming zero CPU and preserving battery.
/// - Excludes itself from accessibility trees so screen-reader controls remain pristine.
class PartwkAudioVisualizer extends StatefulWidget {
  final bool isPlaying;
  final Color? color;
  final int barCount;
  final double maxHeight;
  final double barWidth;

  const PartwkAudioVisualizer({
    super.key,
    required this.isPlaying,
    this.color,
    this.barCount = 4,
    this.maxHeight = 12.0,
    this.barWidth = 2.5,
  });

  @override
  State<PartwkAudioVisualizer> createState() => _PartwkAudioVisualizerState();
}

class _PartwkAudioVisualizerState extends State<PartwkAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PartwkAudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      } else {
        _controller.animateTo(0.0, duration: const Duration(milliseconds: 250));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.color ?? theme.colorScheme.secondary;

    // Phase offsets and scale factors for natural voice-like micro-motion
    const phases = [0.0, 1.4, 2.8, 4.2];
    const amplitudes = [0.65, 1.0, 0.75, 0.9];
    const minHeight = 2.5;

    return Semantics(
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final isAnimating = _controller.isAnimating;

          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (index) {
              final phase = phases[index % phases.length];
              final amp = amplitudes[index % amplitudes.length];

              double height;
              if (isAnimating) {
                // Sinusoidal rhythm simulating speech vocal energy
                final wave = (math.sin(progress * 2 * math.pi + phase) + 1.0) / 2.0;
                height = minHeight + (widget.maxHeight - minHeight) * amp * wave;
              } else {
                height = minHeight;
              }

              return Container(
                margin: EdgeInsets.only(right: index < widget.barCount - 1 ? 2.5 : 0),
                width: widget.barWidth,
                height: height,
                decoration: BoxDecoration(
                  color: isAnimating ? activeColor : activeColor.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
