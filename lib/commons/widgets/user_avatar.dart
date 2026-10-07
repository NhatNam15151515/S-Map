import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

class ProfileAvatar extends StatelessWidget {
  final double? size;
  final double borderWidth;
  final String? avatarBase64;
  final String? avatarUrl;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.size,
    this.borderWidth = 1.5,
    this.avatarBase64,
    this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final effectiveSize = size ?? 36.0;

    Uint8List? imageBytes;
    if (avatarBase64 != null && avatarBase64!.trim().isNotEmpty) {
      try {
        imageBytes = AvatarUtils.decodeBase64(avatarBase64!);
      } catch (_) {
        imageBytes = null;
      }
    }

    final avatarWidget = Container(
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
      child: ClipOval(
        child: SizedBox(
          width: effectiveSize,
          height: effectiveSize,
          child: imageBytes != null
              ? Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.person_rounded,
                    size: effectiveSize * 0.6,
                    color: colorScheme.primary,
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: effectiveSize * 0.6,
                  color: colorScheme.primary,
                ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }
    return avatarWidget;
  }
}

