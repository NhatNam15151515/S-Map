import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class FeaturePlaceholderWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const FeaturePlaceholderWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.sMapLightTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 56,
              color: AppColors.sMapTeal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppColors.googleDarkText.textTheme.subTitleStyle.copyWith(
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle ?? tr(LocaleKeys.feature_under_development),
            style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
