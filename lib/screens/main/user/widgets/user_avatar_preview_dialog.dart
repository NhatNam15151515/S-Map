import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:s_map/commons/utils/utils.dart';

/// User feature action for presenting an avatar at full size.
class UserAvatarPreviewDialog {
  static void show(BuildContext context, String base64String) {
    Uint8List? imageBytes;
    try {
      imageBytes = AvatarUtils.decodeBase64(base64String);
    } catch (_) {}
    if (imageBytes == null) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2.5,
                ),
              ),
              child: ClipOval(
                child: Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
