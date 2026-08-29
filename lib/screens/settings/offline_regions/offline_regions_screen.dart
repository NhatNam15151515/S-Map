import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'widgets/offline_storage_summary_card.dart';

class OfflineRegionsScreen extends StatefulWidget {
  const OfflineRegionsScreen({super.key});

  @override
  State<OfflineRegionsScreen> createState() => _OfflineRegionsScreenState();
}

class _OfflineRegionsScreenState extends State<OfflineRegionsScreen>
    with AppMixin {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DownloadRegionCubit()..loadRegions(),
      child: const _OfflineRegionsContent(),
    );
  }
}

class _OfflineRegionsContent extends StatelessWidget with AppMixin {
  const _OfflineRegionsContent();

  void _handleMessage(BuildContext context, DownloadRegionState state) {
    if (state.isSuccess && state.successMessage != null) {
      if (state.successMessage == 'DOWNLOAD_SUCCESS') {
        showSuccess(tr(LocaleKeys.offline_maps_download_success));
      } else if (state.successMessage == 'DELETE_SUCCESS') {
        showSuccess(tr(LocaleKeys.offline_maps_delete_success));
      } else {
        showSuccess(state.successMessage!);
      }
    } else if (state.isError && state.errorMessage != null) {
      showError(tr(LocaleKeys.offline_maps_error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocConsumer<DownloadRegionCubit, DownloadRegionState>(
      listener: _handleMessage,
      builder: (context, state) {
        return Scaffold(
          appBar: TitleBackAppBar(
            title: tr(LocaleKeys.offline_maps_title),
            trailingWidgets: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: tr(LocaleKeys.offline_maps_check_updates),
              onPressed: state.isLoading
                  ? null
                  : () {
                      context.read<DownloadRegionCubit>().checkForUpdates();
                    },
            ),
          ),
          body: state.isLoading && state.regions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () =>
                      context.read<DownloadRegionCubit>().loadRegions(),
                  color: context.colorScheme.primary,
                  child: ListView(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    children: [
                      // Header Card: Storage summary
                      OfflineStorageSummaryCard(
                        state: state,
                        onCheckUpdates: () {
                          context.read<DownloadRegionCubit>().checkForUpdates();
                        },
                      ),

                      SizedBox(height: 20.h),

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr(LocaleKeys.offline_maps_available_regions),
                            style: colorScheme.onSurface.textTheme.boldStyle
                                .copyWith(fontSize: 16.sp),
                          ),
                          Text(
                            '${state.downloadedRegionsCount}/${state.regions.length}',
                            style: colorScheme.primary.textTheme.semiBoldStyle
                                .copyWith(fontSize: 14.sp),
                          ),
                        ],
                      ),

                      SizedBox(height: 12.h),

                      // Danh sách các vùng
                      ...state.regions.map((region) {
                        final isCurrentlyDownloading =
                            state.currentlyDownloadingRegionId == region.id;
                        final progress = state.getProgress(region.id);

                        return RegionCard(
                          key: ValueKey(region.id),
                          region: region,
                          progress: progress,
                          isCurrentlyDownloading: isCurrentlyDownloading,
                          onDownload: () {
                            context
                                .read<DownloadRegionCubit>()
                                .downloadRegion(region.id);
                          },
                          onDelete: () {
                            context
                                .read<DownloadRegionCubit>()
                                .deleteRegion(region.id);
                          },
                          onCancel: () {
                            context
                                .read<DownloadRegionCubit>()
                                .cancelDownload(region.id);
                          },
                        );
                      }),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
