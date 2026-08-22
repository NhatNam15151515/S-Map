import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class TripRepositoryImpl implements ITripRepository {
  final ITripService _tripService;

  TripRepositoryImpl({required ITripService tripService})
      : _tripService = tripService;

  @override
  Future<List<TripRecordModel>> getTrips() => _tripService.getTrips();

  @override
  Future<TripRecordModel?> getTripById(String id) =>
      _tripService.getTripById(id);

  @override
  Future<void> saveTrip(TripRecordModel trip) => _tripService.saveTrip(trip);

  @override
  Future<void> deleteTrip(String id) => _tripService.deleteTrip(id);

  @override
  Future<void> clearAllTrips() => _tripService.clearAllTrips();

  @override
  Stream<List<TripRecordModel>> watchTrips() => _tripService.watchTrips();
}

/// Fallback implementation cho môi trường Testing hoặc khi chưa khởi tạo storage
class NoOpTripRepository implements ITripRepository {
  const NoOpTripRepository();

  @override
  Future<List<TripRecordModel>> getTrips() async => const [];

  @override
  Future<TripRecordModel?> getTripById(String id) async => null;

  @override
  Future<void> saveTrip(TripRecordModel trip) async {}

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<void> clearAllTrips() async {}

  @override
  Stream<List<TripRecordModel>> watchTrips() =>
      Stream.value(const <TripRecordModel>[]);
}
