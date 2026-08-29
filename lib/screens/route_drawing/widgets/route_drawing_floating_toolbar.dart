import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RouteDrawingFloatingToolbar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final bool hasPoints;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onFitBounds;

  const RouteDrawingFloatingToolbar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.hasPoints,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onFitBounds,
  });

  void _showClearConfirmDialog(BuildContext context) {
    final colorScheme = context.colorScheme;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.route_drawing_ui_clear_confirm_title),
          style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
            fontSize: 16,
          ),
        ),
        content: Text(
          tr(LocaleKeys.route_drawing_ui_clear_confirm_desc),
          style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('route_drawing_clear_cancel_btn'),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              tr(LocaleKeys.cancel),
              style: colorScheme.onSurfaceVariant.textTheme.mediumStyle,
            ),
          ),
          ElevatedButton(
            key: const Key('route_drawing_clear_confirm_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              onClear();
            },
            child: Text(
              tr(LocaleKeys.route_drawing_ui_clear_all),
              style: colorScheme.onError.textTheme.boldStyle,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Positioned(
      right: 16,
      top: 130,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarButton(
              context: context,
              key: const Key('route_drawing_undo_button'),
              icon: HeroIcons.arrowUturnLeft,
              tooltip: tr(LocaleKeys.route_drawing_ui_undo),
              isEnabled: canUndo,
              onPressed: onUndo,
            ),
            const SizedBox(height: 6),
            _buildToolbarButton(
              context: context,
              key: const Key('route_drawing_redo_button'),
              icon: HeroIcons.arrowUturnRight,
              tooltip: tr(LocaleKeys.route_drawing_ui_redo),
              isEnabled: canRedo,
              onPressed: onRedo,
            ),
            const SizedBox(height: 6),
            _buildToolbarButton(
              context: context,
              key: const Key('route_drawing_fit_bounds_button'),
              icon: HeroIcons.viewfinderCircle,
              tooltip: tr(LocaleKeys.route_drawing_ui_fit_bounds),
              isEnabled: hasPoints,
              onPressed: onFitBounds,
            ),
            const SizedBox(height: 6),
            Divider(
              height: 1,
              indent: 8,
              endIndent: 8,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 6),
            _buildToolbarButton(
              context: context,
              key: const Key('route_drawing_clear_button'),
              icon: HeroIcons.trash,
              tooltip: tr(LocaleKeys.route_drawing_ui_clear_all),
              isEnabled: canClear,
              isDestructive: true,
              onPressed: () => _showClearConfirmDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required BuildContext context,
    required Key key,
    required HeroIcons icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    final colorScheme = context.colorScheme;
    Color iconColor;
    if (!isEnabled) {
      iconColor = colorScheme.outline.withValues(alpha: 0.4);
    } else if (isDestructive) {
      iconColor = colorScheme.error;
    } else {
      iconColor = colorScheme.onSurface;
    }

    return IconButton(
      key: key,
      icon: HeroIcon(icon, size: 20, color: iconColor),
      tooltip: tooltip,
      onPressed: isEnabled ? onPressed : null,
    );
  }
}
