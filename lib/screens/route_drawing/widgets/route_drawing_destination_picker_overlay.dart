import 'package:flutter/material.dart';

/// Overlay tâm màn hình chọn điểm đến kèm nút xác nhận và huỷ
class RouteDrawingDestinationPickerOverlay extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final double bottomOffset;

  const RouteDrawingDestinationPickerOverlay({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    required this.bottomOffset,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        IgnorePointer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Container(
                  width: 2,
                  height: 12,
                  color: colorScheme.error,
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: bottomOffset,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('route_drawing_confirm_destination_btn'),
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Đặt làm điểm đến',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                key: const Key('route_drawing_cancel_destination_btn'),
                heroTag: 'route_drawing_cancel_dest_fab',
                onPressed: onCancel,
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.onSurface,
                elevation: 4,
                child: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
