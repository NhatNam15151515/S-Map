import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/models/models.dart';

/// Selector cho các lộ trình thay thế (alternative routes) trong Route Preview.
///
/// Hiển thị danh sách horizontal các chip lộ trình, cho phép người dùng
/// chọn giữa các phương án tuyến đường khác nhau.
class RoutePreviewAltRouteSelector extends StatelessWidget {
  final List<RouteResult> alternativeRoutes;
  final int selectedRouteIndex;

  const RoutePreviewAltRouteSelector({
    super.key,
    required this.alternativeRoutes,
    required this.selectedRouteIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(alternativeRoutes.length, (index) {
          final alt = alternativeRoutes[index];
          final isSelected = index == selectedRouteIndex;
          final altDurationStr = RouteFormatHelper.formatDuration(alt.time);
          final altDistanceStr = RouteFormatHelper.formatDistance(alt.distance);
          final title = alt.routeTitle ?? 'Lộ trình ${index + 1}';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                context
                    .read<RoutePreviewCubit>()
                    .selectAlternativeRoute(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 15,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$title: $altDurationStr ($altDistanceStr)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
