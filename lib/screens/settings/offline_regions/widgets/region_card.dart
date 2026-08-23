import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
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
    required this.isCurrentlyDownloading,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text(
            tr(LocaleKeys.offline_maps_delete_confirm_title),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            tr(LocaleKeys.offline_maps_delete_confirm_desc),
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                tr(LocaleKeys.offline_maps_cancel_btn),
                style: const TextStyle(fontSize: 14, color: AppColors.googleGreyText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.googleRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete();
              },
              child: Text(
                tr(LocaleKeys.offline_maps_delete_btn),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
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

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.outline,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
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
                  color: AppColors.sMapTeal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.map_outlined,
                  color: AppColors.sMapTeal,
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region.name,
                      style: AppColors.googleDarkText.textTheme.boldStyle.copyWith(fontSize: 16.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      region.description,
                      style: AppColors.googleGreyText.textTheme.captionStyle.copyWith(fontSize: 13.sp),
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
              Icon(Icons.sd_storage_outlined, size: 14.sp, color: AppColors.googleGreyText),
              SizedBox(width: 4.w),
              Text(
                region.formattedSize,
                style: AppColors.googleGreyText.textTheme.captionStyle.copyWith(fontSize: 12.sp),
              ),
              SizedBox(width: 16.w),
              Icon(Icons.verified_outlined, size: 14.sp, color: AppColors.googleGreyText),
              SizedBox(width: 4.w),
              Text(
                'v${region.version}',
                style: AppColors.googleGreyText.textTheme.captionStyle.copyWith(fontSize: 12.sp),
              ),
              if (region.downloadedAt != null) ...[
                SizedBox(width: 16.w),
                Icon(Icons.calendar_today_outlined, size: 14.sp, color: AppColors.googleGreyText),
                SizedBox(width: 4.w),
                Text(
                  DateFormat('dd/MM/yyyy').format(region.downloadedAt!),
                  style: AppColors.googleGreyText.textTheme.captionStyle.copyWith(fontSize: 12.sp),
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
                      progress >= 0.75
                          ? tr(LocaleKeys.offline_maps_extracting)
                          : tr(LocaleKeys.offline_maps_downloading),
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: AppColors.sMapTeal),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppColors.sMapTeal),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 6.h,
                    backgroundColor: AppColors.sMapTeal.withOpacity(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sMapTeal),
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
                    foregroundColor: AppColors.googleRed,
                    side: const BorderSide(color: AppColors.googleRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  ),
                  onPressed: onCancel,
                  icon: Icon(Icons.close_rounded, size: 16.sp),
                  label: Text(tr(LocaleKeys.offline_maps_cancel_btn), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
                ),
              ] else if (region.status == RegionDownloadStatus.notDownloaded ||
                  region.status == RegionDownloadStatus.failed) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sMapTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  ),
                  onPressed: onDownload,
                  icon: Icon(Icons.download_rounded, size: 16.sp),
                  label: Text(tr(LocaleKeys.offline_maps_download_btn), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                ),
              ] else ...[
                if (region.hasUpdate) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    ),
                    onPressed: onDownload,
                    icon: Icon(Icons.system_update_alt_rounded, size: 16.sp),
                    label: Text(tr(LocaleKeys.offline_maps_update_btn), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(width: 8.w),
                ],
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.googleRed,
                    side: const BorderSide(color: AppColors.googleRed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  ),
                  onPressed: () => _showDeleteConfirmDialog(context),
                  icon: Icon(Icons.delete_outline_rounded, size: 16.sp),
                  label: Text(tr(LocaleKeys.offline_maps_delete_btn), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    switch (region.status) {
      case RegionDownloadStatus.downloaded:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.googleGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 12.sp, color: AppColors.googleGreen),
              SizedBox(width: 4.w),
              Text(
                tr(LocaleKeys.offline_maps_downloaded),
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.googleGreen),
              ),
            ],
          ),
        );
      case RegionDownloadStatus.updateAvailable:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, size: 12.sp, color: Colors.orange),
              SizedBox(width: 4.w),
              Text(
                tr(LocaleKeys.offline_maps_update_available),
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.orange),
              ),
            ],
          ),
        );
      case RegionDownloadStatus.downloading:
      case RegionDownloadStatus.extracting:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.sMapTeal.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10.w,
                height: 10.h,
                child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.sMapTeal),
              ),
              SizedBox(width: 6.w),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: AppColors.sMapTeal),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
