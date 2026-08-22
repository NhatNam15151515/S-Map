import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'trip_history_state.dart';

class TripHistoryCubit extends Cubit<TripHistoryState> {
  final ITripRepository _repository;
  StreamSubscription<List<TripRecordModel>>? _watchSubscription;

  /// Optional global default repository resolver set during bootstrap
  static ITripRepository? defaultTripRepository;

  TripHistoryCubit({
    ITripRepository? repository,
  })  : _repository = repository ??
            defaultTripRepository ??
            (AppReposProvider.isInitialized
                ? AppReposProvider.instance.tripRepos
                : const NoOpTripRepository()),
        super(const TripHistoryState());

  @override
  void emit(TripHistoryState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Khởi tạo cubit: tải danh sách ban đầu và đăng ký lắng nghe realtime
  Future<void> init({bool autoWatch = true}) async {
    await loadTrips();
    if (isClosed) return;
    if (autoWatch) {
      startWatching();
    }
  }

  /// Nạp toàn bộ lịch sử chuyến đi từ Local Storage
  Future<void> loadTrips() async {
    emit(state.copyWith(status: TripHistoryStatus.loading, clearError: true));
    try {
      final trips = await _repository.getTrips();
      emit(state.copyWith(
        status: TripHistoryStatus.success,
        trips: trips,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error loading trips: $e');
      emit(state.copyWith(
        status: TripHistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Lắng nghe stream thay đổi của Hive Box
  void startWatching() {
    _watchSubscription?.cancel();
    try {
      _watchSubscription = _repository.watchTrips().listen(
        (trips) {
          if (isClosed) return;
          emit(state.copyWith(
            status: TripHistoryStatus.success,
            trips: trips,
            clearError: true,
          ));
        },
        onError: (e) {
          DLog.error('❌ [TripHistoryCubit] Error in watch stream: $e');
          if (isClosed) return;
          emit(state.copyWith(
            status: TripHistoryStatus.error,
            errorMessage: e.toString(),
          ));
        },
      );
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error starting watch stream: $e');
      if (isClosed) return;
      emit(state.copyWith(
        status: TripHistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa một chuyến đi
  Future<void> deleteTrip(String id) async {
    try {
      await _repository.deleteTrip(id);
      final updatedList = state.trips.where((t) => t.id != id).toList();
      emit(state.copyWith(
        status: TripHistoryStatus.success,
        trips: updatedList,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error deleting trip $id: $e');
      emit(state.copyWith(
        status: TripHistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa toàn bộ lịch sử chuyến đi
  Future<void> clearAllTrips() async {
    try {
      await _repository.clearAllTrips();
      emit(state.copyWith(
        status: TripHistoryStatus.success,
        trips: const [],
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error clearing trips: $e');
      emit(state.copyWith(
        status: TripHistoryStatus.error,
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
