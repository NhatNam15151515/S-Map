import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'map_explore_state.dart';


class MapExploreCubit extends Cubit<MapExploreState> {
  final IFireStoreService _fireStoreService;
  StreamSubscription<List<PlaceModel>>? _placesSubscription;

  /// Global service resolver set during app bootstrap
  static IFireStoreService? defaultFireStoreService;

  MapExploreCubit({IFireStoreService? fireStoreService})
      : _fireStoreService = fireStoreService ?? defaultFireStoreService ?? _NoOpFireStoreService(),
        super(const MapExploreState());


  @override
  void emit(MapExploreState state) {
    if (isClosed) return;
    super.emit(state);
  }

  void selectCategory(String category) {
    if (state.selectedCategory == category && !state.isLoading) return;
    emit(state.copyWith(
      selectedCategory: category,
      status: MapExploreStatus.loading,
    ));
    watchExplorePlaces(category: category);
  }

  void watchExplorePlaces({String? category}) {
    _placesSubscription?.cancel();
    emit(state.copyWith(status: MapExploreStatus.loading));

    final targetCategory = category ?? state.selectedCategory;
    final filter = targetCategory == CategoryConstants.all ? null : targetCategory;

    _placesSubscription = _fireStoreService
        .streamExplorePlaces(category: filter)
        .listen(
      (places) {
        emit(state.copyWith(
          status: MapExploreStatus.loaded,
          places: places,
          clearError: true,
        ));
      },
      onError: (err) {
        DLog.error('Lỗi nạp địa điểm khám phá: $err');
        emit(state.copyWith(
          status: MapExploreStatus.error,
          errorMessage: err.toString(),
        ));
      },
    );
  }

  @override
  Future<void> close() async {
    await _placesSubscription?.cancel();
    return super.close();
  }
}

class _NoOpFireStoreService implements IFireStoreService {
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


