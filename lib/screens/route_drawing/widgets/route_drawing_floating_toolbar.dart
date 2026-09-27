import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Floating Toolbar chứa các công cụ bản đồ khi vẽ route:
/// - Nằm ở góc dưới bên phải màn hình (trên Bottom Card).
/// - Đã bỏ các nút chọn điểm và nút toggle toàn bộ đường chim bay (vì đã có trên Menu từng đoạn).
class RouteDrawingFloatingToolbar extends StatefulWidget {
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

  @override
  State<RouteDrawingFloatingToolbar> createState() =>
      _RouteDrawingFloatingToolbarState();
}

class _RouteDrawingFloatingToolbarState
    extends State<RouteDrawingFloatingToolbar> {
  bool _isCollapsed = false;

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
      onConfirm: widget.onClear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final effectiveMaxHeight =
        widget.maxHeight ?? (screenHeight - 160).clamp(240.0, screenHeight);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.5, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _isCollapsed
          ? _buildCollapsedHandle(colorScheme)
          : _buildFullToolbar(context, colorScheme, effectiveMaxHeight),
    );
  }

  Widget _buildCollapsedHandle(ColorScheme colorScheme) {
    return Align(
      key: const ValueKey('toolbar_collapsed'),
      alignment: Alignment.centerRight,
      child: Material(
        color: colorScheme.surface,
        borderRadius:
            const BorderRadius.horizontal(left: Radius.circular(16)),
        elevation: 3,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.16),
        child: InkWell(
          key: const Key('route_drawing_expand_toolbar_button'),
          borderRadius:
              const BorderRadius.horizontal(left: Radius.circular(16)),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _isCollapsed = false);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.8,
                ),
                top: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.8,
                ),
                bottom: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                  width: 0.8,
                ),
              ),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Icon(
              Icons.keyboard_double_arrow_left_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullToolbar(
    BuildContext context,
    ColorScheme colorScheme,
    double effectiveMaxHeight,
  ) {
    return Align(
      key: const ValueKey('toolbar_expanded'),
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Handle / Tab ">>" ở sườn bên trái giữa thanh toolbar (thanh mảnh, mượt mà, không nhô quá nhiều)
            Material(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10),
              ),
              elevation: 1,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
              child: InkWell(
                key: const Key('route_drawing_collapse_toolbar_button'),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isCollapsed = true);
                },
                child: Tooltip(
                  message: tr(LocaleKeys.route_drawing_ui_collapse_toolbar),
                  child: Container(
                    width: 14,
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                        top: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                        bottom: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 12,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),

            // Thân chính Toolbar
            ConstrainedBox(
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
                      if (widget.onLocateMe != null) ...[
                        MapLocateButton(
                          key: const Key('route_drawing_locate_me_button'),
                          heroTag: 'route_drawing_locate_me_fab',
                          onPressed: widget.onLocateMe!,
                        ),
                        const SizedBox(height: 6),
                      ],
                      _buildToolbarButton(
                        context: context,
                        key: const Key('route_drawing_undo_button'),
                        icon: HeroIcons.arrowUturnLeft,
                        tooltip: tr(LocaleKeys.route_drawing_ui_undo),
                        isEnabled: widget.canUndo,
                        onPressed: widget.onUndo,
                      ),
                      const SizedBox(height: 6),
                      _buildToolbarButton(
                        context: context,
                        key: const Key('route_drawing_redo_button'),
                        icon: HeroIcons.arrowUturnRight,
                        tooltip: tr(LocaleKeys.route_drawing_ui_redo),
                        isEnabled: widget.canRedo,
                        onPressed: widget.onRedo,
                      ),
                      if (widget.onReverseRoute != null) ...[
                        const SizedBox(height: 6),
                        _buildToolbarButton(
                          context: context,
                          key: const Key('route_drawing_reverse_button'),
                          icon: HeroIcons.arrowsRightLeft,
                          tooltip: tr(LocaleKeys.route_drawing_ui_reverse_route),
                          isEnabled: widget.canReverse,
                          onPressed: widget.onReverseRoute!,
                        ),
                      ],
                      if (widget.onToggleCrosshair != null) ...[
                        const SizedBox(height: 6),
                        _buildToolbarButton(
                          context: context,
                          key: const Key('route_drawing_crosshair_button'),
                          icon: HeroIcons.plusCircle,
                          tooltip: widget.isCrosshairActive
                              ? tr(LocaleKeys.route_drawing_ui_crosshair_tooltip_off)
                              : tr(LocaleKeys.route_drawing_ui_crosshair_tooltip_on),
                          isEnabled: true,
                          isActive: widget.isCrosshairActive,
                          onPressed: widget.onToggleCrosshair!,
                        ),
                      ],
                      const SizedBox(height: 6),
                      _buildToolbarButton(
                        context: context,
                        key: const Key('route_drawing_clear_button'),
                        icon: HeroIcons.trash,
                        tooltip: tr(LocaleKeys.route_drawing_ui_clear_all),
                        isEnabled: widget.canClear,
                        isDestructive: true,
                        onPressed: () => _showClearConfirmDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
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
