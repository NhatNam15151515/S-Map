import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/app_colors.dart';

class AppBottomSheetUtil {
  static Future<T?> showModalBottom<T>({
    required BuildContext context,
    required Widget child,
    required String title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: bottomSheetContainer(
            title,
            AppStyle.of(context),
            context,
            child,
          ),
        );
      },
    );
  }

  static Widget bottomSheetContainer(
    String title,
    AppStyle styles,
    BuildContext context,
    Widget child,
  ) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height / 1.5,
      ),
      decoration: BoxDecoration(
        color: styles.whiteTextColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style:
                        styles.blackTextColor.textTheme.subTitleStyle.copyWith(
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    ),
                    onPressed: () => context.pop(),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(child: child),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
