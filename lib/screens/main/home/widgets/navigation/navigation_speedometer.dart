import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

/// Widget hiển thị đồng hồ đo tốc độ (HUD Speedometer Badge) trong quá trình dẫn đường.
///
/// Gồm 2 phần:
/// - **Speed limit badge** (phía trên): Biển báo tốc độ tối đa hình tròn viền đỏ,
///   chỉ hiện khi đoạn đường có tag `maxspeed` trong OSM.
/// - **Speedometer circle** (phía dưới): Tốc độ hiện tại (km/h).
///   Chuyển đỏ khi vượt tốc + haptic feedback.
class NavigationSpeedometer extends StatelessWidget {
  static const double circleSize = 56.0;
  static const double speedLimitBadgeSize = 36.0;

  const NavigationSpeedometer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) =>
          prev.currentSpeedKmh != curr.currentSpeedKmh ||
          prev.currentInstruction?.maxSpeedKmh !=
              curr.currentInstruction?.maxSpeedKmh,
      builder: (context, state) {
        final speedStr = RouteFormatHelper.formatSpeed(state.currentSpeedKmh);
        final speedLimit = state.currentSpeedLimit;
        final isOverSpeed = state.isOverSpeedLimit;

        // Haptic feedback khi mới bắt đầu vượt tốc
        if (isOverSpeed) {
          HapticFeedback.lightImpact();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Speed Limit Badge — biển báo tốc độ tối đa (chỉ hiện khi có data)
            if (speedLimit != null) ...[
              _SpeedLimitBadge(speedLimit: speedLimit),
              const SizedBox(height: 6),
            ],

            // Speedometer Circle — tốc độ hiện tại
            Container(
              width: circleSize,
              height: circleSize,
              decoration: BoxDecoration(
                color: isOverSpeed
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.12)
                    : colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOverSpeed
                      ? const Color(0xFFFF3B30)
                      : colorScheme.outline.withValues(alpha: 0.15),
                  width: isOverSpeed ? 2.0 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isOverSpeed
                        ? const Color(0xFFFF3B30).withValues(alpha: 0.25)
                        : colorScheme.shadow.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    speedStr,
                    style: (isOverSpeed
                            ? const Color(0xFFFF3B30)
                            : colorScheme.onSurface)
                        .textTheme
                        .boldStyle
                        .copyWith(
                          fontSize: 18,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                  ),
                  Text(
                    'km/h',
                    style: colorScheme.onSurfaceVariant.textTheme.mediumStyle
                        .copyWith(
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Biển báo tốc độ tối đa — hình tròn viền đỏ dày, nền trắng, số đen ở giữa.
/// Thiết kế giống biển báo giao thông Việt Nam (P.127).
class _SpeedLimitBadge extends StatelessWidget {
  final double speedLimit;

  const _SpeedLimitBadge({required this.speedLimit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: NavigationSpeedometer.speedLimitBadgeSize,
      height: NavigationSpeedometer.speedLimitBadgeSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFFF3B30),
          width: 3.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          speedLimit.round().toString(),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
