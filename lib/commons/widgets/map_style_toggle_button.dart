import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:s_map/commons/widgets/map_circle_icon_button.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Reusable map appearance toggle used by every screen that displays a map.
class MapStyleToggleButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const MapStyleToggleButton({
    super.key,
    required this.onPressed,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MapCircleIconButton(
      size: size,
      tooltip: tr(LocaleKeys.map_switch_layers),
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Icon(Icons.layers_rounded, color: colorScheme.onSurface, size: 20),
    );
  }
}
