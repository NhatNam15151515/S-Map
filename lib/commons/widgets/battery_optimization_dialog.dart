import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';
import 'package:s_map/models/models.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  final DeviceOemType oemType;
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  const BatteryOptimizationDialog({
    super.key,
    required this.oemType,
    required this.onAllow,
    required this.onSkip,
  });

  static Future<bool?> show(
    BuildContext context, {
    required DeviceOemType oemType,
    required VoidCallback onAllow,
    required VoidCallback onSkip,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BatteryOptimizationDialog(
        oemType: oemType,
        onAllow: () {
          ctx.pop(true);
          onAllow();
        },
        onSkip: () {
          ctx.pop(false);
          onSkip();
        },
      ),
    );
  }

  String _getDescription() {
    if (oemType.isSamsung) {
      return LocaleKeys.routing_battery_dialog_desc_samsung.tr();
    }
    if (oemType.isXiaomi) {
      return LocaleKeys.routing_battery_dialog_desc_xiaomi.tr();
    }
    return LocaleKeys.routing_battery_dialog_desc_general.tr();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.navDarkSurface : AppColors.white;
    final primaryTextColor =
        isDark ? AppColors.white : AppColors.googleDarkText;
    final secondaryTextColor =
        isDark ? AppColors.tangledWeb : AppColors.googleGreyText;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: backgroundColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.sMapTeal.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.battery_charging_full_rounded,
                    color: AppColors.sMapTeal,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LocaleKeys.routing_battery_dialog_title.tr(),
                    style: primaryTextColor.textTheme.textTitleStyle.copyWith(
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _getDescription(),
              style: secondaryTextColor.textTheme.regularStyle.copyWith(
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: style.outlineButtonStyle.copyWith(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 12),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    child: Text(
                      LocaleKeys.routing_battery_dialog_btn_skip.tr(),
                      style: secondaryTextColor.textTheme.mediumStyle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAllow,
                    style: style.buttonStyle.copyWith(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 12),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    child: Text(
                      LocaleKeys.routing_battery_dialog_btn_allow.tr(),
                      style: AppColors.white.textTheme.textTitleStyle.copyWith(
                        fontSize: 14,
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
}
