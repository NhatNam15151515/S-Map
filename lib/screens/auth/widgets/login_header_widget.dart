import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withAlpha(25),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(35),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(40),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AppAsset.logo.image.build(
              size: const Size(56, 56),
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            appName,
            style: colorScheme.primary.textTheme.headlineStyle.copyWith(
              letterSpacing: 1,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(LocaleKeys.login_subtitle),
            style: colorScheme.onSurfaceVariant.textTheme.textStyle.copyWith(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
