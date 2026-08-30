import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:s_map/commons/styles/styles.dart';
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
          Navigator.of(ctx).pop(true);
          onAllow();
        },
        onSkip: () {
          Navigator.of(ctx).pop(false);
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
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onSkip();
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: colorScheme.surface,
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
                      color: colorScheme.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),

                    child: Icon(
                      Icons.battery_charging_full_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      LocaleKeys.routing_battery_dialog_title.tr(),
                      style: colorScheme.onSurface.textTheme.textTitleStyle.copyWith(
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _getDescription(),
                style: colorScheme.onSurfaceVariant.textTheme.regularStyle.copyWith(
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: colorScheme.outline.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        LocaleKeys.routing_battery_dialog_btn_skip.tr(),
                        style: colorScheme.onSurfaceVariant.textTheme.mediumStyle,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAllow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        LocaleKeys.routing_battery_dialog_btn_allow.tr(),
                        style: colorScheme.onPrimary.textTheme.textTitleStyle.copyWith(
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
      ),
    );
  }
}
