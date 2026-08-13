import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/models/app_error.dart';
import 'generic_list_cubit.dart';
import 'generic_list_cubit_state.dart';

extension GenericListCubitListenState<T> on GenericListCubit<T> {
  StreamSubscription<GenericListState<T>> listenToState({
    Function(List<T> value)? onStateSuccess,
    Function(AppError? err)? onStateError,
    Function(GenericListStateType type)? onStateChange,
  }) {
    return stream.listen((event) {
      onStateChange?.call(event.type);
      if (event.type == GenericListStateType.succeed) {
        onStateSuccess?.call(event.value);
      }
      if (event.type == GenericListStateType.error) {
        onStateError?.call(event.errorMessage);
      }
    });
  }

  Widget blocBuilder({
    required Widget Function(BuildContext context, GenericListState<T> state) builder,
  }) {
    return BlocBuilder<GenericListCubit<T>, GenericListState<T>>(
      bloc: this,
      builder: builder,
    );
  }
}
