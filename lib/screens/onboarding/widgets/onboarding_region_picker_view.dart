import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class OnboardingRegionPickerView extends StatelessWidget {
  final List<RegionModel> regions;
  final bool isLoading;
  final bool hasError;
  final bool hasDownloadedRegions;
  final VoidCallback onSkip;
  final VoidCallback onRetry;
  final ValueChanged<String> onDownload;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onCancel;

  const OnboardingRegionPickerView({
    super.key,
    required this.regions,
    required this.isLoading,
    required this.hasError,
    this.hasDownloadedRegions = false,
    required this.onSkip,
    required this.onRetry,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_region_title),
            style:
                colorScheme.onPrimary.textTheme.boldStyle.copyWith(fontSize: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            tr(LocaleKeys.onboarding_region_subtitle),
            style: colorScheme.onPrimary.textTheme.regularStyle
                .copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 24.h),
          Expanded(
            child: isLoading && regions.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: colorScheme.onPrimary))
                : regions.isEmpty
                    ? Center(
                        child: EmptyWidget(
                          icon: hasDownloadedRegions
                              ? Icons.check_circle_outline_rounded
                              : Icons.wifi_off_rounded,
                          title: hasDownloadedRegions
                              ? tr(LocaleKeys.offline_maps_all_downloaded)
                              : tr(LocaleKeys.offline_maps_error),
                          textColor: colorScheme.onPrimary,
                          iconColor: colorScheme.onPrimary,
                          onRefresh: (!hasDownloadedRegions &&
                                  (hasError || regions.isEmpty))
                              ? onRetry
                              : null,
                          actionLabel: tr(LocaleKeys.onboarding_retry_btn),
                        ),
                      )
                    : ListView.separated(
                        itemCount: regions.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final region = regions[index];
                          return RegionCard(
                            region: region,
                            progress: region.downloadProgress,
                            isCurrentlyDownloading: region.isDownloading,
                            onDownload: () => onDownload(region.id),
                            onDelete: () => onDelete(region.id),
                            onCancel: () => onCancel(region.id),
                          );
                        },
                      ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: AppButton.text(
              text: tr(LocaleKeys.onboarding_skip_btn),
              textColor: colorScheme.onPrimary,
              textStyle: colorScheme.onPrimary.textTheme.semiBoldStyle.copyWith(
                fontSize: 14.sp,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.onPrimary,
              ),
              onPressed: onSkip,
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
