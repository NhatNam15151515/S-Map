import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class OnboardingDownloadingView extends StatelessWidget {
  final DownloadRegionState state;
  final VoidCallback onCancel;

  const OnboardingDownloadingView({
    super.key,
    required this.state,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final regionId = state.currentlyDownloadingRegionId;
    final region = state.regions.where((r) => r.id == regionId).firstOrNull;
    final progress = state.getProgress(regionId ?? '');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_download_rounded,
            size: 100.r,
            color: AppColors.white,
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_downloading_title),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 24.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            region?.name ?? tr(LocaleKeys.onboarding_downloading_region_fallback),
            style: AppColors.white.textTheme.semiBoldStyle
                .copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 32.h),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            backgroundColor: AppColors.white.withAlpha(50),
            color: AppColors.white,
            minHeight: 8.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
          SizedBox(height: 16.h),
          Text(
            () {
              final safeProgress = (progress.isNaN || progress.isInfinite)
                  ? 0.0
                  : progress.clamp(0.0, 1.0);
              final percent = (safeProgress * 100).toStringAsFixed(1);
              if (region != null && region.sizeBytes > 0) {
                final downloadedBytes = (region.sizeBytes * safeProgress).toInt();
                final downloadedMb =
                    (downloadedBytes / (1024 * 1024)).toStringAsFixed(1);
                return "$percent% ($downloadedMb MB / ${region.formattedSize})";
              }
              return "$percent%";
            }(),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 16.sp),
          ),
          SizedBox(height: 24.h),
          TextButton(
            onPressed: onCancel,
            child: Text(
              tr(LocaleKeys.offline_maps_cancel_btn),
              style: AppColors.white.textTheme.semiBoldStyle.copyWith(
                fontSize: 14.sp,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
