import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/app_button.dart';

/// Reusable Dumb Widget hiển thị trạng thái và tiến độ tải tác vụ
/// (tải bản đồ offline, cập nhật dữ liệu, tải tài nguyên).
class DownloadProgressView extends StatelessWidget {
  final String? title;
  final String itemName;
  final double progress;
  final String progressText;
  final VoidCallback? onCancel;
  final String? cancelLabel;
  final IconData icon;
  final Color? foregroundColor;
  final Color? progressColor;
  final Color? progressBackgroundColor;

  const DownloadProgressView({
    super.key,
    this.title,
    required this.itemName,
    required this.progress,
    required this.progressText,
    this.onCancel,
    this.cancelLabel,
    this.icon = Icons.cloud_download_rounded,
    this.foregroundColor,
    this.progressColor,
    this.progressBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final resolvedColor = foregroundColor ?? colorScheme.onSurface;
    final resolvedProgressColor = progressColor ?? resolvedColor;
    final resolvedBgProgressColor = progressBackgroundColor ??
        resolvedProgressColor.withValues(alpha: 0.2);

    final safeProgress = (progress.isNaN || progress.isInfinite)
        ? 0.0
        : progress.clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100.r,
            color: resolvedColor,
          ),
          SizedBox(height: 32.h),
          if (title != null && title!.isNotEmpty) ...[
            Text(
              title!,
              style: resolvedColor.textTheme.boldStyle.copyWith(fontSize: 24.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
          ],
          Text(
            itemName,
            style: resolvedColor.textTheme.semiBoldStyle.copyWith(fontSize: 18.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          LinearProgressIndicator(
            value: safeProgress,
            backgroundColor: resolvedBgProgressColor,
            color: resolvedProgressColor,
            minHeight: 8.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
          SizedBox(height: 16.h),
          Text(
            progressText,
            style: resolvedColor.textTheme.boldStyle.copyWith(fontSize: 16.sp),
            textAlign: TextAlign.center,
          ),
          if (onCancel != null && cancelLabel != null) ...[
            SizedBox(height: 24.h),
            Center(
              child: AppButton.text(
                text: cancelLabel!,
                textColor: resolvedColor,
                textStyle: resolvedColor.textTheme.semiBoldStyle.copyWith(
                  fontSize: 14.sp,
                  decoration: TextDecoration.underline,
                  decorationColor: resolvedColor,
                ),
                onPressed: onCancel,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
