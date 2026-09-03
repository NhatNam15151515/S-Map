import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class RouteDrawingFloatingToolbar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool canClear;
  final bool hasPoints;
  final bool isMyLocationOrigin;
  final bool isResolvingMyLocation;
  final bool isMarkerDestination;
  final bool hasMarkerDestination;
  final VoidCallback? onLocateMe;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onFitBounds;
  final VoidCallback? onReverseRoute;
  final bool canReverse;
  final VoidCallback? onToggleCrosshair;
  final bool isCrosshairActive;
  final VoidCallback? onToggleMyLocationOrigin;
  final VoidCallback? onToggleMarkerDestination;
  final VoidCallback? onRemoveMarkerDestination;
  final bool isStraightLineMode;
  final VoidCallback? onToggleStraightLineMode;

  const RouteDrawingFloatingToolbar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.canClear,
    required this.hasPoints,
    this.isMyLocationOrigin = false,
    this.isResolvingMyLocation = false,
    this.isMarkerDestination = false,
    this.hasMarkerDestination = false,
    this.onLocateMe,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onFitBounds,
    this.onReverseRoute,
    this.canReverse = false,
    this.onToggleCrosshair,
    this.isCrosshairActive = true,
    this.onToggleMyLocationOrigin,
    this.onToggleMarkerDestination,
    this.onRemoveMarkerDestination,
    this.isStraightLineMode = false,
    this.onToggleStraightLineMode,
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
          style: colorScheme.onSurfaceVariant.textTheme.textStyle
              .copyWith(fontSize: 14),
        ),
        actions: [
          TextButton(
            key: const Key('route_drawing_clear_cancel_btn'),
            onPressed: () => dialogCtx.safePop(),
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
            if (onLocateMe != null) ...[
              MapLocateButton(
                key: const Key('route_drawing_locate_me_button'),
                heroTag: 'route_drawing_locate_me_fab',
                onPressed: onLocateMe!,
              ),
              const SizedBox(height: 6),
            ],
            if (onToggleMyLocationOrigin != null) ...[
              _buildToolbarButton(
                context: context,
                key: const Key('route_drawing_my_location_origin_button'),
                icon: HeroIcons.mapPin,
                tooltip: tr(LocaleKeys.route_drawing_ui_use_my_location_origin),
                isEnabled: !isResolvingMyLocation,
                isActive: isMyLocationOrigin,
                isLoading: isResolvingMyLocation,
                onPressed: onToggleMyLocationOrigin!,
              ),
              const SizedBox(height: 6),
            ],
            if (hasMarkerDestination && onToggleMarkerDestination != null) ...[
              _buildToolbarButton(
                context: context,
                key: const Key('route_drawing_marker_destination_button'),
                icon: HeroIcons.flag,
                tooltip: tr(LocaleKeys.route_drawing_ui_use_selected_destination),
                isEnabled: true,
                isActive: isMarkerDestination,
                onPressed: onToggleMarkerDestination!,
              ),
              const SizedBox(height: 6),
            ],
            if (hasMarkerDestination && onRemoveMarkerDestination != null) ...[
              _buildToolbarButton(
                context: context,
                key: const Key('route_drawing_remove_destination_button'),
                icon: HeroIcons.xMark,
                tooltip: 'Xóa điểm kết thúc',
                isEnabled: true,
                onPressed: onRemoveMarkerDestination!,
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
            const SizedBox(height: 6),
            _buildToolbarButton(
              context: context,
              key: const Key('route_drawing_fit_bounds_button'),
              icon: HeroIcons.viewfinderCircle,
              tooltip: tr(LocaleKeys.route_drawing_ui_fit_bounds),
              isEnabled: hasPoints,
              isPrimary: true,
              onPressed: onFitBounds,
            ),
            if (onReverseRoute != null) ...[
              const SizedBox(height: 6),
              _buildToolbarButton(
                context: context,
                key: const Key('route_drawing_reverse_button'),
                icon: HeroIcons.arrowsRightLeft,
                tooltip: 'Đảo chiều lộ trình',
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
                    ? 'Tắt tâm ngắm vẽ đường'
                    : 'Bật tâm ngắm vẽ đường',
                isEnabled: true,
                isActive: isCrosshairActive,
                onPressed: onToggleCrosshair!,
              ),
            ],
            if (onToggleStraightLineMode != null) ...[
              const SizedBox(height: 6),
              _buildToolbarButton(
                context: context,
                key: const Key('route_drawing_toggle_straight_line_btn'),
                materialIcon: Icons.airplanemode_active_rounded,
                tooltip: isStraightLineMode
                    ? tr(LocaleKeys.route_drawing_ui_straight_line_mode_tooltip_off)
                    : tr(LocaleKeys.route_drawing_ui_straight_line_mode_tooltip_on),
                isEnabled: true,
                isActive: isStraightLineMode,
                onPressed: onToggleStraightLineMode!,
              ),
            ],
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
    HeroIcons? icon,
    IconData? materialIcon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onPressed,
    bool isDestructive = false,
    bool isPrimary = false,
    bool isActive = false,
    bool isLoading = false,
  }) {
    final colorScheme = context.colorScheme;
    Color iconColor;
    Color? backgroundColor;

    if (!isEnabled) {
      iconColor = colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isActive) {
      iconColor = colorScheme.onPrimary;
      backgroundColor = colorScheme.primary;
    } else if (isDestructive) {
      iconColor = colorScheme.error;
    } else if (isPrimary) {
      iconColor = colorScheme.primary;
    } else {
      iconColor = colorScheme.onSurface;
    }

    final Widget iconWidget;
    if (isLoading) {
      iconWidget = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      );
    } else if (materialIcon != null) {
      iconWidget = Icon(materialIcon, size: 20, color: iconColor);
    } else if (icon != null) {
      iconWidget = HeroIcon(icon, size: 20, color: iconColor);
    } else {
      iconWidget = const SizedBox(width: 20, height: 20);
    }

    Widget button = IconButton(
      key: key,
      icon: iconWidget,
      tooltip: tooltip,
      onPressed: isEnabled ? onPressed : null,
    );

    if (backgroundColor != null) {
      return Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: button,
      );
    }

    return button;
  }
}
