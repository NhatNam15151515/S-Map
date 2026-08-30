import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class InitialLogoWidget extends StatelessWidget {
  final String appName;

  const InitialLogoWidget({
    super.key,
    required this.appName,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // App Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.onPrimary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: AppAsset.logo.image.build(
            size: const Size(64, 64),
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 24),
        // App name with shimmer
        Shimmer.fromColors(
          baseColor: colorScheme.onPrimary,
          highlightColor: colorScheme.onPrimary.withValues(alpha: 0.5),
          child: Text(
            appName,
            style: colorScheme.onPrimary.textTheme.displayStyle.copyWith(
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Tagline
        Text(
          tr(LocaleKeys.app_tagline),
          style: colorScheme.onPrimary.withValues(alpha: 0.8).textTheme.textStyle.copyWith(
                fontSize: 14,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}
