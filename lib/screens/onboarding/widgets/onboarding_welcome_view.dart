import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/constants/app_asset.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class OnboardingWelcomeView extends StatelessWidget {
  final VoidCallback onContinue;

  const OnboardingWelcomeView({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: AppAsset.logo.image.build(size: Size(100.w, 100.w)),
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_welcome_title),
            style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(fontSize: 28.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            tr(LocaleKeys.onboarding_welcome_subtitle),
            style: colorScheme.onPrimary.textTheme.regularStyle
                .copyWith(fontSize: 16.sp, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surface,
                foregroundColor: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
                elevation: 0,
              ),
              child: Text(
                tr(LocaleKeys.onboarding_continue_btn),
                style: colorScheme.primary.textTheme.boldStyle
                    .copyWith(fontSize: 18.sp),
              ),
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}
