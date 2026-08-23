import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/trip_repository.dart';
import 'package:s_map/services/services.dart';
import 'route_profile_state.dart';

export 'route_profile_state.dart';

/// Cubit quản lý tính toán, lọc đa chiều và theo dõi số liệu thống kê hành trình
class RouteProfileCubit extends Cubit<RouteProfileState> {
  final ITripRepository _repository;
  StreamSubscription<List<TripRecordModel>>? _watchSubscription;
  int _loadGeneration = 0;
  int _watchGeneration = 0;
  bool _isClosing = false;

  RouteProfileCubit({ITripRepository? repository})
      : _repository = repository ??
            TripRepositoryImpl(
              tripService: TripServiceImpl.instance,
            ),
        super(const RouteProfileState());

  @override
  void emit(RouteProfileState state) {
    if (_isClosing || isClosed) return;
    super.emit(state);
  }

  /// Khởi tạo cubit: tính toán thống kê và bắt đầu theo dõi thay đổi realtime
  Future<void> init({
    bool autoWatch = true,
    String? initialProfileFilter,
    StatsTimeRange initialTimeRange = StatsTimeRange.thisWeek,
  }) async {
    await loadStats(
      profileFilter: initialProfileFilter,
      timeRange: initialTimeRange,
    );
    if (_isClosing || isClosed) return;
    if (autoWatch) {
      await startWatching();
    }
  }

  /// Kiểm tra phương tiện có khớp với bộ lọc hay không (chuẩn hóa moped_vn, motorcycle, moped, foot, walking)
  static bool _matchesProfile(String tripProfile, String filterProfile) {
    final tripLower = tripProfile.toLowerCase().trim();
    final filterLower = filterProfile.toLowerCase().trim();

    if (filterLower == 'motorcycle' || filterLower == 'moped' || filterLower == 'moped_vn') {
      return tripLower == 'motorcycle' || tripLower == 'moped' || tripLower == 'moped_vn';
    }
    if (filterLower == 'walking' || filterLower == 'foot') {
      return tripLower == 'walking' || tripLower == 'foot';
    }
    if (filterLower == 'car') {
      return tripLower == 'car';
    }
    return tripLower == filterLower;
  }

  /// Lọc danh sách chuyến đi theo vehicle profile
  static List<TripRecordModel> _filterByProfile(
    List<TripRecordModel> trips,
    String? profileFilter,
  ) {
    if (profileFilter == null || profileFilter.trim().isEmpty) return trips;
    return trips.where((t) => _matchesProfile(t.vehicleProfile, profileFilter)).toList();
  }

  /// Lọc danh sách chuyến đi theo vehicle profile và khoảng thời gian
  static List<TripRecordModel> _applyFilter(
    List<TripRecordModel> trips,
    String? profileFilter,
    StatsTimeRange timeRange,
  ) {
    final profileTrips = _filterByProfile(trips, profileFilter);
    return TripChartData.filterTripsByTimeRange(profileTrips, timeRange);
  }

