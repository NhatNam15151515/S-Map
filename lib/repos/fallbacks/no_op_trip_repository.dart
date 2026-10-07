import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

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
  Future<void> markTripAsSynced(String id) async {}

  @override
  Stream<List<TripRecordModel>> watchTrips() =>
      Stream.value(const <TripRecordModel>[]);
}
