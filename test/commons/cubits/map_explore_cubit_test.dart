import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/map_explore_cubit/map_explore_cubit.dart';
import 'package:s_map/commons/cubits/map_explore_cubit/map_explore_state.dart';
import 'package:s_map/interfaces/i_firebase_firestore_service.dart';
import 'package:s_map/models/notification_model.dart';
import 'package:s_map/models/place_model.dart';
import 'package:s_map/models/user.dart';

class MockFireStoreService implements IFireStoreService {
  final _placesStreamController = StreamController<List<PlaceModel>>.broadcast();

  void emitPlaces(List<PlaceModel> places) {
    _placesStreamController.add(places);
  }

  void emitError(Object error) {
    _placesStreamController.addError(error);
  }

  @override
  Stream<List<PlaceModel>> streamExplorePlaces({String? category, int limit = 10}) {
    return _placesStreamController.stream;
  }

  @override
  Future<List<PlaceModel>> getExplorePlaces({String? category, int limit = 10}) async => [];

  @override
  Future<User?> getUserProfile(String userId) async => null;

  @override
  Future<void> saveUserProfile(User user) async {}

  @override
  Future<List<NotificationModel>> getNotifications({int limit = 20}) async => [];

  @override
  Future<void> savePlace(String userId, Map<String, dynamic> placeData) async {}

  @override
  Stream<QuerySnapshot?> streamSavedPlaces(String userId) => const Stream.empty();

  @override
  CollectionReference? get notificationsCollection => null;
  @override
  CollectionReference? get placesCollection => null;
  @override
  CollectionReference? get routesCollection => null;
  @override
  CollectionReference? get savedPlacesCollection => null;
  @override
  CollectionReference? get usersCollection => null;

  void dispose() {
    _placesStreamController.close();
  }
}

void main() {
  group('MapExploreCubit Tests', () {
    late MockFireStoreService mockService;

    setUp(() {
      mockService = MockFireStoreService();
    });

    tearDown(() {
      mockService.dispose();
    });

    test('Initial state starts with loading and default category', () {
      final cubit = MapExploreCubit(fireStoreService: mockService);
      expect(cubit.state.status, MapExploreStatus.loading);
      expect(cubit.state.selectedCategory, 'Tất cả');
      expect(cubit.state.places, isEmpty);
      cubit.close();
    });

    test('Emits loaded state when stream receives place models', () async {
      final cubit = MapExploreCubit(fireStoreService: mockService);

      const dummyPlace = PlaceModel(
        id: 'place_1',
        title: 'Quán Cafe S-Map',
        latitude: 10.762622,
        longitude: 106.660172,
        category: 'Cà phê',
      );

      mockService.emitPlaces([dummyPlace]);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.status, MapExploreStatus.loaded);
      expect(cubit.state.places.length, 1);
      expect(cubit.state.places.first.title, 'Quán Cafe S-Map');
      cubit.close();
    });

    test('selectCategory updates category and requests fresh stream', () async {
      final cubit = MapExploreCubit(fireStoreService: mockService);

      cubit.selectCategory('Ăn uống');
      expect(cubit.state.selectedCategory, 'Ăn uống');
      expect(cubit.state.status, MapExploreStatus.loading);

      cubit.close();
    });

    test('Handles stream error gracefully', () async {
      final cubit = MapExploreCubit(fireStoreService: mockService);

      mockService.emitError(Exception('Firestore network error'));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.status, MapExploreStatus.error);
      expect(cubit.state.errorMessage, contains('Firestore network error'));
      cubit.close();
    });
  });
}
