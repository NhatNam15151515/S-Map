import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class OnboardingReadyView extends StatelessWidget {
  final VoidCallback onLetsGo;

  const OnboardingReadyView({
    super.key,
    required this.onLetsGo,
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
            padding: EdgeInsets.all(24.r),
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 80.r,
              color: AppColors.sMapTeal,
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_ready_title),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 28.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            tr(LocaleKeys.onboarding_ready_subtitle),
            style: AppColors.white.textTheme.regularStyle
                .copyWith(fontSize: 16.sp, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: onLetsGo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.sMapTeal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28.r),
                ),
                elevation: 0,
              ),
              child: Text(
                tr(LocaleKeys.onboarding_lets_go_btn),
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
