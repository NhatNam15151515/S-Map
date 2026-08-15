import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class LoginHeaderWidget extends StatelessWidget {
  final String appName;

  const LoginHeaderWidget({
    super.key,
    required this.appName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.sMapTealSurface,
            AppColors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.sMapLightTeal,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.sMapTeal.withAlpha(30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AppAsset.logo.image.build(
              size: const Size(56, 56),
              color: AppColors.sMapTeal,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            appName,
            style: AppColors.sMapDarkTeal.textTheme.headlineStyle.copyWith(
              letterSpacing: 1,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(LocaleKeys.login_subtitle),
            style: AppColors.onSurfaceVariant.textTheme.textStyle.copyWith(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
