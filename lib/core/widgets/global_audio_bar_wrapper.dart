import 'package:flutter/material.dart';
import 'audio_bar.dart';

class GlobalAudioBarWrapper extends StatelessWidget {
  final Widget child;

  const GlobalAudioBarWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        const MiniAudioBar(),
      ],
    );
  }
}
