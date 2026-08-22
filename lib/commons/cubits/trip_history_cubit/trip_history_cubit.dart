import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/cubits/trip_history_cubit/trip_history_state.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';

class TripHistoryCubit extends Cubit<TripHistoryState> {
  final ITripRepository _repository;
  StreamSubscription<List<TripRecordModel>>? _watchSubscription;

  int _loadGeneration = 0;
  int _watchGeneration = 0;
  bool _isClosing = false;

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
    if (_isClosing || isClosed) return;
    super.emit(state);
  }

  /// Khởi tạo cubit: tải danh sách ban đầu và đăng ký lắng nghe realtime
  Future<void> init({bool autoWatch = true}) async {
    await loadTrips();
    if (_isClosing || isClosed) return;
    if (autoWatch) {
      await startWatching();
    }
  }

  /// Nạp toàn bộ lịch sử chuyến đi từ Local Storage
  Future<void> loadTrips() async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(status: TripHistoryStatus.loading, clearError: true));
    try {
      final trips = await _repository.getTrips();
      if (_isClosing || isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(
        status: TripHistoryStatus.success,
        trips: trips,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error loading trips: $e');
      if (_isClosing || isClosed || generation != _loadGeneration) return;
      emit(state.copyWith(
        status: TripHistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Lắng nghe stream thay đổi của Hive Box
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
          emit(state.copyWith(
            status: TripHistoryStatus.success,
            trips: trips,
            clearError: true,
          ));
        },
        onError: (e) {
          DLog.error('❌ [TripHistoryCubit] Error in watch stream: $e');
          if (_isClosing || isClosed || token != _watchGeneration) return;
          emit(state.copyWith(
            status: TripHistoryStatus.error,
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
      DLog.error('❌ [TripHistoryCubit] Error starting watch stream: $e');
      if (_isClosing || isClosed || token != _watchGeneration) return;
      emit(state.copyWith(
        status: TripHistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa một chuyến đi
  Future<void> deleteTrip(String id) async {
    _loadGeneration++;
    try {
      await _repository.deleteTrip(id);
      if (_isClosing || isClosed) return;
      final updatedList = state.trips.where((t) => t.id != id).toList();
      emit(state.copyWith(
        status: TripHistoryStatus.success,
        trips: updatedList,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error deleting trip $id: $e');
      if (_isClosing || isClosed) return;
      emit(state.copyWith(
        status: TripHistoryStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa toàn bộ lịch sử chuyến đi
  Future<void> clearAllTrips() async {
    _loadGeneration++;
    try {
      await _repository.clearAllTrips();
      if (_isClosing || isClosed) return;
      emit(state.copyWith(
        status: TripHistoryStatus.success,
        trips: const [],
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [TripHistoryCubit] Error clearing trips: $e');
      if (_isClosing || isClosed) return;
      emit(state.copyWith(
        status: TripHistoryStatus.error,
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
