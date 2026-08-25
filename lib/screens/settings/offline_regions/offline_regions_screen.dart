import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/mixin/mixin.dart';
import 'package:s_map/commons/styles/styles.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/widgets/widgets.dart';
import 'package:s_map/routers/app_routes.dart';
import 'package:s_map/screens/settings/offline_regions/widgets/region_card.dart';

class OfflineRegionsScreen extends StatefulWidget {
  static const String path = AppRoutes.offlineRegions;

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
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.sMapTeal))
              : RefreshIndicator(
                  onRefresh: () =>
                      context.read<DownloadRegionCubit>().loadRegions(),
                  color: AppColors.sMapTeal,
                  child: ListView(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    children: [
                      // Header Card: Tổng dung lượng bộ nhớ & thống kê
                      _buildStorageSummaryCard(context, state),

                      SizedBox(height: 20.h),

                      // Section Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr(LocaleKeys.offline_maps_available_regions),
                            style: AppColors.googleDarkText.textTheme.boldStyle
                                .copyWith(fontSize: 16.sp),
                          ),
                          Text(
                            '${state.downloadedRegionsCount}/${state.regions.length}',
                            style: AppColors.sMapTeal.textTheme.semiBoldStyle
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

  Widget _buildStorageSummaryCard(
    BuildContext context,
    DownloadRegionState state,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.sMapTeal,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(
            color: AppColors.blackOpa25,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: const BoxDecoration(
              color: AppColors.sMapLightTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_download_outlined,
              color: AppColors.sMapDarkTeal,
              size: 26.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(LocaleKeys.offline_maps_storage_used),
                  style: AppColors.white.textTheme.mediumStyle
                      .copyWith(fontSize: 13.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  state.formattedTotalStorage,
                  style: AppColors.white.textTheme.boldStyle
                      .copyWith(fontSize: 20.sp),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.white),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            ),
            onPressed: () {
              context.read<DownloadRegionCubit>().checkForUpdates();
            },
            child: Text(
              tr(LocaleKeys.offline_maps_check_updates),
              style: AppColors.white.textTheme.semiBoldStyle
                  .copyWith(fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }
}
