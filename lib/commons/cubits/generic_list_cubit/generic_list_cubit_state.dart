import 'package:s_map/models/app_error.dart';

enum GenericListStateType {
  initial,
  loading,
  refresh,
  loadMore,
  succeed,
  error,
}

class GenericListState<T> {
  final GenericListStateType type;
  final List<T> value;
  final AppError? errorMessage;

  GenericListState({required this.type, required this.value, this.errorMessage});

  GenericListState<T> copyWith({
    GenericListStateType? type,
    List<T>? value,
    AppError? errorMessage,
  }) {
    return GenericListState<T>(
      type: type ?? this.type,
      value: value ?? this.value,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
