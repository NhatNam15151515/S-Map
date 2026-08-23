import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
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
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          tr(LocaleKeys.route_drawing_ui_clear_confirm_title),
          style: AppStyle.of(context).blackTextColor.textTheme.boldStyle.copyWith(
                fontSize: 16,
              ),
        ),
        content: Text(
          tr(LocaleKeys.route_drawing_ui_clear_confirm_desc),
          style: AppStyle.of(context).blackTextColor.textTheme.textStyle.copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              tr(LocaleKeys.cancel),
              style: const TextStyle(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
            key: const Key('route_drawing_clear_confirm_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.heroicRed,
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
              style: const TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 130,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarButton(
              key: const Key('route_drawing_undo_button'),
              icon: HeroIcons.arrowUturnLeft,
              tooltip: tr(LocaleKeys.route_drawing_ui_undo),
              isEnabled: canUndo,
              onPressed: onUndo,
            ),
            const SizedBox(height: 6),
            _buildToolbarButton(
              key: const Key('route_drawing_redo_button'),
              icon: HeroIcons.arrowUturnRight,
              tooltip: tr(LocaleKeys.route_drawing_ui_redo),
              isEnabled: canRedo,
              onPressed: onRedo,
            ),
            const SizedBox(height: 6),
            _buildToolbarButton(
              key: const Key('route_drawing_fit_bounds_button'),
              icon: HeroIcons.viewfinderCircle,
              tooltip: tr(LocaleKeys.route_drawing_ui_fit_bounds),
              isEnabled: hasPoints,
              onPressed: onFitBounds,
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, indent: 8, endIndent: 8),
            const SizedBox(height: 6),
            _buildToolbarButton(
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
    required Key key,
    required HeroIcons icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    Color iconColor;
    if (!isEnabled) {
      iconColor = AppColors.roughStone;
    } else if (isDestructive) {
      iconColor = AppColors.heroicRed;
    } else {
      iconColor = AppColors.grimReaper;
    }

    return IconButton(
      key: key,
      icon: HeroIcon(icon, size: 20, color: iconColor),
      tooltip: tooltip,
      onPressed: isEnabled ? onPressed : null,
    );
  }
}
