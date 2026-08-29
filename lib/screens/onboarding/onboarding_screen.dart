import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/onboarding/widgets/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  static const String path = AppRoutes.onboarding;

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with AppMixin {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (!mounted) return;
    _currentPageIndex = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          page,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _nextPage() {
    _goToPage(_currentPageIndex + 1);
  }

  Future<void> _finishOnboarding(BuildContext context) async {
    final cubit = context.read<DownloadRegionCubit>();
    final downloadingId = cubit.state.currentlyDownloadingRegionId;
    if (downloadingId != null) {
      await cubit.cancelDownload(downloadingId);
    }
    if (!context.mounted) return;
    await context.read<AuthCubit>().completeOnboarding();
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
              listenWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.currentlyDownloadingRegionId !=
                      current.currentlyDownloadingRegionId,
              listener: (context, state) {
                if (state.status == DownloadRegionStatus.downloading &&
                    state.currentlyDownloadingRegionId != null) {
                  // Navigate directly to downloading view (index 2)
                  if (_currentPageIndex != 2) _goToPage(2);
                } else if (state.isSuccess &&
                    state.successMessage ==
                        DownloadRegionMessages.downloadSuccess) {
                  // Navigate directly to Ready view (index 3)
                  if (_currentPageIndex != 3) _goToPage(3);
                } else if (state.isError) {
                  showError(tr(LocaleKeys.offline_maps_error));
                  // Go back to region picker (index 1) on error
                  if (_currentPageIndex != 1) _goToPage(1);
                }
              },
              builder: (context, state) {
                return PageView(
                  controller: _pageController,
                  onPageChanged: (index) => _currentPageIndex = index,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    OnboardingWelcomeView(
                      onContinue: _nextPage,
                    ),
                    OnboardingRegionPickerView(
                      state: state,
                      onSkip: () => _finishOnboarding(context),
                      onRetry: () =>
                          context.read<DownloadRegionCubit>().loadRegions(),
                      onDownload: (regionId) => context
                          .read<DownloadRegionCubit>()
                          .downloadRegion(regionId),
                      onDelete: (regionId) => context
                          .read<DownloadRegionCubit>()
                          .deleteRegion(regionId),
                      onCancel: (regionId) => context
                          .read<DownloadRegionCubit>()
                          .cancelDownload(regionId),
                    ),
                    OnboardingDownloadingView(
                      state: state,
                      onCancel: () {
                        final regionId = state.currentlyDownloadingRegionId;
                        if (regionId != null) {
                          context
                              .read<DownloadRegionCubit>()
                              .cancelDownload(regionId);
                        }
                        _goToPage(1);
                      },
                    ),
                    OnboardingReadyView(
                      onLetsGo: () => _finishOnboarding(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
