import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.blackOpa25,
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: AppAsset.logo.image.build(size: Size(100.w, 100.w)),
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_welcome_title),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 28.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Text(
            tr(LocaleKeys.onboarding_welcome_subtitle),
            style: AppColors.white.textTheme.regularStyle
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
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.sMapTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
                elevation: 0,
              ),
              child: Text(
                tr(LocaleKeys.onboarding_continue_btn),
                style: AppColors.sMapTeal.textTheme.boldStyle
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
