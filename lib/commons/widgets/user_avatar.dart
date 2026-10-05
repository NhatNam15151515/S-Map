import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

class ProfileAvatar extends StatelessWidget {
  final double? size;
  final double borderWidth;
  const ProfileAvatar({super.key, this.size, this.borderWidth = 1.5});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveSize = size ?? 36.0;
    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary,
          width: borderWidth,
        ),
        color: colorScheme.primary.withAlpha(25),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: effectiveSize * 0.6,
        color: colorScheme.primary,
      ),
    );
  }
}
