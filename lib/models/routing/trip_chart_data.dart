import 'package:equatable/equatable.dart';
import 'trip_record_model.dart';

/// Khoảng thời gian lọc và thống kê biểu đồ
enum StatsTimeRange {
  today,
  thisWeek,
  thisMonth,
  thisYear,
  allTime,
}

/// Dữ liệu cho từng cột biểu đồ khoảng cách
class TripChartBarData extends Equatable {
  final int x;
  final String label;
  final double distanceKm;
  final int tripCount;
  final DateTime startDate;
  final DateTime endDate;

  const TripChartBarData({
    required this.x,
    required this.label,
    required this.distanceKm,
    required this.tripCount,
    required this.startDate,
    required this.endDate,
  });

  @override
  List<Object?> get props => [x, label, distanceKm, tripCount, startDate, endDate];
}

/// Tập hợp toàn bộ dữ liệu biểu đồ quãng đường cho một khoảng thời gian
class TripChartData extends Equatable {
  final List<TripChartBarData> bars;
  final double maxDistanceKm;
  final double totalDistanceKm;
  final StatsTimeRange timeRange;

  const TripChartData({
    required this.bars,
    required this.maxDistanceKm,
    required this.totalDistanceKm,
    required this.timeRange,
  });

  const TripChartData.empty({this.timeRange = StatsTimeRange.thisWeek})
      : bars = const [],
        maxDistanceKm = 0.0,
        totalDistanceKm = 0.0;

  bool get isEmpty => bars.isEmpty || totalDistanceKm == 0.0;
  bool get isNotEmpty => !isEmpty;

