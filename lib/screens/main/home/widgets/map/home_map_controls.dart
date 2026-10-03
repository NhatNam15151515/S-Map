import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class HomeMapControls extends StatelessWidget {
  final MapDisplayCubit displayCubit;
  final VoidCallback? onSwitchLayers;
  final double bottom;

  // Drawing mode properties
  final bool isDrawingMode;
  final bool canReverse;
  final bool isCrosshairActive;
  final VoidCallback? onReverseRoute;
  final VoidCallback? onToggleCrosshair;

  const HomeMapControls({
    super.key,
    required this.displayCubit,
    this.onSwitchLayers,
    this.bottom = 175,
    this.isDrawingMode = false,
    this.canReverse = false,
    this.isCrosshairActive = true,
    this.onReverseRoute,
    this.onToggleCrosshair,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      right: 16,
      bottom: bottom + MediaQuery.paddingOf(context).bottom,
      child: BlocBuilder<MapDisplayCubit, MapDisplayState>(
        bloc: displayCubit,
        buildWhen: (previous, current) =>
            previous.rotation != current.rotation ||
            previous.orientationMode != current.orientationMode ||
            previous.isNightMode != current.isNightMode,
        builder: (context, state) {
          return MapControls(
            onZoomIn: displayCubit.zoomIn,
            onZoomOut: displayCubit.zoomOut,
            onLocateMe: displayCubit.locateMe,
            onSwitchLayers: onSwitchLayers ?? displayCubit.toggleNightMode,
            onToggleOrientation: displayCubit.toggleOrientationMode,
            rotation: state.rotation,
            orientationMode: state.orientationMode,
            locateHeroTag: 'home_screen_locate_fab',
            customMiddleControl:
                isDrawingMode ? _buildDrawingControls(context) : null,
          );
        },
      ),
    );
  }

  Widget _buildDrawingControls(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      width: 44,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReverseRoute != null) ...[
            _buildActionButton(
              context: context,
              key: const Key('route_drawing_reverse_button'),
              icon: HeroIcons.arrowsRightLeft,
              tooltip: tr(LocaleKeys.route_drawing_ui_reverse_route),
              isEnabled: canReverse,
              onPressed: () {
                HapticFeedback.mediumImpact();
                onReverseRoute?.call();
              },
            ),
          ],
          if (onToggleCrosshair != null) ...[
            _buildDivider(colorScheme),
            _buildActionButton(
              context: context,
              key: const Key('route_drawing_crosshair_button'),
              icon: HeroIcons.plusCircle,
              tooltip: isCrosshairActive
                  ? tr(LocaleKeys.route_drawing_ui_crosshair_tooltip_off)
                  : tr(LocaleKeys.route_drawing_ui_crosshair_tooltip_on),
              isEnabled: true,
              isActive: isCrosshairActive,
              onPressed: onToggleCrosshair,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: colorScheme.outline.withAlpha(80),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Key key,
    required HeroIcons icon,
    required String tooltip,
    required bool isEnabled,
    bool isActive = false,
    VoidCallback? onPressed,
  }) {
    final colorScheme = context.colorScheme;
    final Color iconColor;

    if (!isEnabled) {
      iconColor = colorScheme.onSurface.withValues(alpha: 0.3);
    } else if (isActive) {
      iconColor = colorScheme.primary;
    } else {
      iconColor = colorScheme.onSurface;
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          key: key,
          customBorder: const CircleBorder(),
          onTap: isEnabled ? onPressed : null,
          child: SizedBox(
            width: 44,
            height: 38,
            child: Center(
              child: HeroIcon(icon, size: 19, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
