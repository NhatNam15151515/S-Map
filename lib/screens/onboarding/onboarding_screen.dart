import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/constants/app_asset.dart';
import 'package:s_map/routers/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  static const String path = AppRoutes.onboarding;

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with AppMixin {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding(BuildContext context) {
    context.read<AuthCubit>().completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadRegionCubit()..loadRegions(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.sMapTealGradientStart,
                AppColors.sMapTeal,
                AppColors.sMapDarkTeal,
              ],
            ),
          ),
          child: SafeArea(
            child: BlocConsumer<DownloadRegionCubit, DownloadRegionState>(
              listener: (context, state) {
                if (state.status == DownloadRegionStatus.downloading) {
                  // Jump to downloading page if not already there
                  if (_pageController.page?.round() == 1) {
                    _nextPage();
                  }
                } else if (state.isSuccess) {
                  // Jump to Ready page when done
                  if (_pageController.page?.round() == 2) {
                    _nextPage();
                  }
                } else if (state.isError) {
                  showError(tr(LocaleKeys.offline_maps_error));
                  // Go back to region picker if error during download
                  if (_pageController.page?.round() == 2) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                }
              },
              builder: (context, state) {
                return PageView(
                  controller: _pageController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Prevent manual swipe
                  children: [
                    _buildWelcomePage(),
                    _buildRegionPickerPage(context, state),
                    _buildDownloadingPage(state),
                    _buildReadyPage(context),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
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
              onPressed: _nextPage,
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

  Widget _buildRegionPickerPage(
      BuildContext context, DownloadRegionState state) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_region_title),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 24.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            tr(LocaleKeys.onboarding_region_subtitle),
            style: AppColors.white.textTheme.regularStyle
                .copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 24.h),
          Expanded(
            child: state.isLoading && state.regions.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.white))
                : ListView.separated(
                    itemCount: state.regions.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final region = state.regions[index];
                      // Hide already downloaded ones in onboarding (or just show them normally)
                      if (region.isDownloaded) {
                        return const SizedBox
                            .shrink(); // Ideally shouldn't happen on fresh install
                      }
                      return RegionCard(
                        region: region,
                        progress: state.getProgress(region.id),
                        isCurrentlyDownloading:
                            state.currentlyDownloadingRegionId == region.id,
                        onDownload: () {
                          context
                              .read<DownloadRegionCubit>()
                              .downloadRegion(region.id);
                        },
                        onDelete: () {}, // Not needed in onboarding
                        onCancel: () {
                          context
                              .read<DownloadRegionCubit>()
                              .cancelDownload(region.id);
                        },
                      );
                    },
                  ),
          ),
          SizedBox(height: 16.h),
          Center(
            child: TextButton(
              onPressed: () => _finishOnboarding(context),
              child: Text(
                tr(LocaleKeys.onboarding_skip_btn),
                style: AppColors.white.textTheme.semiBoldStyle.copyWith(
                  fontSize: 14.sp,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.white,
                ),
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildDownloadingPage(DownloadRegionState state) {
    final regionId = state.currentlyDownloadingRegionId;
    final region = state.regions.where((r) => r.id == regionId).firstOrNull;
    final progress = state.getProgress(regionId ?? '');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_download_rounded,
            size: 100,
            color: AppColors.white,
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_downloading_title),
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 24.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            region?.name ?? tr(LocaleKeys.onboarding_downloading_region_fallback),
            style: AppColors.white.textTheme.semiBoldStyle
                .copyWith(fontSize: 18.sp),
          ),
          SizedBox(height: 32.h),
          LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            backgroundColor: AppColors.white.withAlpha(50),
            color: AppColors.white,
            minHeight: 8.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
          SizedBox(height: 16.h),
          Text(
            "${(progress * 100).toStringAsFixed(1)}%",
            style:
                AppColors.white.textTheme.boldStyle.copyWith(fontSize: 16.sp),
          ),
          SizedBox(height: 24.h),
          TextButton(
            onPressed: () {
              if (regionId != null) {
                context.read<DownloadRegionCubit>().cancelDownload(regionId);
              }
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Text(
              tr(LocaleKeys.offline_maps_cancel_btn),
              style: AppColors.white.textTheme.semiBoldStyle.copyWith(
                fontSize: 14.sp,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyPage(BuildContext context) {
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
            child: const Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: AppColors.sMapTeal,
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            tr(LocaleKeys.onboarding_ready_title),
            style: AppColors.white.textTheme.boldStyle.copyWith(fontSize: 28.sp),
          ),
          SizedBox(height: 16.h),
          Text(
            tr(LocaleKeys.onboarding_ready_subtitle),
            style: AppColors.white.textTheme.regularStyle.copyWith(fontSize: 16.sp, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56.h,
            child: ElevatedButton(
              onPressed: () => _finishOnboarding(context),
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
                style: AppColors.sMapTeal.textTheme.boldStyle.copyWith(fontSize: 18.sp),
              ),
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}
