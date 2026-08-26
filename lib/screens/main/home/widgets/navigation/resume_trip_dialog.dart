import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

/// Dialog hỏi người dùng có muốn tiếp tục chuyến đi chưa hoàn tất (Resume Trip)
class ResumeTripDialog extends StatelessWidget {
  final ActiveTripSnapshot snapshot;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  const ResumeTripDialog({
    super.key,
    required this.snapshot,
    required this.onResume,
    required this.onDiscard,
  });

  /// Hiển thị ResumeTripDialog dạng Modal Dialog
  static Future<bool?> show(
    BuildContext context, {
    required ActiveTripSnapshot snapshot,
    required VoidCallback onResume,
    required VoidCallback onDiscard,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ResumeTripDialog(
        snapshot: snapshot,
        onResume: () {
          dialogContext.pop(true);
          onResume();
        },
        onDiscard: () {
          dialogContext.pop(false);
          onDiscard();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final destName = snapshot.destinationName?.trim().isNotEmpty == true
        ? snapshot.destinationName!
        : null;

    final description = destName != null
        ? tr(LocaleKeys.routing_resume_trip_desc, args: [destName])
        : tr(LocaleKeys.routing_resume_trip_desc_unnamed);

    final distanceStr =
        RouteFormatHelper.formatDistance(snapshot.totalDistanceTraveledMeters);
    final timePassed = DateTime.now().difference(snapshot.tripStartTime);
    final durationStr = RouteFormatHelper.formatTripDuration(timePassed);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Header
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.bleuDeFrance.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restore_rounded,
                  color: AppColors.bleuDeFrance,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              tr(LocaleKeys.routing_resume_trip_title),
              textAlign: TextAlign.center,
              style: style.blackTextColor.textTheme.boldStyle.copyWith(
                fontSize: 20,
                color: AppColors.googleDarkText,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              description,
              textAlign: TextAlign.center,
              style: style.blackTextColor.textTheme.regularStyle.copyWith(
                fontSize: 14,
                color: AppColors.googleGreyText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Stats Preview Box (nếu đã di chuyển hoặc có thời gian)
            if (snapshot.totalDistanceTraveledMeters > 0 || timePassed.inSeconds > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.outlineVariant, width: 0.8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      icon: Icons.straighten_rounded,
                      label: tr(LocaleKeys.routing_trip_distance),
                      value: distanceStr,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: AppColors.outlineVariant,
                    ),
                    _buildStatItem(
                      context,
                      icon: Icons.timer_outlined,
                      label: tr(LocaleKeys.routing_trip_duration),
                      value: durationStr,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDiscard,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      tr(LocaleKeys.routing_discard_btn),
                      style: style.blackTextColor.textTheme.mediumStyle.copyWith(
                        fontSize: 15,
                        color: AppColors.googleGreyText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onResume,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bleuDeFrance,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      tr(LocaleKeys.routing_resume_btn),
                      style: style.blackTextColor.textTheme.boldStyle.copyWith(
                        fontSize: 15,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final style = AppStyle.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.bleuDeFrance),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: style.blackTextColor.textTheme.regularStyle.copyWith(
                fontSize: 11,
                color: AppColors.googleGreyText,
              ),
            ),
            Text(
              value,
              style: style.blackTextColor.textTheme.boldStyle.copyWith(
                fontSize: 13,
                color: AppColors.googleDarkText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
