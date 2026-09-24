import 'package:flutter/material.dart';

/// Icon hiển thị cho từng điểm dừng (Waypoint) chuẩn phong cách Google Maps:
/// - Điểm xuất phát (index == 0): Chấm tròn xanh dương viền trắng (GPS location dot).
/// - Điểm kết thúc (index == totalCount - 1): Icon Pin đỏ (Destination marker).
/// - Điểm trung gian: Vòng tròn rỗng (Intermediate stop).
class RouteDrawingPointIcon extends StatelessWidget {
  final int index;
  final int totalCount;

  const RouteDrawingPointIcon({
    super.key,
    required this.index,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 1. Điểm xuất phát (Điểm đầu tiên)
    if (index == 0) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }

    // 2. Điểm kết thúc (Điểm cuối cùng khi có từ 2 điểm trở lên)
    if (index == totalCount - 1 && totalCount >= 2) {
      return Icon(
        Icons.location_on_rounded,
        size: 22,
        color: Colors.redAccent.shade400,
      );
    }

    // 3. Điểm dừng trung gian (Vòng tròn rỗng)
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.75),
          width: 2.2,
        ),
      ),
    );
  }
}