  /// Lọc danh sách chuyến đi theo khoảng thời gian được chỉ định
  static List<TripRecordModel> filterTripsByTimeRange(
    List<TripRecordModel> trips,
    StatsTimeRange timeRange, {
    DateTime? now,
  }) {
    if (trips.isEmpty) return const [];
    final current = now ?? DateTime.now();

    switch (timeRange) {
      case StatsTimeRange.today:
        final startOfDay = DateTime(current.year, current.month, current.day);
        final endOfDay = DateTime(current.year, current.month, current.day, 23, 59, 59, 999);
        return trips.where((t) {
          return !t.startTime.isBefore(startOfDay) && !t.startTime.isAfter(endOfDay);
        }).toList();

      case StatsTimeRange.thisWeek:
        // Monday = 1, Sunday = 7
        final weekday = current.weekday;
        final startOfWeek = DateTime(current.year, current.month, current.day - (weekday - 1));
        final endOfWeek = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day + 6,
          23,
          59,
          59,
          999,
        );
        return trips.where((t) {
          return !t.startTime.isBefore(startOfWeek) && !t.startTime.isAfter(endOfWeek);
        }).toList();

      case StatsTimeRange.thisMonth:
        final startOfMonth = DateTime(current.year, current.month, 1);
        final lastDay = DateTime(current.year, current.month + 1, 0).day;
        final endOfMonth = DateTime(current.year, current.month, lastDay, 23, 59, 59, 999);
        return trips.where((t) {
          return !t.startTime.isBefore(startOfMonth) && !t.startTime.isAfter(endOfMonth);
        }).toList();

      case StatsTimeRange.thisYear:
        final startOfYear = DateTime(current.year, 1, 1);
        final endOfYear = DateTime(current.year, 12, 31, 23, 59, 59, 999);
        return trips.where((t) {
          return !t.startTime.isBefore(startOfYear) && !t.startTime.isAfter(endOfYear);
        }).toList();

      case StatsTimeRange.allTime:
        return trips;
    }
  }

  /// Tính toán dữ liệu biểu đồ từ danh sách các chuyến đi
  factory TripChartData.fromTrips(
    List<TripRecordModel> trips,
    StatsTimeRange timeRange, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    switch (timeRange) {
      case StatsTimeRange.today:
        return _buildTodayChart(trips, current);
      case StatsTimeRange.thisWeek:
        return _buildWeekChart(trips, current);
      case StatsTimeRange.thisMonth:
        return _buildMonthChart(trips, current);
      case StatsTimeRange.thisYear:
        return _buildYearChart(trips, current);
      case StatsTimeRange.allTime:
        return _buildAllTimeChart(trips, current);
    }
  }

  static TripChartData _buildTodayChart(List<TripRecordModel> trips, DateTime current) {
    // 6 buckets of 4 hours: 00-04, 04-08, 08-12, 12-16, 16-20, 20-24
    const bucketHours = [0, 4, 8, 12, 16, 20];
    const labels = ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'];

    final bars = <TripChartBarData>[];
    var totalDistance = 0.0;
    var maxDistance = 0.0;

    for (var i = 0; i < bucketHours.length; i++) {
      final startH = bucketHours[i];
      final endH = startH + 3;
      final start = DateTime(current.year, current.month, current.day, startH, 0, 0);
      final end = DateTime(current.year, current.month, current.day, endH, 59, 59, 999);

      var distance = 0.0;
      var count = 0;

      for (final trip in trips) {
        if (!trip.startTime.isBefore(start) && !trip.startTime.isAfter(end)) {
          distance += trip.distanceKm;
          count++;
        }
      }

      totalDistance += distance;
      if (distance > maxDistance) maxDistance = distance;

      bars.add(TripChartBarData(
        x: i,
        label: labels[i],
        distanceKm: double.parse(distance.toStringAsFixed(2)),
        tripCount: count,
        startDate: start,
        endDate: end,
      ));
    }

    return TripChartData(
      bars: List.unmodifiable(bars),
      maxDistanceKm: double.parse(maxDistance.toStringAsFixed(2)),
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      timeRange: StatsTimeRange.today,
    );
  }

  static TripChartData _buildWeekChart(List<TripRecordModel> trips, DateTime current) {
    // 7 days of current week: Monday to Sunday
    const dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final weekday = current.weekday; // 1 = Monday, 7 = Sunday
    final monday = DateTime(current.year, current.month, current.day - (weekday - 1));

    final bars = <TripChartBarData>[];
    var totalDistance = 0.0;
    var maxDistance = 0.0;

    for (var i = 0; i < 7; i++) {
      final dayDate = monday.add(Duration(days: i));
      final start = DateTime(dayDate.year, dayDate.month, dayDate.day, 0, 0, 0);
      final end = DateTime(dayDate.year, dayDate.month, dayDate.day, 23, 59, 59, 999);

      var distance = 0.0;
      var count = 0;

      for (final trip in trips) {
        if (!trip.startTime.isBefore(start) && !trip.startTime.isAfter(end)) {
          distance += trip.distanceKm;
          count++;
        }
      }

      totalDistance += distance;
      if (distance > maxDistance) maxDistance = distance;

      bars.add(TripChartBarData(
        x: i,
        label: dayLabels[i],
        distanceKm: double.parse(distance.toStringAsFixed(2)),
        tripCount: count,
        startDate: start,
        endDate: end,
      ));
    }

    return TripChartData(
      bars: List.unmodifiable(bars),
      maxDistanceKm: double.parse(maxDistance.toStringAsFixed(2)),
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      timeRange: StatsTimeRange.thisWeek,
    );
  }

  static TripChartData _buildMonthChart(List<TripRecordModel> trips, DateTime current) {
    // 6 intervals: 1-5, 6-10, 11-15, 16-20, 21-25, 26-end
    final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
    final intervals = [
      [1, 5],
      [6, 10],
      [11, 15],
      [16, 20],
      [21, 25],
      [26, daysInMonth],
    ];

    final bars = <TripChartBarData>[];
    var totalDistance = 0.0;
    var maxDistance = 0.0;

    for (var i = 0; i < intervals.length; i++) {
      final startDay = intervals[i][0];
      final endDay = intervals[i][1];
      final start = DateTime(current.year, current.month, startDay, 0, 0, 0);
      final end = DateTime(current.year, current.month, endDay, 23, 59, 59, 999);

      var distance = 0.0;
      var count = 0;

      for (final trip in trips) {
        if (!trip.startTime.isBefore(start) && !trip.startTime.isAfter(end)) {
          distance += trip.distanceKm;
          count++;
        }
      }

      totalDistance += distance;
      if (distance > maxDistance) maxDistance = distance;

      bars.add(TripChartBarData(
        x: i,
        label: '$startDay-$endDay',
        distanceKm: double.parse(distance.toStringAsFixed(2)),
        tripCount: count,
        startDate: start,
        endDate: end,
      ));
    }

    return TripChartData(
      bars: List.unmodifiable(bars),
      maxDistanceKm: double.parse(maxDistance.toStringAsFixed(2)),
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      timeRange: StatsTimeRange.thisMonth,
    );
  }

  static TripChartData _buildYearChart(List<TripRecordModel> trips, DateTime current) {
    // 12 months: T1 to T12
    final bars = <TripChartBarData>[];
    var totalDistance = 0.0;
    var maxDistance = 0.0;

    for (var month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(current.year, month + 1, 0).day;
      final start = DateTime(current.year, month, 1, 0, 0, 0);
      final end = DateTime(current.year, month, daysInMonth, 23, 59, 59, 999);

      var distance = 0.0;
      var count = 0;

      for (final trip in trips) {
        if (!trip.startTime.isBefore(start) && !trip.startTime.isAfter(end)) {
          distance += trip.distanceKm;
          count++;
        }
      }

      totalDistance += distance;
      if (distance > maxDistance) maxDistance = distance;

      bars.add(TripChartBarData(
        x: month - 1,
        label: 'T$month',
        distanceKm: double.parse(distance.toStringAsFixed(2)),
        tripCount: count,
        startDate: start,
        endDate: end,
      ));
    }

    return TripChartData(
      bars: List.unmodifiable(bars),
      maxDistanceKm: double.parse(maxDistance.toStringAsFixed(2)),
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      timeRange: StatsTimeRange.thisYear,
    );
  }

  static TripChartData _buildAllTimeChart(List<TripRecordModel> trips, DateTime current) {
    final bars = <TripChartBarData>[];
    var totalDistance = 0.0;
    var maxDistance = 0.0;

    var oldest = current;
    for (final trip in trips) {
      if (trip.startTime.isBefore(oldest)) {
        oldest = trip.startTime;
      }
    }
    final monthSpan = (current.year - oldest.year) * 12 + (current.month - oldest.month);
    final bucketCount = monthSpan < 5 ? 6 : monthSpan + 1;

    for (var i = bucketCount - 1; i >= 0; i--) {
      final targetDate = DateTime(current.year, current.month - i, 1);
      final daysInMonth = DateTime(targetDate.year, targetDate.month + 1, 0).day;
      final start = DateTime(targetDate.year, targetDate.month, 1, 0, 0, 0);
      final end = DateTime(targetDate.year, targetDate.month, daysInMonth, 23, 59, 59, 999);

      var distance = 0.0;
      var count = 0;

      for (final trip in trips) {
        if (!trip.startTime.isBefore(start) && !trip.startTime.isAfter(end)) {
          distance += trip.distanceKm;
          count++;
        }
      }

      totalDistance += distance;
      if (distance > maxDistance) maxDistance = distance;

      bars.add(TripChartBarData(
        x: (bucketCount - 1) - i,
        label: 'T${targetDate.month}/${targetDate.year.toString().substring(2)}',
        distanceKm: double.parse(distance.toStringAsFixed(2)),
        tripCount: count,
        startDate: start,
        endDate: end,
      ));
    }

    return TripChartData(
      bars: List.unmodifiable(bars),
      maxDistanceKm: double.parse(maxDistance.toStringAsFixed(2)),
      totalDistanceKm: double.parse(totalDistance.toStringAsFixed(2)),
      timeRange: StatsTimeRange.allTime,
    );
  }

  @override
  List<Object?> get props => [bars, maxDistanceKm, totalDistanceKm, timeRange];
}
