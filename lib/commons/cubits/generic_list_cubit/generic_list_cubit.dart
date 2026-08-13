import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/models/app_error.dart';
import 'generic_list_cubit_state.dart';

typedef GenericListCubitInputFuture<T> = Future<List<T>> Function(int page, int limit);

class GenericListCubit<T> extends Cubit<GenericListState<T>> {
  GenericListCubit({required this.future, this.limit = 10})
      : super(GenericListState<T>(type: GenericListStateType.initial, value: []));

  final GenericListCubitInputFuture<T> future;
  final int limit;

  int _currentPage = 1;
  bool _canLoadMore = true;
  final ScrollController scrollController = ScrollController();

  bool get isLoadingInitial => state.type == GenericListStateType.loading;
  bool get isRefreshing => state.type == GenericListStateType.refresh;
  bool get isLoadingMore => state.type == GenericListStateType.loadMore;

  void request() async {
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

  void refresh() async {
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

  void loadMore() async {
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

  @override
  Future<void> close() {
    scrollController.dispose();
    return super.close();
  }
}
