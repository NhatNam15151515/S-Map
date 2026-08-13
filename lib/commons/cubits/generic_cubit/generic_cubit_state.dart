import 'package:s_map/models/app_error.dart';

enum GenericStateType {
  initial,
  loading,
  succeed,
  error,
}

class GenericState<T> {
  final GenericStateType type;
  final T? value;
  final AppError? errorMessage;

  GenericState({required this.type, this.value, this.errorMessage});
}
