import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class OnboardingDownloadingView extends StatelessWidget {
  final String regionName;
  final double progress;
  final String progressText;
  final VoidCallback onCancel;

  const OnboardingDownloadingView({
    super.key,
    required this.regionName,
    required this.progress,
    required this.progressText,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return DownloadProgressView(
      title: tr(LocaleKeys.onboarding_downloading_title),
      itemName: regionName,
      progress: progress,
      progressText: progressText,
      cancelLabel: tr(LocaleKeys.offline_maps_cancel_btn),
      onCancel: onCancel,
      foregroundColor: colorScheme.onPrimary,
      progressColor: colorScheme.onPrimary,
      progressBackgroundColor: colorScheme.onPrimary.withValues(alpha: 0.2),
    );
  }
}

