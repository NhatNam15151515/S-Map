import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'saved_routes_fallbacks.dart';
import 'saved_routes_state.dart';

class SavedRoutesCubit extends Cubit<SavedRoutesState> {
  final ICustomRouteRepository _repository;
  StreamSubscription<List<CustomRouteModel>>? _watchSubscription;

  /// Optional global default repository resolver set during bootstrap
  static ICustomRouteRepository? defaultCustomRouteRepository;

  SavedRoutesCubit({
    ICustomRouteRepository? customRouteRepository,
    bool autoInit = true,
    bool autoWatch = true,
  })  : _repository = customRouteRepository ??
            defaultCustomRouteRepository ??
            (AppReposProvider.isInitialized
                ? AppReposProvider.instance.customRouteRepos
                : const NoOpCustomRouteRepository()),
        super(const SavedRoutesState()) {
    if (autoInit) {
      init(autoWatch: autoWatch);
    }
  }

  /// Khởi tạo tải danh sách lộ trình và đăng ký stream watcher
  Future<void> init({bool autoWatch = true}) async {
    await loadSavedRoutes();
    if (isClosed) return;
    if (autoWatch) {
      startWatching();
    }
  }

  @override
  void emit(SavedRoutesState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Tải danh sách lộ trình đã lưu
  Future<void> loadSavedRoutes() async {
    emit(state.copyWith(status: SavedRoutesStatus.loading, clearError: true));
    try {
      final routes = await _repository.getSavedRoutes();
      emit(state.copyWith(
        status: SavedRoutesStatus.success,
        routes: routes,
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [SavedRoutesCubit] Error loading saved routes: $e');
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Lắng nghe stream thay đổi của Hive Box
  void startWatching() {
    _watchSubscription?.cancel();
    try {
      _watchSubscription = _repository.watchSavedRoutes().listen(
        (routes) {
          if (isClosed) return;
          emit(state.copyWith(
            status: SavedRoutesStatus.success,
            routes: routes,
            clearError: true,
          ));
        },
        onError: (e) {
          DLog.error('❌ [SavedRoutesCubit] Error in watch stream: $e');
          if (isClosed) return;
          emit(state.copyWith(
            status: SavedRoutesStatus.error,
            errorMessage: e.toString(),
          ));
        },
      );
    } catch (e) {
      DLog.error('❌ [SavedRoutesCubit] Error starting watch stream: $e');
      if (isClosed) return;
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa một lộ trình đã lưu
  Future<void> deleteRoute(String id) async {
    try {
      await _repository.deleteRoute(id);
      await loadSavedRoutes();
    } catch (e) {
      DLog.error('❌ [SavedRoutesCubit] Error deleting route $id: $e');
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Xóa tất cả các lộ trình đã lưu
  Future<void> clearAllRoutes() async {
    try {
      await _repository.clearAllRoutes();
      emit(state.copyWith(
        status: SavedRoutesStatus.success,
        routes: const [],
        clearError: true,
      ));
    } catch (e) {
      DLog.error('❌ [SavedRoutesCubit] Error clearing all routes: $e');
      emit(state.copyWith(
        status: SavedRoutesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  @override
  Future<void> close() async {
    await _watchSubscription?.cancel();
    return super.close();
  }
}
