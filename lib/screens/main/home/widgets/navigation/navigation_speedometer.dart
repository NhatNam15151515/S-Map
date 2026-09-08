import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';

/// Widget hiển thị đồng hồ đo tốc độ (HUD Speedometer Badge) hình tròn trong quá trình dẫn đường.
///
/// Tự động lắng nghe `NavigationBloc` khi tốc độ GPS thay đổi (`currentSpeedKmh`),
/// tránh gây rebuild lãng phí cho các controls bản đồ xung quanh (la bàn, nút recenter).
class NavigationSpeedometer extends StatelessWidget {
  static const double circleSize = 56.0;

  const NavigationSpeedometer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return BlocBuilder<NavigationBloc, NavigationState>(
      buildWhen: (prev, curr) => prev.currentSpeedKmh != curr.currentSpeedKmh,
      builder: (context, state) {
        final speedStr = RouteFormatHelper.formatSpeed(state.currentSpeedKmh);

        return Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15),
              width: 0.8,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                speedStr,
                style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                  fontSize: 18,
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              Text(
                'km/h',
                style:
                    colorScheme.onSurfaceVariant.textTheme.mediumStyle.copyWith(
                  fontSize: 9,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
