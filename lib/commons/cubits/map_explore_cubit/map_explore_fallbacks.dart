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
}
