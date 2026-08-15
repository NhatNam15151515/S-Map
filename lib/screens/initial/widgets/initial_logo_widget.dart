import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/services/services.dart';

class InitialLogoWidget extends StatelessWidget {
  const InitialLogoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: AppAsset.logo.image.build(
            size: const Size(64, 64),
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 24),
        // App name with shimmer from PackageInfoService
        Shimmer.fromColors(
          baseColor: AppColors.white,
          highlightColor: AppColors.white.withAlpha(128),
          child: Text(
            PackageInfoService.instance.appName,
            style: AppColors.white.textTheme.displayStyle.copyWith(
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Tagline
        Text(
          tr(LocaleKeys.app_tagline),
          style: AppColors.white.withAlpha(200).textTheme.textStyle.copyWith(
                fontSize: 14,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}
