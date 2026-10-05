import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/models/models.dart';
import 'generic_list_cubit_state.dart';

typedef GenericListCubitInputFuture<T> = Future<List<T>> Function(
    int page, int limit);

class GenericListCubit<T> extends Cubit<GenericListState<T>> {
  GenericListCubit({required this.future, this.limit = 10})
      : super(GenericListState<T>(
            type: GenericListStateType.initial, value: const []));

  final GenericListCubitInputFuture<T> future;
  final int limit;

  int _currentPage = 1;
  bool _canLoadMore = true;

  bool get isLoadingInitial => state.type == GenericListStateType.loading;
  bool get isRefreshing => state.type == GenericListStateType.refresh;
  bool get isLoadingMore => state.type == GenericListStateType.loadMore;
  bool get canLoadMore => _canLoadMore;

  @override
  void emit(GenericListState<T> state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> request() async {
    if (isClosed) return;
    _currentPage = 1;
    _canLoadMore = true;
    emit(state.copyWith(type: GenericListStateType.loading));
    try {
      final res = await future.call(_currentPage, limit);
      _canLoadMore = res.length >= limit;
      emit(state.copyWith(type: GenericListStateType.succeed, value: res));
    } on AppError catch (e) {
      emit(state.copyWith(type: GenericListStateType.error, errorMessage: e));
    } catch (e) {
      emit(state.copyWith(
        type: GenericListStateType.error,
        errorMessage: AppError.defaultError(statusMessage: e.toString()),
      ));
    }
  }

  Future<void> refresh() async {
    if (isClosed) return;
    _currentPage = 1;
    _canLoadMore = true;
    emit(state.copyWith(type: GenericListStateType.refresh));
    try {
      final res = await future.call(_currentPage, limit);
      _canLoadMore = res.length >= limit;
      emit(state.copyWith(type: GenericListStateType.succeed, value: res));
    } on AppError catch (e) {
      emit(state.copyWith(type: GenericListStateType.error, errorMessage: e));
    } catch (e) {
      emit(state.copyWith(
        type: GenericListStateType.error,
        errorMessage: AppError.defaultError(statusMessage: e.toString()),
      ));
    }
  }

  Future<void> loadMore() async {
    if (!_canLoadMore || isLoadingMore || isClosed) return;
    emit(state.copyWith(type: GenericListStateType.loadMore));
    try {
      final nextPage = _currentPage + 1;
      final res = await future.call(nextPage, limit);
      _currentPage = nextPage;
      _canLoadMore = res.length >= limit;
      final combined = [...state.value, ...res];
      emit(state.copyWith(type: GenericListStateType.succeed, value: combined));
    } on AppError catch (e) {
      emit(state.copyWith(type: GenericListStateType.error, errorMessage: e));
    } catch (e) {
      emit(state.copyWith(
        type: GenericListStateType.error,
        errorMessage: AppError.defaultError(statusMessage: e.toString()),
      ));
    }
  }
}
