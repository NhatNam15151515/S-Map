import 'package:s_map/commons/mixin/app_mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';
import 'package:flutter/material.dart';

class EmptyWidget extends StatelessWidget with AppMixin {
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Function? onRefresh;
  const EmptyWidget(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon,
      this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.sMapLightTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.inbox_rounded,
              size: 48,
              color: AppColors.sMapTeal,
            ),
          ),
          const SizedBox(height: 20),
          if (title != null)
            Text(
              title!,
              style: styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (onRefresh != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: OutlinedButton.icon(
                onPressed: () {
                  onRefresh!();
                },
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ),
                label: Text(
                  "Thử lại",
                  style: AppColors.sMapTeal.textTheme.boldStyle.copyWith(
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sMapTeal,
                  side: const BorderSide(color: AppColors.sMapTeal, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
