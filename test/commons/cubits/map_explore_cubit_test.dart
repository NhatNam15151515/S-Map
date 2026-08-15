import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

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

    test('Initial state is initial with default category all and does not fetch until triggered', () {
      final cubit = MapExploreCubit(fireStoreService: mockService);
      expect(cubit.state.status, MapExploreStatus.initial);
      expect(cubit.state.selectedCategory, CategoryConstants.all);
      expect(cubit.state.places, isEmpty);
      cubit.close();
    });

    test('watchExplorePlaces changes status to loading and emits loaded state on stream data', () async {
      final cubit = MapExploreCubit(fireStoreService: mockService);
      cubit.watchExplorePlaces();
      expect(cubit.state.status, MapExploreStatus.loading);

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

      cubit.selectCategory(CategoryConstants.food);
      expect(cubit.state.selectedCategory, CategoryConstants.food);
      expect(cubit.state.status, MapExploreStatus.loading);

      cubit.close();
    });

    test('Handles stream error gracefully', () async {
      final cubit = MapExploreCubit(fireStoreService: mockService);
      cubit.watchExplorePlaces();

      mockService.emitError(Exception('Firestore network error'));
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.status, MapExploreStatus.error);
      expect(cubit.state.errorMessage, contains('Firestore network error'));
      cubit.close();
    });
  });
}
