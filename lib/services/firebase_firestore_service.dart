import 'dart:async';
import 'dart:convert';
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
  /// Legacy root collection kept only so existing data can be migrated. New
  /// user data must always use users/{uid}/saved_places.
  CollectionReference? get savedPlacesCollection => _fs?.collection('saved_places');
  @override
  CollectionReference? get placesCollection => _fs?.collection('places');
  @override
  /// Legacy root collection kept only so existing data can be migrated. New
  /// user data must always use users/{uid}/routes.
  CollectionReference? get routesCollection => _fs?.collection('routes');

  CollectionReference? _userCollection(String userId, String name) {
    final users = usersCollection;
    if (users == null || userId.trim().isEmpty) return null;
    return users.doc(userId).collection(name);
  }

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
    final collection = _userCollection(userId, 'saved_places');
    if (collection == null) return;
    try {
      final poiKey = (placeData['poiKey'] ??
              '${placeData['name'] ?? ''}:${placeData['lat'] ?? ''}:${placeData['lon'] ?? ''}')
          .toString();
      await collection.doc(_safeDocumentId(poiKey)).set({
        'poiKey': poiKey,
        ...placeData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      DLog.error("Firestore savePlace error: $e");
    }
  }

  @override
  Stream<QuerySnapshot?> streamSavedPlaces(String userId) {
    final collection = _userCollection(userId, 'saved_places');
    if (collection == null) {
      return Stream.value(null);
    }
    try {
      unawaited(_migrateLegacySavedPlaces(userId, collection));
      return collection
          .orderBy('createdAt', descending: true)
          .snapshots();
    } catch (_) {
      return Stream.value(null);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSavedPlaces(String userId) async {
    final collection = _userCollection(userId, 'saved_places');
    if (collection == null) return [];
    try {
      await _migrateLegacySavedPlaces(userId, collection);
      final snapshot = await collection.orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(
            doc.data() as Map<String, dynamic>);
        data.remove('createdAt');
        data.remove('updatedAt');
        return data;
      }).toList();
    } catch (e) {
      DLog.error("Firestore getSavedPlaces error: $e");
      return [];
    }
  }

  @override
  Future<void> deleteSavedPlace(String userId, String poiKey) async {
    final collection = _userCollection(userId, 'saved_places');
    if (collection == null) return;
    try {
      await collection.doc(_safeDocumentId(poiKey)).delete();
      // Also remove an old root record if this user has not opened the list
      // since the schema migration was introduced.
      await savedPlacesCollection
          ?.doc(_safeDocumentId('$userId:$poiKey'))
          .delete();
    } catch (e) {
      DLog.error("Firestore deleteSavedPlace error: $e");
    }
  }

  @override
  Future<void> clearSavedPlaces(String userId) async {
    final collection = _userCollection(userId, 'saved_places');
    final legacyCollection = savedPlacesCollection;
    if (collection == null) return;
    try {
      await _deleteQueryDocuments(collection);
      if (legacyCollection != null) {
        final legacySnapshot =
            await legacyCollection.where('userId', isEqualTo: userId).get();
        await _deleteDocuments(legacySnapshot.docs);
      }
    } catch (e) {
      DLog.error("Firestore clearSavedPlaces error: $e");
    }
  }

  @override
  Future<void> saveSearchQuery(String userId, String query) async {
    final normalized = query.trim();
    final fs = _fs;
    if (normalized.isEmpty || fs == null) return;
    try {
      await fs
          .collection('users')
          .doc(userId)
          .collection('search_history')
          .doc(_safeDocumentId(normalized.toLowerCase()))
          .set({
        'query': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      DLog.error("Firestore saveSearchQuery error: $e");
    }
  }

  @override
  Future<List<String>> getSearchQueries(String userId, {int limit = 20}) async {
    final fs = _fs;
    if (fs == null) return [];
    try {
      final snapshot = await fs
          .collection('users')
          .doc(userId)
          .collection('search_history')
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => (doc.data()['query'] ?? '').toString().trim())
          .where((query) => query.isNotEmpty)
          .toList();
    } catch (e) {
      DLog.error("Firestore getSearchQueries error: $e");
      return [];
    }
  }

  @override
  Future<void> deleteSearchQuery(String userId, String query) async {
    final fs = _fs;
    final normalized = query.trim();
    if (fs == null || normalized.isEmpty) return;
    try {
      await fs
          .collection('users')
          .doc(userId)
          .collection('search_history')
          .doc(_safeDocumentId(normalized.toLowerCase()))
          .delete();
    } catch (e) {
      DLog.error("Firestore deleteSearchQuery error: $e");
    }
  }

  @override
  Future<void> clearSearchQueries(String userId) async {
    final fs = _fs;
    if (fs == null) return;
    try {
      final collection = fs
          .collection('users')
          .doc(userId)
          .collection('search_history');
      final snapshot = await collection.get();
      final batch = fs.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      DLog.error("Firestore clearSearchQueries error: $e");
    }
  }

  @override
  Future<void> saveVisitedPlace(
      String userId, Map<String, dynamic> placeData) async {
    final fs = _fs;
    if (fs == null) return;
    try {
      final poiKey = (placeData['poiKey'] ??
              '${placeData['name'] ?? ''}:${placeData['lat'] ?? ''}:${placeData['lon'] ?? ''}')
          .toString();
      await fs
          .collection('users')
          .doc(userId)
          .collection('visited_places')
          .doc(_safeDocumentId(poiKey))
          .set({
        'poiKey': poiKey,
        ...placeData,
        'visitedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      DLog.error("Firestore saveVisitedPlace error: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getVisitedPlaces(String userId) async {
    final fs = _fs;
    if (fs == null) return [];
    try {
      final snapshot = await fs
          .collection('users')
          .doc(userId)
          .collection('visited_places')
          .orderBy('visitedAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data.remove('visitedAt');
        return data;
      }).toList();
    } catch (e) {
      DLog.error("Firestore getVisitedPlaces error: $e");
      return [];
    }
  }

  @override
  Future<void> clearVisitedPlaces(String userId) async {
    final fs = _fs;
    if (fs == null) return;
    try {
      final collection = fs
          .collection('users')
          .doc(userId)
          .collection('visited_places');
      final snapshot = await collection.get();
      final batch = fs.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      DLog.error("Firestore clearVisitedPlaces error: $e");
    }
  }

  // --- CUSTOM ROUTE METHODS ---
  @override
  Future<void> saveCustomRoute(
      String userId, Map<String, dynamic> routeData) async {
    final collection = _userCollection(userId, 'routes');
    if (collection == null) return;
    final routeId = (routeData['id'] ?? '').toString().trim();
    if (routeId.isEmpty) return;
    try {
      final firestoreRoute = _encodeNestedArrayField(routeData, 'fullPolyline');
      await collection.doc(_safeDocumentId(routeId)).set({
        ...firestoreRoute,
        'routeId': routeId,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      DLog.error("Firestore saveCustomRoute error: $e");
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomRoutes(String userId) async {
    final collection = _userCollection(userId, 'routes');
    if (collection == null) return [];
    try {
      await _migrateLegacyCustomRoutes(userId, collection);
      final snapshot = await collection.get();
      return snapshot.docs.map((doc) {
        final data = _decodeNestedArrayField(
          Map<String, dynamic>.from(doc.data() as Map<String, dynamic>),
          'fullPolyline',
        );
        data['id'] = (data['id'] ?? data['routeId'] ?? doc.id).toString();
        data.remove('userId');
        data.remove('routeId');
        data.remove('syncedAt');
        return data;
      }).toList();
    } catch (e) {
      DLog.error("Firestore getCustomRoutes error: $e");
      return [];
    }
  }

  @override
  Future<void> deleteCustomRoute(String userId, String routeId) async {
    final collection = _userCollection(userId, 'routes');
    if (collection == null || routeId.trim().isEmpty) return;
    try {
      await collection.doc(_safeDocumentId(routeId.trim())).delete();
      await routesCollection
          ?.doc(_safeDocumentId('$userId:${routeId.trim()}'))
          .delete();
    } catch (e) {
      DLog.error("Firestore deleteCustomRoute error: $e");
      rethrow;
    }
  }

  @override
  Future<void> clearCustomRoutes(String userId) async {
    final collection = _userCollection(userId, 'routes');
    final legacyCollection = routesCollection;
    if (collection == null) return;
    try {
      await _deleteQueryDocuments(collection);
      if (legacyCollection != null) {
        final legacySnapshot =
            await legacyCollection.where('userId', isEqualTo: userId).get();
        await _deleteDocuments(legacySnapshot.docs);
      }
    } catch (e) {
      DLog.error("Firestore clearCustomRoutes error: $e");
      rethrow;
    }
  }

  /// Move records created by the old root-level schema into the owner's
  /// subcollection. The write and delete happen in one batch, so a failed
  /// migration cannot lose the legacy record.
  Future<void> _migrateLegacySavedPlaces(
    String userId,
    CollectionReference target,
  ) async {
    final legacy = savedPlacesCollection;
    final fs = _fs;
    if (legacy == null || fs == null) return;

    try {
      final snapshot = await legacy.where('userId', isEqualTo: userId).get();
      if (snapshot.docs.isEmpty) return;

      final batch = fs.batch();
      var migratedCount = 0;
      for (final doc in snapshot.docs) {
        final raw = doc.data();
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final poiKey = (data['poiKey'] ??
                '${data['name'] ?? ''}:${data['lat'] ?? ''}:${data['lon'] ?? ''}')
            .toString();
        if (poiKey.trim().isEmpty) continue;

        data
          ..remove('userId')
          ..['poiKey'] = poiKey
          ..['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(
          target.doc(_safeDocumentId(poiKey)),
          data,
          SetOptions(merge: true),
        );
        batch.delete(doc.reference);
        migratedCount++;
      }

      if (migratedCount > 0) {
        await batch.commit();
        DLog.info(
            '☁️ Đã chuyển $migratedCount saved place vào users/$userId/saved_places');
      }
    } catch (e) {
      // Keep the legacy record for a later retry. This is intentionally best
      // effort so opening the Saved screen still falls back to local Hive.
      DLog.warning('⚠️ Không thể migrate saved places cũ: $e');
    }
  }

  Future<void> _migrateLegacyCustomRoutes(
    String userId,
    CollectionReference target,
  ) async {
    final legacy = routesCollection;
    final fs = _fs;
    if (legacy == null || fs == null) return;

    try {
      final snapshot = await legacy.where('userId', isEqualTo: userId).get();
      if (snapshot.docs.isEmpty) return;

      final batch = fs.batch();
      var migratedCount = 0;
      for (final doc in snapshot.docs) {
        final raw = doc.data();
        if (raw is! Map) continue;
        final data = Map<String, dynamic>.from(raw);
        final routeId =
            (data['id'] ?? data['routeId'] ?? '').toString().trim();
        if (routeId.isEmpty) continue;

        data
          ..remove('userId')
          ..remove('routeId')
          ..remove('syncedAt')
          ..['id'] = routeId;
        final firestoreRoute =
            _encodeNestedArrayField(data, 'fullPolyline');
        batch.set(
          target.doc(_safeDocumentId(routeId)),
          firestoreRoute,
          SetOptions(merge: true),
        );
        batch.delete(doc.reference);
        migratedCount++;
      }

      if (migratedCount > 0) {
        await batch.commit();
        DLog.info(
            '☁️ Đã chuyển $migratedCount custom route vào users/$userId/routes');
      }
    } catch (e) {
      DLog.warning('⚠️ Không thể migrate custom routes cũ: $e');
    }
  }

  Future<void> _deleteQueryDocuments(CollectionReference collection) async {
    final snapshot = await collection.get();
    await _deleteDocuments(snapshot.docs);
  }

  Future<void> _deleteDocuments(List<QueryDocumentSnapshot> documents) async {
    final fs = _fs;
    if (fs == null || documents.isEmpty) return;
    const batchSize = 500;
    for (var start = 0; start < documents.length; start += batchSize) {
      final end = start + batchSize > documents.length
          ? documents.length
          : start + batchSize;
      final batch = fs.batch();
      for (final doc in documents.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  String _safeDocumentId(String value) =>
      base64UrlEncode(utf8.encode(value)).replaceAll('=', '');

  /// Firestore supports arrays, but it rejects an array directly containing
  /// another array. Route polylines are naturally represented as
  /// `List<List<double>>` locally, so keep that shape in Hive and store only
  /// the nested field as JSON in the user document.
  Map<String, dynamic> _encodeNestedArrayField(
    Map<String, dynamic> source,
    String field,
  ) {
    final data = Map<String, dynamic>.from(source);
    final value = data[field];
    if (value is List && value.any((item) => item is List)) {
      data['${field}Json'] = jsonEncode(value);
      // `set(..., merge: true)` would otherwise leave a stale legacy array
      // beside the JSON value and the reader could prefer that old value.
      data[field] = FieldValue.delete();
    }
    return data;
  }

  /// Restores the local model shape from the compact Firestore wire format.
  /// The fallback to the original field keeps older documents readable.
  Map<String, dynamic> _decodeNestedArrayField(
    Map<String, dynamic> source,
    String field,
  ) {
    final data = Map<String, dynamic>.from(source);
    final encoded = data.remove('${field}Json');
    if (data[field] == null && encoded is String && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) data[field] = decoded;
      } catch (e) {
        DLog.warning(
            '⚠️ Không thể giải mã trường $field từ Firestore: $e');
      }
    }
    return data;
  }

  // --- TRIP & STATS SYNC METHODS ---
  @override
  Future<void> syncTrip(String userId, TripRecordModel trip) async {
    if (_fs == null) {
      throw StateError('Cloud Firestore instance is not initialized.');
    }
    try {
      final userTrips = _fs!.collection('users').doc(userId).collection('trips');
      final tripMap = _encodeNestedArrayField(trip.toMap(), 'polyline');
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
      final userTrips = fs.collection('users').doc(userId).collection('trips');
      const int chunkSize = 500;

      for (int i = 0; i < trips.length; i += chunkSize) {
        final chunk = trips.sublist(
          i,
          (i + chunkSize > trips.length) ? trips.length : i + chunkSize,
        );

        final batch = fs.batch();
        for (final trip in chunk) {
          final tripMap = _encodeNestedArrayField(trip.toMap(), 'polyline');
          tripMap['isSynced'] = true;
          tripMap['syncedAt'] = FieldValue.serverTimestamp();
          batch.set(userTrips.doc(trip.id), tripMap, SetOptions(merge: true));
        }

        await batch.commit();

        for (final trip in chunk) {
          await updateDailyStats(userId, trip.startTime, trip);
        }
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
      return snapshot.docs
          .map((doc) => TripRecordModel.fromMap(
                _decodeNestedArrayField(doc.data(), 'polyline'),
              ))
          .toList();
    } catch (e) {
      DLog.error("Firestore getSyncedTrips error: $e");
      return [];
    }
  }
}
