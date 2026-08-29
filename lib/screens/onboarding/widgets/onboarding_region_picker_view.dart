import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class OnboardingRegionPickerView extends StatelessWidget {
  final DownloadRegionState state;
  final VoidCallback onSkip;
  final VoidCallback onRetry;
  final ValueChanged<String> onDownload;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onCancel;

  const OnboardingRegionPickerView({
    super.key,
    required this.state,
    required this.onSkip,
    required this.onRetry,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  List<RegionModel> get _availableRegions =>
      state.regions.where((r) => !r.isDownloaded).toList();

  @override
  Widget build(BuildContext context) {
    final availableRegions = _availableRegions;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_region_title),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            tr(LocaleKeys.onboarding_region_subtitle),
            style: AppColors.white.textTheme.regularStyle
                .copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 24.h),
          Expanded(
            child: state.isLoading && state.regions.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.white))
                : availableRegions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_off_rounded,
                                size: 48.r, color: AppColors.white),
                            SizedBox(height: 12.h),
                            Text(
                              tr(LocaleKeys.offline_maps_error),
                              style: AppColors.white.textTheme.mediumStyle
                                  .copyWith(fontSize: 14.sp),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            TextButton(
                              onPressed: onRetry,
                              child: Text(
                                tr(LocaleKeys.onboarding_retry_btn),
                                style: AppColors.white.textTheme.boldStyle
                                    .copyWith(
                                  fontSize: 14.sp,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: availableRegions.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final region = availableRegions[index];
                          return RegionCard(
                            region: region,
                            progress: state.getProgress(region.id),
                            isCurrentlyDownloading:
                                state.currentlyDownloadingRegionId == region.id,
                            onDownload: () => onDownload(region.id),
                            onDelete: () => onDelete(region.id),
                            onCancel: () => onCancel(region.id),
                          );
                        },
                      ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                tr(LocaleKeys.onboarding_skip_btn),
                style: AppColors.white.textTheme.semiBoldStyle.copyWith(
                  fontSize: 14.sp,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
