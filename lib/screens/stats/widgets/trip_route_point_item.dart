import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

/// Dòng hiển thị thông tin điểm trên lộ trình (Điểm xuất phát / Điểm đến).
///
/// Bao gồm dot chỉ thị màu kép (vòng ngoài alpha 0.15, vòng trong đậm),
/// nhãn phân loại (label) và địa chỉ chi tiết (address).
class TripRoutePointItem extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String address;
  final Widget? customLeading;

  const TripRoutePointItem({
    super.key,
    required this.dotColor,
    required this.label,
    required this.address,
    this.customLeading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        customLeading ??
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                    .copyWith(
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: colorScheme.onSurface.textTheme.semiBoldStyle.copyWith(
                  fontSize: 13,
                  height: 1.3,
                ),
                softWrap: true,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
