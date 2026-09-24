import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Floating Toolbar chứa các công cụ bản đồ khi vẽ route:
/// - Nằm ở góc dưới bên phải màn hình (trên Bottom Card).
/// - Đã bỏ các nút chọn điểm và nút toggle toàn bộ đường chim bay (vì đã có trên Menu từng đoạn).
class RouteDrawingFloatingToolbar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final bool hasPoints;
  final VoidCallback? onLocateMe;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback? onReverseRoute;
  final bool canReverse;
  final VoidCallback? onToggleCrosshair;
  final bool isCrosshairActive;
  final double? maxHeight;

  const RouteDrawingFloatingToolbar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.hasPoints,
    this.onLocateMe,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    this.onReverseRoute,
    this.canReverse = false,
    this.onToggleCrosshair,
    this.isCrosshairActive = true,
    this.maxHeight,
  });

  void _showClearConfirmDialog(BuildContext context) {
    AppConfirmDialog.show(
      context,
      title: tr(LocaleKeys.route_drawing_ui_clear_confirm_title),
      message: tr(LocaleKeys.route_drawing_ui_clear_confirm_desc),
      confirmText: tr(LocaleKeys.route_drawing_ui_clear_all),
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
      confirmKey: const Key('route_drawing_clear_confirm_btn'),
      cancelKey: const Key('route_drawing_clear_cancel_btn'),
      onConfirm: onClear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final effectiveMaxHeight =
        maxHeight ?? (screenHeight - 160).clamp(240.0, screenHeight);

    return Positioned(
      right: 14,
      bottom: 155,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: effectiveMaxHeight),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onLocateMe != null) ...[
                  MapLocateButton(
                    key: const Key('route_drawing_locate_me_button'),
                    heroTag: 'route_drawing_locate_me_fab',
                    onPressed: onLocateMe!,
                  ),
                  const SizedBox(height: 6),
                ],
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
                if (onReverseRoute != null) ...[
                  const SizedBox(height: 6),
                  _buildToolbarButton(
                    context: context,
                    key: const Key('route_drawing_reverse_button'),
                    icon: HeroIcons.arrowsRightLeft,
                    tooltip: tr(LocaleKeys.route_drawing_ui_reverse_route),
                    isEnabled: canReverse,
                    onPressed: onReverseRoute!,
                  ),
                ],
                if (onToggleCrosshair != null) ...[
                  const SizedBox(height: 6),
                  _buildToolbarButton(
                    context: context,
                    key: const Key('route_drawing_crosshair_button'),
                    icon: HeroIcons.plusCircle,
                    tooltip: isCrosshairActive
                        ? tr(LocaleKeys.route_drawing_ui_crosshair_tooltip_off)
                        : tr(LocaleKeys.route_drawing_ui_crosshair_tooltip_on),
                    isEnabled: true,
                    isActive: isCrosshairActive,
                    onPressed: onToggleCrosshair!,
                  ),
                ],
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
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required BuildContext context,
    required Key key,
    HeroIcons? icon,
    IconData? materialIcon,
    required String tooltip,
    required bool isEnabled,
    bool isActive = false,
    bool isPrimary = false,
    bool isDestructive = false,
    required VoidCallback onPressed,
  }) {
    final colorScheme = context.colorScheme;
    final Color iconColor;
    final Color? backgroundColor;

    if (!isEnabled) {
      iconColor = colorScheme.onSurface.withValues(alpha: 0.3);
      backgroundColor = null;
    } else if (isDestructive) {
      iconColor = colorScheme.error;
      backgroundColor = colorScheme.error.withValues(alpha: 0.1);
    } else if (isActive) {
      iconColor = colorScheme.onPrimary;
      backgroundColor = colorScheme.primary;
    } else if (isPrimary) {
      iconColor = colorScheme.primary;
      backgroundColor = colorScheme.primary.withValues(alpha: 0.1);
    } else {
      iconColor = colorScheme.onSurface;
      backgroundColor = null;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: isEnabled ? onPressed : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: materialIcon != null
                  ? Icon(materialIcon, size: 20, color: iconColor)
                  : HeroIcon(icon!, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
