import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/models/app_error.dart';
import 'generic_cubit.dart';
import 'generic_cubit_state.dart';

extension GenericCubitListenState<T> on GenericCubit<T> {
  StreamSubscription<GenericState<T>> listenToState({
    Function(T? value)? onStateSuccess,
    Function(AppError? err)? onStateError,
    Function(GenericStateType type)? onStateChange,
  }) {
    return stream.listen((event) {
      onStateChange?.call(event.type);
      if (event.type == GenericStateType.succeed) {
        onStateSuccess?.call(event.value);
      }
      if (event.type == GenericStateType.error) {
        onStateError?.call(event.errorMessage);
      }
    });
  }

  Widget blocBuilder({
    required Widget Function(BuildContext context, GenericState<T> state) builder,
  }) {
    return BlocBuilder<GenericCubit<T>, GenericState<T>>(
      bloc: this,
      builder: builder,
    );
  }
}

extension GenericNonNullCubitListenState<T> on GenericNonNullCubit<T> {
  StreamSubscription<GenericState<T>> listenToState({
    Function(T value)? onStateSuccess,
    Function(AppError? err)? onStateError,
    Function(GenericStateType type)? onStateChange,
  }) {
    return stream.listen((event) {
      onStateChange?.call(event.type);
      if (event.type == GenericStateType.succeed && event.value != null) {
        onStateSuccess?.call(event.value as T);
      }
      if (event.type == GenericStateType.error) {
        onStateError?.call(event.errorMessage);
      }
    });
  }

  Widget blocBuilder({
    required Widget Function(BuildContext context, GenericState<T> state) builder,
  }) {
    return BlocBuilder<GenericNonNullCubit<T>, GenericState<T>>(
      bloc: this,
      builder: builder,
    );
  }
}
