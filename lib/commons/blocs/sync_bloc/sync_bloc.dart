import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/transformers/transformers.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/repos/repos.dart';
import 'sync_event.dart';
import 'sync_state.dart';

export 'sync_event.dart';
export 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final ISyncRepository _syncRepository;
  final IFirebaseAuthService _authService;
  final IAuthRepos _authRepos;
  StreamSubscription<int>? _queueSubscription;

  SyncBloc({
    ISyncRepository? syncRepository,
    IFirebaseAuthService? authService,
    IAuthRepos? authRepos,
  })  : _syncRepository = syncRepository ??
            (AppReposProvider.isInitialized
                ? AppReposProvider.instance.syncRepos
                : const NoOpSyncRepository()),
        _authService = authService ?? const NoOpFirebaseAuthService(),
        _authRepos = authRepos ??
            (AppReposProvider.isInitialized
                ? AppReposProvider.instance.authRepos
                : const NoOpAuthRepos()),
        super(const SyncState()) {
    on<SyncStarted>(_onSyncStarted, transformer: droppable());
    on<SyncTripQueued>(_onSyncTripQueued);
    on<SyncQueueCountChanged>(_onSyncQueueCountChanged);
    on<SyncReset>(_onSyncReset);

    _initQueueWatcher();
  }

  void _initQueueWatcher() {
    _queueSubscription = _syncRepository.watchPendingSyncCount().listen((count) {
      if (!isClosed) {
        add(SyncQueueCountChanged(count));
      }
    }, onError: (e) {
      DLog.error('❌ [SyncBloc] Lỗi theo dõi stream queue count: $e');
    });
  }


  Future<void> _onSyncStarted(
    SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    try {
      final currentCount = await _syncRepository.getPendingSyncCount();
      if (isClosed || emit.isDone) return;

      if (currentCount == 0) {
        emit(state.copyWith(
          status: SyncStatus.success,
          pendingCount: 0,
          lastSyncedAt: DateTime.now(),
          syncedTripIds: const [],
          clearError: true,
        ));
        return;
      }

      emit(state.copyWith(
        status: SyncStatus.syncing,
        pendingCount: currentCount,
        clearError: true,
      ));

      // 1. Xác định User ID (nếu chưa đăng nhập thì tự động đăng nhập ẩn danh)
      String? userId = event.userId ?? _authService.currentUser?.uid;
      if (userId == null || userId.trim().isEmpty) {
        final anonUser = await _authRepos.signInAnonymously();
        if (isClosed || emit.isDone) return;
        userId = anonUser?.id;
      }

      if (userId == null || userId.trim().isEmpty) {
        throw StateError('Không thể xác thực danh tính người dùng để đồng bộ');
      }

      // 2. Thực hiện đồng bộ toàn bộ chuyến đi đang tồn trong offline queue
      final syncedIds = await _syncRepository.syncPendingTrips(userId);
      if (isClosed || emit.isDone) return;

      int remainingCount = state.pendingCount;
      try {
        remainingCount = await _syncRepository.getPendingSyncCount();
      } catch (e) {
        DLog.warning('⚠️ [SyncBloc] Không thể đọc queue sau đồng bộ: $e');
      }
      if (isClosed || emit.isDone) return;

      emit(state.copyWith(
        status: SyncStatus.success,
        pendingCount: remainingCount,
        lastSyncedAt: DateTime.now(),
        syncedTripIds: syncedIds,
      ));
    } catch (e) {
      DLog.error('❌ [SyncBloc] Đồng bộ thất bại: $e');
      int fallbackPending = state.pendingCount;
      try {
        fallbackPending = await _syncRepository.getPendingSyncCount();
      } catch (_) {
        // Fallback to state.pendingCount
      }
      if (!isClosed && !emit.isDone) {
        emit(state.copyWith(
          status: SyncStatus.failure,
          errorMessage: e.toString(),
          pendingCount: fallbackPending,
        ));
      }
    }
  }

  Future<void> _onSyncTripQueued(
    SyncTripQueued event,
    Emitter<SyncState> emit,
  ) async {
    try {
      await _syncRepository.enqueueTripForSync(event.tripId);
      if (isClosed || emit.isDone) return;
      final count = await _syncRepository.getPendingSyncCount();
      if (!isClosed && !emit.isDone) {
        emit(state.copyWith(pendingCount: count));
      }
    } catch (e) {
      DLog.error('❌ [SyncBloc] Lỗi enqueue trip: $e');
    }
  }

  void _onSyncQueueCountChanged(
    SyncQueueCountChanged event,
    Emitter<SyncState> emit,
  ) {
    if (!isClosed && !emit.isDone) {
      emit(state.copyWith(pendingCount: event.count));
    }
  }

  void _onSyncReset(
    SyncReset event,
    Emitter<SyncState> emit,
  ) {
    if (!isClosed && !emit.isDone) {
      emit(const SyncState());
    }
  }

  @override
  Future<void> close() {
    _queueSubscription?.cancel();
    return super.close();
  }
}
