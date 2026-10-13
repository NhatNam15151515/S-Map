import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Nút đưa bản đồ về vị trí hiện tại của người dùng.
///
/// Widget này được dùng chung giữa Home và các màn hình bản đồ khác để
/// giữ nguyên biểu tượng, màu sắc, tooltip và phản hồi haptic.
class MapLocateButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Object? heroTag;

  const MapLocateButton({
    super.key,
    required this.onPressed,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton(
      heroTag: heroTag ?? 'map_locate_me_fab',
      tooltip: tr(LocaleKeys.map_current_location),
      onPressed: () {
        HapticFeedback.mediumImpact();
        onPressed();
      },
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.primary,
      elevation: 3,
      shape: const CircleBorder(),
      child: const Icon(Icons.my_location_rounded, size: 24),
    );
  }
}
