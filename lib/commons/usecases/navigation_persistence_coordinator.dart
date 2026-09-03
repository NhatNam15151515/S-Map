import 'dart:async';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/trip_metrics_tracker.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Kết quả tổng kết và bản ghi hành trình khi kết thúc phiên dẫn đường
class TripFinalizationResult {
  final TripSummary summary;
  final TripRecordModel record;

  const TripFinalizationResult({
    required this.summary,
    required this.record,
  });
}

/// Coordinator quản lý lưu trữ và vòng đời dữ liệu chuyến đi
///
/// Tách biệt hoàn toàn việc lưu Hive, SQLite và Visited POI khỏi NavigationBloc.
class NavigationPersistenceCoordinator {
  final ITripRepository _tripRepository;
  final IActiveTripService _activeTripService;
  final IVisitedPoiService _visitedPoiService;
  final Duration autoSaveInterval;

  Timer? _autoSaveTimer;

  NavigationPersistenceCoordinator({
    required ITripRepository tripRepository,
    required IActiveTripService activeTripService,
    required IVisitedPoiService visitedPoiService,
    this.autoSaveInterval = const Duration(seconds: 30),
  })  : _tripRepository = tripRepository,
        _activeTripService = activeTripService,
        _visitedPoiService = visitedPoiService;

  void startAutoSave(void Function() onAutoSave) {
    stopAutoSave();
    _autoSaveTimer = Timer.periodic(autoSaveInterval, (_) => onAutoSave());
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
  }

  Future<void> saveActiveSession(ActiveTripSnapshot snapshot) async {
    await _activeTripService.saveActiveSession(snapshot);
  }

  Future<ActiveTripSnapshot?> getActiveSession() async {
    return _activeTripService.getActiveSession();
  }

  Future<bool> isSessionExpired(ActiveTripSnapshot snapshot) async {
    if (!snapshot.isValid()) {
      DLog.warning(
          '⚠️ [NavigationPersistenceCoordinator] Cannot resume: active session expired (> 24h)');
      unawaited(clearActiveSessionSafely());
      return true;
    }
    return false;
  }

  Future<void> clearActiveSessionSafely() async {
    try {
      await _activeTripService.clearActiveSession();
    } catch (e, stack) {
      DLog.error(
          '❌ [NavigationPersistenceCoordinator] Failed to clear active session: $e',
          e,
          stack);
    }
  }

  Future<void> saveTripSafely(TripRecordModel trip) async {
    try {
      await _tripRepository.saveTrip(trip);
    } catch (e, stack) {
      DLog.error(
          '❌ [NavigationPersistenceCoordinator] Failed to auto-save trip: $e',
          e,
          stack);
    }
  }

  Future<void> recordVisitedDestinationSafely(
    RoutePoint? destination,
    String? destinationName,
  ) async {
    if (destination == null) return;

    final name = destinationName?.trim();
    final displayName = name == null || name.isEmpty ? 'Điểm đã đến' : name;
    final poi = PoiModel(
      osmId:
          'visited:${destination.lat.toStringAsFixed(6)}:${destination.lon.toStringAsFixed(6)}',
      name: displayName,
      nameAscii: AppUtils.instance.toAscii(displayName),
      category: 'place',
      lat: destination.lat,
      lon: destination.lon,
    );

    try {
      await _visitedPoiService.recordVisited(poi);
    } catch (e, stack) {
      DLog.warning(
          '⚠️ [NavigationPersistenceCoordinator] Không thể lưu POI đã đến: $e',
          stack);
    }
  }

  /// Tổng kết và hoàn tất lưu trữ chuyến đi (dùng chung cho cả Arrive và Stop)
  Future<TripFinalizationResult> finalizeTrip({
    required TripMetricsTracker metrics,
    required DateTime? startTime,
    required RoutePoint? destination,
    required String? destinationName,
    required String profile,
    required List<List<double>>? polyline,
    required bool hasArrived,
  }) async {
    stopAutoSave();
    unawaited(clearActiveSessionSafely());

    final now = DateTime.now();
    final effectiveStartTime = startTime ?? now;

    final summary = metrics.buildSummary(
      startTime: effectiveStartTime,
      endTime: now,
      destinationName: destinationName,
      hasArrived: hasArrived,
    );

    final record = metrics.buildRecord(
      id: 'trip_${now.microsecondsSinceEpoch}_${now.hashCode.abs()}',
      startTime: effectiveStartTime,
      endTime: now,
      destinationName: destinationName,
      profile: profile,
      polyline: polyline,
      hasArrived: hasArrived,
    );

    unawaited(saveTripSafely(record));
    if (hasArrived && destination != null) {
      await recordVisitedDestinationSafely(destination, destinationName);
    }

    return TripFinalizationResult(summary: summary, record: record);
  }

  void dispose() {
    stopAutoSave();
  }
}
