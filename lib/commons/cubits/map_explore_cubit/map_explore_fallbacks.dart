import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Fallback / No-Op implementation for IFireStoreService in decoupled/testing environments
class NoOpFireStoreService implements IFireStoreService {
  @override
  CollectionReference? get usersCollection => null;

  @override
  CollectionReference? get notificationsCollection => null;

  @override
  CollectionReference? get savedPlacesCollection => null;

  @override
  CollectionReference? get placesCollection => null;

  @override
  CollectionReference? get routesCollection => null;

  @override
  Future<void> saveUserProfile(User user) async {}

  @override
  Future<User?> getUserProfile(String userId) async => null;

  @override
  Future<List<NotificationModel>> getNotifications({int limit = 20}) async => [];

  @override
  Future<List<PlaceModel>> getExplorePlaces({String? category, int limit = 10}) async => [];

  @override
  Stream<List<PlaceModel>> streamExplorePlaces({String? category, int limit = 10}) => const Stream.empty();

  @override
  Future<void> savePlace(String userId, Map<String, dynamic> placeData) async {}

  @override
  Stream<QuerySnapshot?> streamSavedPlaces(String userId) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> getSavedPlaces(String userId) async => [];

  @override
  Future<void> deleteSavedPlace(String userId, String poiKey) async {}

  @override
  Future<void> clearSavedPlaces(String userId) async {}

  @override
  Future<void> saveSearchQuery(String userId, String query) async {}

  @override
  Future<List<String>> getSearchQueries(String userId, {int limit = 20}) async => [];

  @override
  Future<void> deleteSearchQuery(String userId, String query) async {}

  @override
  Future<void> clearSearchQueries(String userId) async {}

  @override
  Future<void> saveVisitedPlace(
      String userId, Map<String, dynamic> placeData) async {}

  @override
  Future<List<Map<String, dynamic>>> getVisitedPlaces(String userId) async => [];

  @override
  Future<void> clearVisitedPlaces(String userId) async {}

  @override
  Future<void> saveCustomRoute(
      String userId, Map<String, dynamic> routeData) async {}

  @override
  Future<List<Map<String, dynamic>>> getCustomRoutes(String userId) async => [];

  @override
  Future<void> deleteCustomRoute(String userId, String routeId) async {}

  @override
  Future<void> clearCustomRoutes(String userId) async {}

  @override
  Future<void> syncTrip(String userId, TripRecordModel trip) async {}

  @override
  Future<void> syncTripsBatch(String userId, List<TripRecordModel> trips) async {}

  @override
  Future<void> updateDailyStats(String userId, DateTime date, TripRecordModel trip) async {}

  @override
  Future<List<TripRecordModel>> getSyncedTrips(String userId) async => const [];
}
