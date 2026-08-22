import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/route_profile_cubit/route_profile_state.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

class RouteProfileCubit extends Cubit<RouteProfileState> {
  final ITripRepository _repository;
  StreamSubscription<List<TripRecordModel>>? _watchSubscription;

  /// Optional global default repository resolver set during bootstrap
  static ITripRepository? defaultTripRepository;

  RouteProfileCubit({
    ITripRepository? repository,
  })  : _repository = repository ??
            defaultTripRepository ??
            (AppReposProvider.isInitialized
                ? AppReposProvider.instance.tripRepos
                : const NoOpTripRepository()),
        super(const RouteProfileState());

  @override
  void emit(RouteProfileState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Khởi tạo cubit: tính toán thống kê và bắt đầu theo dõi thay đổi realtime
  Future<void> init({
    bool autoWatch = true,
    String? initialProfileFilter,
  }) async {
    await loadStats(profileFilter: initialProfileFilter);
    if (isClosed) return;
    if (autoWatch) {
      await startWatching();
    }
  }

  /// Nạp danh sách chuyến đi và tính toán các chỉ số thống kê tổng hợp
  Future<void> loadStats({String? profileFilter, bool clearFilter = false}) async {
    final activeFilter = clearFilter ? null : (profileFilter ?? state.profileFilter);
    emit(state.copyWith(
      status: RouteProfileStatus.loading,
      profileFilter: activeFilter,
      clearProfileFilter: clearFilter,
      clearError: true,
    ));

    try {
      final trips = await _repository.getTrips();
      final filtered = activeFilter != null && activeFilter.isNotEmpty
          ? trips.where((t) => t.vehicleProfile == activeFilter).toList()
          : trips;

      final stats = TripStatsModel.fromTrips(filtered);

      emit(state.copyWith(
        status: RouteProfileStatus.success,
        stats: stats,
        allTrips: trips,
        filteredTrips: filtered,
        profileFilter: activeFilter,
        clearProfileFilter: activeFilter == null,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [RouteProfileCubit] Error calculating stats: $e');
      emit(state.copyWith(
        status: RouteProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Thay đổi bộ lọc theo vehicle profile (ví dụ: 'motorcycle', 'car', hoặc null/rỗng cho tất cả)
  void setProfileFilter(String? profileFilter) {
    final filter = profileFilter?.trim().isNotEmpty == true
        ? profileFilter!.trim()
        : null;

    final filtered = filter != null
        ? state.allTrips.where((t) => t.vehicleProfile == filter).toList()
        : state.allTrips;

    final stats = TripStatsModel.fromTrips(filtered);

    emit(state.copyWith(
      status: RouteProfileStatus.success,
      stats: stats,
      filteredTrips: filtered,
      profileFilter: filter,
      clearProfileFilter: filter == null,
      clearError: true,
    ));
  }

  /// Lắng nghe stream thay đổi từ Hive Box để cập nhật thống kê realtime
  Future<void> startWatching() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    if (isClosed) return;

    try {
      _watchSubscription = _repository.watchTrips().listen(
        (trips) {
          if (isClosed) return;
          final filter = state.profileFilter;
          final filtered = filter != null && filter.isNotEmpty
              ? trips.where((t) => t.vehicleProfile == filter).toList()
              : trips;
          final stats = TripStatsModel.fromTrips(filtered);

          emit(state.copyWith(
            status: RouteProfileStatus.success,
            stats: stats,
            allTrips: trips,
            filteredTrips: filtered,
            clearError: true,
          ));
        },
        onError: (e) {
          DLog.error('❌ [RouteProfileCubit] Error in watch stream: $e');
          if (isClosed) return;
          emit(state.copyWith(
            status: RouteProfileStatus.error,
            errorMessage: e.toString(),
          ));
        },
      );
    } catch (e) {
      DLog.error('❌ [RouteProfileCubit] Error starting watch stream: $e');
      if (isClosed) return;
      emit(state.copyWith(
        status: RouteProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    return super.close();
  }
}
