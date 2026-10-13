import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class OfflineStorageSummaryCard extends StatelessWidget {
  final String formattedStorage;
  final VoidCallback onCheckUpdates;

  const OfflineStorageSummaryCard({
    super.key,
    required this.formattedStorage,
    required this.onCheckUpdates,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_download_outlined,
              color: colorScheme.onPrimary,
              size: 26.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(LocaleKeys.offline_maps_storage_used),
                  style: colorScheme.onPrimary.textTheme.mediumStyle
                      .copyWith(fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  formattedStorage,
                  style: colorScheme.onPrimary.textTheme.boldStyle
                      .copyWith(fontSize: 20.sp),
                ),
              ],
            ),
          ),
          AppButton.outlined(
            text: tr(LocaleKeys.offline_maps_check_updates),
            width: null,
            height: 36.h,
            borderRadius: 8.r,
            textColor: colorScheme.onPrimary,
            borderColor: colorScheme.onPrimary,
            textStyle: colorScheme.onPrimary.textTheme.semiBoldStyle
                .copyWith(fontSize: 12.sp),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            onPressed: onCheckUpdates,
          ),
        ],
      ),
    );
  }
}
