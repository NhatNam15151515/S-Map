import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';

class MapCompassButton extends StatelessWidget {
  final double rotation;
  final MapOrientationMode orientationMode;
  final VoidCallback onTap;

  const MapCompassButton({
    super.key,
    required this.rotation,
    required this.orientationMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isHeadingUp = orientationMode == MapOrientationMode.headingUp;
    final colorScheme = context.colorScheme;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        shape: BoxShape.circle,
        border: isHeadingUp
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Transform.rotate(
              angle: -(rotation * math.pi / 180),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.navigation_rounded,
                    size: 22,
                    color: isHeadingUp
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
