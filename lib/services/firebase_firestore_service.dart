import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/i_firebase_firestore_service.dart';
import 'package:s_map/models/notification_model.dart';
import 'package:s_map/models/place_model.dart';
import 'package:s_map/models/user.dart';

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
}
