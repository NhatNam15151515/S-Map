import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/generated/locale_keys.g.dart';

class OnboardingReadyView extends StatelessWidget {
  final VoidCallback onLetsGo;

  const OnboardingReadyView({
    super.key,
    required this.onLetsGo,
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
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 80.r,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_ready_title),
            style: colorScheme.onPrimary.textTheme.boldStyle
                .copyWith(fontSize: 28.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            tr(LocaleKeys.onboarding_ready_subtitle),
            style: colorScheme.onPrimary.textTheme.regularStyle
                .copyWith(fontSize: 16.sp, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          AppButton(
            text: tr(LocaleKeys.onboarding_lets_go_btn),
            height: 70.h,
            borderRadius: 28.r,
            backgroundColor: colorScheme.surface,
            textColor: colorScheme.primary,
            textStyle: colorScheme.primary.textTheme.boldStyle
                .copyWith(fontSize: 18.sp),
            onPressed: onLetsGo,
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}
