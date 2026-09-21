import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';

/// Card hiển thị trạng thái đang tính toán lộ trình (loading).
class RoutePreviewLoadingCard extends StatelessWidget {
  final VoidCallback onClose;

  const RoutePreviewLoadingCard({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              tr(LocaleKeys.routing_calculating_moped_route),
              style: colorScheme.onSurface.textTheme.mediumStyle.copyWith(
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            onPressed: onClose,
            tooltip: tr(LocaleKeys.cancel),
          ),
        ],
      ),
    );
  }
}
