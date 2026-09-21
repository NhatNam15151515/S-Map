import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';

/// Ô chọn điểm xuất phát / điểm đến trong Route Direction Header.
///
/// Hiển thị icon, tên địa điểm, và biểu tượng tìm kiếm.
/// Phân biệt bằng màu icon (xanh cho origin, đỏ cho destination).
class RouteEndpointBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDefaultLocation;
  final VoidCallback onTap;

  const RouteEndpointBox({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDefaultLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: colorScheme.onSurface.textTheme.mediumStyle.copyWith(
                  fontSize: 13.5,
                  fontWeight:
                      isDefaultLocation ? FontWeight.w500 : FontWeight.w600,
                  color: isDefaultLocation
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.search_rounded,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
