import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class FireStoreService implements IFireStoreService {
  FireStoreService._() {
    initCompleter.complete(this);
  }

  static FireStoreService? _instance;
  factory FireStoreService() => _instance ??= FireStoreService._();
  static FireStoreService get instance => FireStoreService();

  FirebaseFirestore? get _fs {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (e) {
      DLog.error("Firestore access error: $e");
    }
    return null;
  }

  Completer<FireStoreService> initCompleter = Completer();

  // Collections
  @override
  CollectionReference? get usersCollection => _fs?.collection('users');
  @override
  CollectionReference? get notificationsCollection => _fs?.collection('notifications');
  @override
  CollectionReference? get savedPlacesCollection => _fs?.collection('saved_places');
  @override
  CollectionReference? get placesCollection => _fs?.collection('places');
  @override
  CollectionReference? get routesCollection => _fs?.collection('routes');

  // --- USER METHODS ---
  @override
  Future<void> saveUserProfile(User user) async {
    if (user.id == null || usersCollection == null) return;
    try {
      await usersCollection!.doc(user.id.toString()).set(user.toJson(), SetOptions(merge: true));
    } catch (e) {
      DLog.error("Firestore saveUserProfile error: $e");
    }
  }

  @override
  Future<User?> getUserProfile(String userId) async {
    if (usersCollection == null) return null;
    try {
      final doc = await usersCollection!.doc(userId).get();
      if (doc.exists && doc.data() != null) {
        return User.fromJson(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      DLog.error("Firestore getUserProfile error: $e");
    }
    return null;
  }

  // --- NOTIFICATION METHODS ---
  @override
  Future<List<NotificationModel>> getNotifications({int limit = 20}) async {
    if (notificationsCollection == null) return [];
    try {
      final snapshot = await notificationsCollection!
          .orderBy('createdDate', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return NotificationModel.fromJson(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // --- PLACES METHODS ---
  @override
  Future<List<PlaceModel>> getExplorePlaces({String? category, int limit = 10}) async {
    if (placesCollection == null) return [];
    try {
      Query query = placesCollection!.limit(limit);
      if (category != null && category.isNotEmpty && category != "Tất cả") {
        query = query.where('category', isEqualTo: category);
      }
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return PlaceModel.fromJson(data);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<PlaceModel>> streamExplorePlaces({String? category, int limit = 10}) {
    if (placesCollection == null) {
      return Stream.value([]);
    }
    try {
      Query query = placesCollection!.limit(limit);
      if (category != null && category.isNotEmpty && category != "Tất cả") {
        query = query.where('category', isEqualTo: category);
      }
      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return PlaceModel.fromJson(data);
        }).toList();
      });
    } catch (_) {
      return Stream.value([]);
    }
  }

  // --- SAVED PLACES METHODS ---
  @override
  Future<void> savePlace(String userId, Map<String, dynamic> placeData) async {
    if (savedPlacesCollection == null) return;
    try {
      await savedPlacesCollection!.add({
        'userId': userId,
        ...placeData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DLog.error("Firestore savePlace error: $e");
    }
  }

  @override
  Stream<QuerySnapshot?> streamSavedPlaces(String userId) {
    if (savedPlacesCollection == null) {
      return Stream.value(null);
    }
    try {
      return savedPlacesCollection!
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (_) {
      return Stream.value(null);
    }
  }

  // --- TRIP & STATS SYNC METHODS ---
  @override
  Future<void> syncTrip(String userId, TripRecordModel trip) async {
    if (_fs == null) {
      throw StateError('Cloud Firestore instance is not initialized.');
    }
    try {
      final userTrips = _fs!.collection('users').doc(userId).collection('trips');
      final tripMap = trip.toMap();
      tripMap['isSynced'] = true;
      tripMap['syncedAt'] = FieldValue.serverTimestamp();
      await userTrips.doc(trip.id).set(tripMap, SetOptions(merge: true));
      await updateDailyStats(userId, trip.startTime, trip);
    } catch (e) {
      DLog.error("Firestore syncTrip error: $e");
      rethrow;
    }
  }

  @override
  Future<void> syncTripsBatch(String userId, List<TripRecordModel> trips) async {
    if (trips.isEmpty) return;
    if (_fs == null) {
      throw StateError('Cloud Firestore instance is not initialized.');
    }
    try {
      final fs = _fs!;
      final batch = fs.batch();
      final userTrips = fs.collection('users').doc(userId).collection('trips');

      for (final trip in trips) {
        final tripMap = trip.toMap();
        tripMap['isSynced'] = true;
        tripMap['syncedAt'] = FieldValue.serverTimestamp();
        batch.set(userTrips.doc(trip.id), tripMap, SetOptions(merge: true));
      }

      await batch.commit();

      for (final trip in trips) {
        await updateDailyStats(userId, trip.startTime, trip);
      }
    } catch (e) {
      DLog.error("Firestore syncTripsBatch error: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateDailyStats(String userId, DateTime date, TripRecordModel trip) async {
    if (_fs == null) {
      throw StateError('Cloud Firestore instance is not initialized.');
    }
    try {
      final dateKey =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final statsDoc = _fs!
          .collection('users')
          .doc(userId)
          .collection('daily_stats')
          .doc(dateKey);

      await _fs!.runTransaction((transaction) async {
        final snapshot = await transaction.get(statsDoc);
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          final appliedTrips = List<String>.from(data['appliedTrips'] as List? ?? []);

          // Idempotency: Bỏ qua cộng dồn nếu chuyến đi đã được tính toán trong ngày
          if (appliedTrips.contains(trip.id)) {
            return;
          }

          final currentDistance = (data['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0;
          final currentDuration = (data['totalDurationMs'] as num?)?.toInt() ?? 0;
          final currentTrips = (data['tripCount'] as num?)?.toInt() ?? 0;
          final currentTopSpeed = (data['topSpeedKmh'] as num?)?.toDouble() ?? 0.0;

          final newTopSpeed = trip.topSpeedKmh > currentTopSpeed ? trip.topSpeedKmh : currentTopSpeed;

          transaction.update(statsDoc, {
            'totalDistanceMeters': currentDistance + trip.distanceMeters,
            'totalDurationMs': currentDuration + trip.durationMs,
            'tripCount': currentTrips + 1,
            'topSpeedKmh': newTopSpeed,
            'appliedTrips': FieldValue.arrayUnion([trip.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(statsDoc, {
            'date': dateKey,
            'totalDistanceMeters': trip.distanceMeters,
            'totalDurationMs': trip.durationMs,
            'tripCount': 1,
            'topSpeedKmh': trip.topSpeedKmh,
            'appliedTrips': [trip.id],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      DLog.error("Firestore updateDailyStats error: $e");
      rethrow;
    }
  }

  @override
  Future<List<TripRecordModel>> getSyncedTrips(String userId) async {
    if (_fs == null) return [];
    try {
      final userTrips = _fs!.collection('users').doc(userId).collection('trips');
      final snapshot = await userTrips.orderBy('startTime', descending: true).get();
      return snapshot.docs.map((doc) => TripRecordModel.fromMap(doc.data())).toList();
    } catch (e) {
      DLog.error("Firestore getSyncedTrips error: $e");
      return [];
    }
  }
}
