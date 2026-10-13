import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

enum SavedRoutesStatus {
  initial,
  loading,
  success,
  error,
}

class SavedRoutesState extends Equatable {
  final SavedRoutesStatus status;
  final List<CustomRouteModel> routes;
  final String? errorMessage;

  const SavedRoutesState({
    this.status = SavedRoutesStatus.initial,
    this.routes = const [],
    this.errorMessage,
  });

  bool get isLoading => status == SavedRoutesStatus.loading;
  bool get isSuccess => status == SavedRoutesStatus.success;
  bool get isEmpty => routes.isEmpty && status == SavedRoutesStatus.success;
  int get count => routes.length;

  SavedRoutesState copyWith({
    SavedRoutesStatus? status,
    List<CustomRouteModel>? routes,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SavedRoutesState(
      status: status ?? this.status,
      routes: routes ?? this.routes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, routes, errorMessage];
}
