import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

enum RouteProfileStatus {
  initial,
  loading,
  success,
  error,
}

class RouteProfileState extends Equatable {
  final RouteProfileStatus status;
  final TripStatsModel stats;
  final List<TripRecordModel> allTrips;
  final List<TripRecordModel> filteredTrips;
  final String? profileFilter;
  final StatsTimeRange timeRange;
  final TripChartData chartData;
  final String? errorMessage;

  const RouteProfileState({
    this.status = RouteProfileStatus.initial,
    this.stats = const TripStatsModel.empty(),
    this.allTrips = const [],
    this.filteredTrips = const [],
    this.profileFilter,
    this.timeRange = StatsTimeRange.thisWeek,
    this.chartData = const TripChartData.empty(),
    this.errorMessage,
  });

  bool get isLoading => status == RouteProfileStatus.loading;
  bool get isSuccess => status == RouteProfileStatus.success;
  bool get isError => status == RouteProfileStatus.error;
  bool get hasStats => stats.totalTrips > 0;
  bool get hasTrips => filteredTrips.isNotEmpty;
  bool get hasChartData => chartData.isNotEmpty;

  RouteProfileState copyWith({
    RouteProfileStatus? status,
    TripStatsModel? stats,
    List<TripRecordModel>? allTrips,
    List<TripRecordModel>? filteredTrips,
    String? profileFilter,
    StatsTimeRange? timeRange,
    TripChartData? chartData,
    String? errorMessage,
    bool clearProfileFilter = false,
    bool clearError = false,
  }) {
    return RouteProfileState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      allTrips: allTrips ?? this.allTrips,
      filteredTrips: filteredTrips ?? this.filteredTrips,
      profileFilter:
          clearProfileFilter ? null : (profileFilter ?? this.profileFilter),
      timeRange: timeRange ?? this.timeRange,
      chartData: chartData ?? this.chartData,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        stats,
        allTrips,
        filteredTrips,
        profileFilter,
        timeRange,
        chartData,
        errorMessage,
      ];
}
