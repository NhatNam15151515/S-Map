import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:s_map/models/models.dart';

abstract class IFireStoreService {
  CollectionReference? get usersCollection;
  CollectionReference? get notificationsCollection;
  CollectionReference? get savedPlacesCollection;
  CollectionReference? get placesCollection;
  CollectionReference? get routesCollection;

  // --- USER METHODS ---
  Future<void> saveUserProfile(User user);
  Future<User?> getUserProfile(String userId);

  // --- NOTIFICATION METHODS ---
  Future<List<NotificationModel>> getNotifications({int limit = 20});

  // --- PLACES METHODS ---
  Future<List<PlaceModel>> getExplorePlaces({String? category, int limit = 10});
  Stream<List<PlaceModel>> streamExplorePlaces({String? category, int limit = 10});

  // --- SAVED PLACES METHODS ---
  Future<void> savePlace(String userId, Map<String, dynamic> placeData);
  Stream<QuerySnapshot?> streamSavedPlaces(String userId);

  // --- TRIP & STATS SYNC METHODS ---
  Future<void> syncTrip(String userId, TripRecordModel trip);
  Future<void> syncTripsBatch(String userId, List<TripRecordModel> trips);
  Future<void> updateDailyStats(String userId, DateTime date, TripRecordModel trip);
  Future<List<TripRecordModel>> getSyncedTrips(String userId);
}
