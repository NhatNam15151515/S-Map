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
  Future<void> markTripAsSynced(String id) => _tripService.markTripAsSynced(id);

  @override
  Stream<List<TripRecordModel>> watchTrips() => _tripService.watchTrips();
}
