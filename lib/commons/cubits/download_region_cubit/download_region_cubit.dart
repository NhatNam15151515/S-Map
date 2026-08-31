import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/services/map_style_service.dart';
import 'download_region_state.dart';

export 'download_region_state.dart';

class DownloadRegionCubit extends Cubit<DownloadRegionState> {
  final IRegionRepository _repository;
  final IMapStyleService _mapStyleService;
  StreamSubscription<Map<String, double>>? _progressSubscription;

  DownloadRegionCubit({
    IRegionRepository? repository,
    IMapStyleService? mapStyleService,
  })
      : _repository = repository ?? RegionRepositoryImpl.instance,
        _mapStyleService = mapStyleService ?? MapStyleService.instance,
        super(const DownloadRegionState()) {
    _initProgressSubscription();
  }

  void _initProgressSubscription() {
    _progressSubscription = _repository.downloadProgressStream.listen(
      (progressMap) {
        if (isClosed) return;
        emit(state.copyWith(
          progressMap: progressMap,
        ));
      },
      onError: (e) {
        DLog.error('❌ [DownloadRegionCubit] Error in downloadProgressStream: $e');
      },
    );
  }

  @override
  void emit(DownloadRegionState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> loadRegions() async {
    emit(state.copyWith(
      status: DownloadRegionStatus.loading,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      final regions = await _repository.getRegions();
      final storageBytes = await _repository.getTotalStorageUsage();

      emit(state.copyWith(
        status: DownloadRegionStatus.loaded,
        regions: regions,
        totalStorageBytes: storageBytes,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [DownloadRegionCubit] Lỗi tải danh sách vùng: $e');
      emit(state.copyWith(
        status: DownloadRegionStatus.error,
        errorMessage: 'FETCH_REGIONS_ERROR',
      ));
    }
  }

  Future<void> downloadRegion(String regionId) async {
    if (state.currentlyDownloadingRegionId != null) {
      DLog.warning('⚠️ [DownloadRegionCubit] Đang có vùng khác đang tải xuống: ${state.currentlyDownloadingRegionId}');
      return;
    }

    emit(state.copyWith(
      status: DownloadRegionStatus.downloading,
      currentlyDownloadingRegionId: regionId,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      await _repository.downloadRegion(regionId);
      // Refresh the map facade before the success state is emitted. If Home
      // is still alive behind this settings route, its MapDisplayCubit will
      // receive the style change and swap to the local PMTiles source.
      await _refreshMapStyleSafely();
      final updatedRegions = await _repository.getRegions();
      final updatedStorage = await _repository.getTotalStorageUsage();

      emit(state.copyWith(
        status: DownloadRegionStatus.success,
        regions: updatedRegions,
        totalStorageBytes: updatedStorage,
        clearDownloadingRegion: true,
        successMessage: DownloadRegionMessages.downloadSuccess,
      ));
    } on DownloadCancelledException {
      DLog.info('ℹ️ [DownloadRegionCubit] Tải vùng $regionId đã bị hủy');
      final updatedRegions = await _repository.getRegions().catchError((_) => state.regions);
      emit(state.copyWith(
        status: DownloadRegionStatus.loaded,
        regions: updatedRegions,
        clearDownloadingRegion: true,
      ));
    } catch (e) {
      if (e is DownloadCancelledException ||
          e.toString().contains('DOWNLOAD_CANCELLED') ||
          e.toString().contains('cancelled') ||
          e.toString().contains('hủy')) {
        final updatedRegions = await _repository.getRegions().catchError((_) => state.regions);
        emit(state.copyWith(
          status: DownloadRegionStatus.loaded,
          regions: updatedRegions,
          clearDownloadingRegion: true,
        ));
        return;
      }
      DLog.error('❌ [DownloadRegionCubit] Lỗi tải vùng $regionId: $e');
      final updatedRegions = await _repository.getRegions().catchError((_) => state.regions);
      emit(state.copyWith(
        status: DownloadRegionStatus.error,
        regions: updatedRegions,
        errorMessage: DownloadRegionMessages.downloadError,
        clearDownloadingRegion: true,
      ));
    }
  }

  Future<void> deleteRegion(String regionId) async {
    emit(state.copyWith(
      status: DownloadRegionStatus.loading,
      clearError: true,
      clearSuccess: true,
    ));

    try {
      await _repository.deleteRegion(regionId);
      await _refreshMapStyleSafely();
      final updatedRegions = await _repository.getRegions();
      final updatedStorage = await _repository.getTotalStorageUsage();

      emit(state.copyWith(
        status: DownloadRegionStatus.loaded,
        regions: updatedRegions,
        totalStorageBytes: updatedStorage,
        clearSuccess: true,
        successMessage: DownloadRegionMessages.deleteSuccess,
      ));
    } catch (e) {
      DLog.error('❌ [DownloadRegionCubit] Lỗi xóa vùng $regionId: $e');
      emit(state.copyWith(
        status: DownloadRegionStatus.error,
        errorMessage: DownloadRegionMessages.deleteError,
      ));
    }
  }

  Future<void> checkForUpdates() async {
    emit(state.copyWith(
      status: DownloadRegionStatus.loading,
      clearError: true,
    ));

    try {
      final updatedRegions = await _repository.checkForUpdates();
      emit(state.copyWith(
        status: DownloadRegionStatus.loaded,
        regions: updatedRegions,
      ));
    } catch (e) {
      DLog.error('❌ [DownloadRegionCubit] Lỗi kiểm tra cập nhật: $e');
      emit(state.copyWith(
        status: DownloadRegionStatus.error,
        errorMessage: 'UPDATE_CHECK_ERROR',
      ));
    }
  }

  Future<void> cancelDownload(String regionId) async {
    try {
      await _repository.cancelDownload(regionId);
      final updatedRegions = await _repository.getRegions();
      emit(state.copyWith(
        status: DownloadRegionStatus.loaded,
        regions: updatedRegions,
        clearDownloadingRegion: true,
      ));
    } catch (e) {
      DLog.error('❌ [DownloadRegionCubit] Lỗi hủy tải vùng $regionId: $e');
    }
  }

  Future<void> _refreshMapStyleSafely() async {
    try {
      await _mapStyleService.refreshOfflineMap();
    } catch (error) {
      // Download/delete remains successful even if a map view is not mounted
      // or a desktop test target has no native MapLibre channel.
      DLog.warning(
          '⚠️ [DownloadRegionCubit] Không làm mới được style offline: $error');
    }
  }

  @override
  Future<void> close() {
    _progressSubscription?.cancel();
    return super.close();
  }
}
