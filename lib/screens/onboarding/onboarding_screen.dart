import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/commons/mixin/mixin.dart';
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
    if (!mounted || !_pageController.hasClients) return;
    setState(() {
      _currentPageIndex = page;
    });
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    _goToPage(_currentPageIndex + 1);
  }

  void _finishOnboarding(BuildContext context) {
    final cubit = context.read<DownloadRegionCubit>();
    final downloadingId = cubit.state.currentlyDownloadingRegionId;
    if (downloadingId != null) {
      cubit.cancelDownload(downloadingId);
    }
    authCubit.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadRegionCubit()..loadRegions(),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentPageIndex > 0) {
            _goToPage(_currentPageIndex - 1);
          }
        },
        child: Scaffold(
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: _currentPageIndex == 0
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary,
                      ],
                    ),
              color: _currentPageIndex == 0
                  ? Theme.of(context).colorScheme.surface
                  : null,
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
                    if (_currentPageIndex != OnboardingStep.downloading.index) {
                      _goToPage(OnboardingStep.downloading.index);
                    }
                  } else if (state.isSuccess &&
                      state.successMessage ==
                          DownloadRegionMessages.downloadSuccess) {
                    // Navigate directly to Ready view (index 3)
                    if (_currentPageIndex != OnboardingStep.ready.index) {
                      _goToPage(OnboardingStep.ready.index);
                    }
                  } else if (state.status == DownloadRegionStatus.loaded &&
                      state.currentlyDownloadingRegionId == null) {
                    // Go back to region picker (index 1) if cancelled/loaded
                    if (_currentPageIndex == OnboardingStep.downloading.index) {
                      _goToPage(OnboardingStep.regionPicker.index);
                    }
                  } else if (state.isError) {
                    showError(tr(LocaleKeys.offline_maps_error));
                    // Go back to region picker (index 1) on error
                    if (_currentPageIndex !=
                        OnboardingStep.regionPicker.index) {
                      _goToPage(OnboardingStep.regionPicker.index);
                    }
                  }
                },
                builder: (context, state) {
                  return PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      if (_currentPageIndex != index) {
                        setState(() => _currentPageIndex = index);
                      }
                    },
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
      ),
    );
  }
}
