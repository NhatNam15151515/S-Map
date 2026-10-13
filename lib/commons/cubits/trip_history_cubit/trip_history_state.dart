import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

enum TripHistoryStatus {
  initial,
  loading,
  success,
  error,
}

class TripHistoryState extends Equatable {
  final TripHistoryStatus status;
  final List<TripRecordModel> trips;
  final String? errorMessage;

  const TripHistoryState({
    this.status = TripHistoryStatus.initial,
    this.trips = const [],
    this.errorMessage,
  });

  bool get isLoading => status == TripHistoryStatus.loading;
  bool get isSuccess => status == TripHistoryStatus.success;
  bool get isError => status == TripHistoryStatus.error;
  bool get isEmpty => trips.isEmpty;
  bool get hasTrips => trips.isNotEmpty;
  int get tripCount => trips.length;

  TripHistoryState copyWith({
    TripHistoryStatus? status,
    List<TripRecordModel>? trips,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TripHistoryState(
      status: status ?? this.status,
      trips: trips ?? this.trips,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, trips, errorMessage];
}
