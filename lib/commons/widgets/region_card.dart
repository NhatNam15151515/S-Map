import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class RegionCard extends StatelessWidget {
  final RegionModel region;
  final double progress;
  final bool isCurrentlyDownloading;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const RegionCard({
    super.key,
    required this.region,
    required this.progress,
    this.isCurrentlyDownloading = false,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  void _showDeleteConfirmDialog(BuildContext context) {
    final colorScheme = context.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            tr(LocaleKeys.offline_maps_delete_confirm_title),
            style: colorScheme.onSurface.textTheme.boldStyle
                .copyWith(fontSize: 18.sp),
          ),
          content: Text(
            tr(LocaleKeys.offline_maps_delete_confirm_desc),
            style: colorScheme.onSurfaceVariant.textTheme.regularStyle
                .copyWith(fontSize: 14.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.safePop(),
              child: Text(
                tr(LocaleKeys.offline_maps_cancel_btn),
                style: colorScheme.onSurfaceVariant.textTheme.mediumStyle
                    .copyWith(fontSize: 14.sp),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: () {
                dialogContext.safePop();
                onDelete();
              },
              child: Text(
                tr(LocaleKeys.offline_maps_delete_btn),
                style: colorScheme.onError.textTheme.semiBoldStyle
                    .copyWith(fontSize: 14.sp),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = isCurrentlyDownloading || region.isDownloading;
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: colorScheme.outline.withAlpha(50),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row Header: Icon + Tên vùng + Badge trạng thái
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: colorScheme.primary,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region.id == 'vietnam'
                          ? tr(LocaleKeys.offline_maps_vietnam_name)
                          : region.name,
                      style: colorScheme.onSurface.textTheme.boldStyle
                          .copyWith(fontSize: 16.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      region.id == 'vietnam'
                          ? tr(LocaleKeys.offline_maps_vietnam_desc)
                          : region.description,
                      style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                          .copyWith(fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              _buildStatusBadge(context),
            ],
          ),
          SizedBox(height: 12.h),

          // Dung lượng & Version
          Row(
            children: [
              Icon(Icons.sd_storage_outlined,
                  size: 14.sp, color: colorScheme.onSurfaceVariant),
              SizedBox(width: 4.w),
              Text(
                region.formattedSize,
                style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                    .copyWith(fontSize: 12.sp),
              ),
              SizedBox(width: 16.w),
              Icon(Icons.verified_outlined,
                  size: 14.sp, color: colorScheme.onSurfaceVariant),
              SizedBox(width: 4.w),
              Text(
                'v${region.version}',
                style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                    .copyWith(fontSize: 12.sp),
              ),
              if (region.downloadedAt != null) ...[
                SizedBox(width: 16.w),
                Icon(Icons.calendar_today_outlined,
                    size: 14.sp, color: colorScheme.onSurfaceVariant),
                SizedBox(width: 4.w),
                Text(
                  DateFormat('dd/MM/yyyy', context.locale.toString())
                      .format(region.downloadedAt!),
                  style: colorScheme.onSurfaceVariant.textTheme.captionStyle
                      .copyWith(fontSize: 12.sp),
                ),
              ],
            ],
          ),

          // Progress bar khi đang tải
          if (isDownloading) ...[
            SizedBox(height: 14.h),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      region.status == RegionDownloadStatus.extracting
                          ? tr(LocaleKeys.offline_maps_extracting)
                          : tr(LocaleKeys.offline_maps_downloading),
                      style: colorScheme.primary.textTheme.mediumStyle
                          .copyWith(fontSize: 12.sp),
                    ),
                    Text(
                      () {
                        final safeProgress =
                            (progress.isNaN || progress.isInfinite)
                                ? 0.0
                                : progress.clamp(0.0, 1.0);
                        return '${(safeProgress * 100).toInt()}%';
                      }(),
                      style: colorScheme.primary.textTheme.boldStyle
                          .copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 6.h,
                    backgroundColor: colorScheme.primary.withAlpha(30),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: 14.h),

          // Row Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isDownloading) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  ),
                  onPressed: onCancel,
                  icon: Icon(Icons.close_rounded, size: 16.sp),
                  label: Text(
                    tr(LocaleKeys.offline_maps_cancel_btn),
                    style: colorScheme.error.textTheme.mediumStyle
                        .copyWith(fontSize: 13.sp),
                  ),
                ),
              ] else if (region.status == RegionDownloadStatus.notDownloaded ||
                  region.status == RegionDownloadStatus.failed) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  ),
                  onPressed: onDownload,
                  icon: Icon(Icons.download_rounded, size: 16.sp),
                  label: Text(
                    tr(LocaleKeys.offline_maps_download_btn),
                    style: colorScheme.onPrimary.textTheme.semiBoldStyle
                        .copyWith(fontSize: 13.sp),
                  ),
                ),
              ] else ...[
                if (region.hasUpdate) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColors.statsOrange,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r)),
                      padding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    ),
                    onPressed: onDownload,
                    icon: Icon(Icons.system_update_alt_rounded, size: 16.sp),
                    label: Text(
                      tr(LocaleKeys.offline_maps_update_btn),
                      style: colorScheme.onPrimary.textTheme.semiBoldStyle
                          .copyWith(fontSize: 13.sp),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                  onPressed: () => _showDeleteConfirmDialog(context),
                  icon: Icon(Icons.delete_outline_rounded, size: 16.sp),
                  label: Text(
                    tr(LocaleKeys.offline_maps_delete_btn),
                    style: colorScheme.error.textTheme.mediumStyle
                        .copyWith(fontSize: 13.sp),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final colorScheme = context.colorScheme;
    final themeColors = context.themeColors;

    switch (region.status) {
      case RegionDownloadStatus.downloaded:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: themeColors.statsSuccessBg,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 12.sp, color: themeColors.statsSuccess),
              SizedBox(width: 4.w),
              Text(
                tr(LocaleKeys.offline_maps_downloaded),
                style: themeColors.statsSuccess.textTheme.semiBoldStyle
                    .copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        );
      case RegionDownloadStatus.updateAvailable:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: themeColors.statsOrange.withAlpha(25),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 12.sp, color: themeColors.statsOrange),
              SizedBox(width: 4.w),
              Text(
                tr(LocaleKeys.offline_maps_update_available),
                style: themeColors.statsOrange.textTheme.semiBoldStyle
                    .copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        );
      case RegionDownloadStatus.downloading:
      case RegionDownloadStatus.extracting:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10.w,
                height: 10.h,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colorScheme.primary),
              ),
              SizedBox(width: 6.w),
              Text(
                () {
                  final safeProgress = (progress.isNaN || progress.isInfinite)
                      ? 0.0
                      : progress.clamp(0.0, 1.0);
                  return '${(safeProgress * 100).toInt()}%';
                }(),
                style: colorScheme.primary.textTheme.semiBoldStyle
                    .copyWith(fontSize: 11.sp),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
