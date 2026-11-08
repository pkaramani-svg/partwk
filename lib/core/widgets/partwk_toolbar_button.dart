import 'package:flutter/material.dart';

/// A modern, tactile rounded toolbar button designed for Partwk's Player & Reader.
/// Features subtle glassmorphic/tonal borders, responsive hover/tap states,
/// accessible tooltips and semantic labels, and clean dark/light mode adaptability.
class PartwkToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;
  final bool? isDark;
  final Color? activeColor;
  final Widget? badge;
  final double size;
  final double iconSize;

  const PartwkToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.isDark,
    this.activeColor,
    this.badge,
    this.size = 40.0,
    this.iconSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tealColor = activeColor ?? theme.colorScheme.secondary;
    final effectiveIsDark = isDark ?? (theme.brightness == Brightness.dark);
    const navyColor = Color(0xFF0F172A);

    // Harmonious background, border, and foreground colors
    final Color bgColor = isActive
        ? tealColor.withOpacity(0.18)
        : (effectiveIsDark ? Colors.white.withOpacity(0.08) : navyColor.withOpacity(0.07));

    final Color borderColor = isActive
        ? tealColor.withOpacity(0.45)
        : (effectiveIsDark ? Colors.white.withOpacity(0.14) : navyColor.withOpacity(0.14));

    final Color iconColor = isActive
        ? tealColor
        : (effectiveIsDark ? Colors.white : navyColor);

    Widget button = Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            splashColor: tealColor.withOpacity(0.2),
            highlightColor: tealColor.withOpacity(0.1),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (badge != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -2,
            right: -2,
            child: badge!,
          ),
        ],
      );
    }

    return button;
  }
}
