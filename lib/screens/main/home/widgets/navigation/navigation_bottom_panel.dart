import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

/// Bottom Navigation Bar đơn giản theo chuẩn Google Maps:
/// - Nút X (đóng) bên trái
/// - Thời gian còn lại + khoảng cách + ETA giữa thanh
/// - Nút recenter/navigate bên phải
class NavigationBottomPanel extends StatelessWidget {
  final VoidCallback onStopNavigation;
  final VoidCallback? onRecenter;

  const NavigationBottomPanel({
    super.key,
    required this.onStopNavigation,
    this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) =>
          prev.remainingDistance != curr.remainingDistance ||
          prev.remainingDurationMs != curr.remainingDurationMs ||
          prev.status != curr.status,
      builder: (context, state) {
        if (!state.isNavigating) {
          return const SizedBox.shrink();
        }

        final remainingDistStr = RouteFormatHelper.formatDistance(
          state.remainingDistance,
        );
        final remainingDurationStr = RouteFormatHelper.formatDuration(
          state.remainingDurationMs,
        );
        final etaTimeStr = RouteFormatHelper.formatEtaClockTime(
          state.remainingDurationMs,
        );

        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle nhỏ
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Bottom bar: X | Duration/Distance/ETA | Recenter
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // 1. Nút X đóng navigation
                        _buildCircleButton(
                          colorScheme: colorScheme,
                          onTap: onStopNavigation,
                          child: Icon(
                            Icons.close_rounded,
                            color: colorScheme.onSurface,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 2. Thông tin ETA — giữa
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Thời gian còn lại (lớn, nổi bật)
                              Text(
                                remainingDurationStr,
                                style: colorScheme.onSurface.textTheme
                                    .boldStyle
                                    .copyWith(
                                  fontSize: 22,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Khoảng cách + giờ đến
                              Text(
                                '$remainingDistStr • $etaTimeStr',
                                style: colorScheme.onSurfaceVariant.textTheme
                                    .mediumStyle
                                    .copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // 3. Nút recenter (diamond icon xanh)
                        _buildCircleButton(
                          colorScheme: colorScheme,
                          onTap: onRecenter ?? () {},
                          filled: true,
                          child: Icon(
                            Icons.diamond_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircleButton({
    required ColorScheme colorScheme,
    required VoidCallback onTap,
    required Widget child,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: filled
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