  /// Nạp danh sách chuyến đi và tính toán các chỉ số thống kê tổng hợp + biểu đồ
  Future<void> loadStats({
    String? profileFilter,
    StatsTimeRange? timeRange,
    bool clearFilter = false,
  }) async {
    final generation = ++_loadGeneration;
    final activeProfileFilter = clearFilter ? null : (profileFilter ?? state.profileFilter);
    final activeTimeRange = timeRange ?? state.timeRange;

    emit(state.copyWith(
      status: RouteProfileStatus.loading,
      profileFilter: activeProfileFilter,
      timeRange: activeTimeRange,
      clearProfileFilter: clearFilter,
      clearError: true,
    ));

    try {
      final trips = await _repository.getTrips();
      if (_isClosing || isClosed || generation != _loadGeneration) return;

      final filtered = _applyFilter(trips, activeProfileFilter, activeTimeRange);
      final stats = TripStatsModel.fromTrips(filtered);

      final profileTrips = _filterByProfile(trips, activeProfileFilter);
      final chartData = TripChartData.fromTrips(profileTrips, activeTimeRange);

      emit(state.copyWith(
        status: RouteProfileStatus.success,
        stats: stats,
        chartData: chartData,
        allTrips: trips,
        filteredTrips: filtered,
        profileFilter: activeProfileFilter,
        timeRange: activeTimeRange,
        clearProfileFilter: activeProfileFilter == null,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [RouteProfileCubit] Error calculating stats: $e');
      if (_isClosing || isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(
        status: RouteProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Thay đổi bộ lọc theo vehicle profile (ví dụ: 'motorcycle', 'car', 'walking', hoặc null cho tất cả)
  void setProfileFilter(String? profileFilter) {
    _loadGeneration++;
    final filter = profileFilter?.trim().isNotEmpty == true
        ? profileFilter!.trim()
        : null;

    final filtered = _applyFilter(state.allTrips, filter, state.timeRange);
    final stats = TripStatsModel.fromTrips(filtered);

    final profileTrips = _filterByProfile(state.allTrips, filter);
    final chartData = TripChartData.fromTrips(profileTrips, state.timeRange);

    emit(state.copyWith(
      status: RouteProfileStatus.success,
      stats: stats,
      chartData: chartData,
      filteredTrips: filtered,
      profileFilter: filter,
      clearProfileFilter: filter == null,
      clearError: true,
    ));
  }

  /// Thay đổi khoảng thời gian thống kê (Hôm nay, Tuần này, Tháng này, Năm này, Tất cả)
  void setTimeRange(StatsTimeRange timeRange) {
    _loadGeneration++;
    final filtered = _applyFilter(state.allTrips, state.profileFilter, timeRange);
    final stats = TripStatsModel.fromTrips(filtered);

    final profileTrips = _filterByProfile(state.allTrips, state.profileFilter);
    final chartData = TripChartData.fromTrips(profileTrips, timeRange);

    emit(state.copyWith(
      status: RouteProfileStatus.success,
      stats: stats,
      chartData: chartData,
      filteredTrips: filtered,
      timeRange: timeRange,
      clearError: true,
    ));
  }

  /// Xóa một chuyến đi khỏi lịch sử
  Future<void> deleteTrip(String tripId) async {
    try {
      await _repository.deleteTrip(tripId);
    } catch (e) {
      DLog.error('❌ [RouteProfileCubit] Error deleting trip $tripId: $e');
      emit(state.copyWith(
        status: RouteProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa toàn bộ lịch sử chuyến đi
  Future<void> clearAllTrips() async {
    try {
      await _repository.clearAllTrips();
    } catch (e) {
      DLog.error('❌ [RouteProfileCubit] Error clearing all trips: $e');
      emit(state.copyWith(
        status: RouteProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Lắng nghe stream thay đổi từ Hive Box để cập nhật thống kê realtime
  Future<void> startWatching() async {
    final token = ++_watchGeneration;
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    if (_isClosing || isClosed || token != _watchGeneration) return;

    try {
      final sub = _repository.watchTrips().listen(
        (trips) {
          if (_isClosing || isClosed || token != _watchGeneration) return;
          _loadGeneration++;

          final filtered = _applyFilter(trips, state.profileFilter, state.timeRange);
          final stats = TripStatsModel.fromTrips(filtered);

          final profileTrips = _filterByProfile(trips, state.profileFilter);
          final chartData = TripChartData.fromTrips(profileTrips, state.timeRange);

          emit(state.copyWith(
            status: RouteProfileStatus.success,
            stats: stats,
            chartData: chartData,
            allTrips: trips,
            filteredTrips: filtered,
            clearError: true,
          ));
        },
        onError: (e) {
          DLog.error('❌ [RouteProfileCubit] Error in watch stream: $e');
          if (_isClosing || isClosed || token != _watchGeneration) return;
          emit(state.copyWith(
            status: RouteProfileStatus.error,
            errorMessage: e.toString(),
          ));
        },
      );

      if (_isClosing || isClosed || token != _watchGeneration) {
        await sub.cancel();
      } else {
        _watchSubscription = sub;
      }
    } catch (e) {
      DLog.error('❌ [RouteProfileCubit] Error starting watch stream: $e');
      if (_isClosing || isClosed || token != _watchGeneration) return;
      emit(state.copyWith(
        status: RouteProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    _loadGeneration++;
    _watchGeneration++;
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    return super.close();
  }
}
