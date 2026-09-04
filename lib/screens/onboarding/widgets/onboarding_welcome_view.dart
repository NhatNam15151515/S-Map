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

    return Column(
      children: [
        SizedBox(height: 12.h),
        // Logo bung to full màn hình, chiếm trọn phần không gian chủ đạo
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Center(
              child: AppAsset.logoOf(context).image.build(
                    fit: BoxFit.contain,
                  ),
            ),
          ),
        ),
        SizedBox(height: 20.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr(LocaleKeys.onboarding_welcome_title),
                style: colorScheme.onSurface.textTheme.boldStyle.copyWith(
                  fontSize: 26.sp,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.h),
              Text(
                tr(LocaleKeys.onboarding_welcome_subtitle),
                style:
                    colorScheme.onSurfaceVariant.textTheme.regularStyle.copyWith(
                  fontSize: 15.sp,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28.r),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    tr(LocaleKeys.onboarding_continue_btn),
                    style: colorScheme.onPrimary.textTheme.boldStyle.copyWith(
                      fontSize: 18.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 28.h),
            ],
          ),
        ),
      ],
    );
  }
}
