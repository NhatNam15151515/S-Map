import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

class MapCircleIconButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;
  final Color? backgroundColor;
  final bool hasShadow;
  final String? tooltip;
  final BoxBorder? border;

  const MapCircleIconButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 44,
    this.backgroundColor,
    this.hasShadow = true,
    this.tooltip,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveBg = backgroundColor ?? colorScheme.surface;

    Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBg,
        shape: BoxShape.circle,
        border: border,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
