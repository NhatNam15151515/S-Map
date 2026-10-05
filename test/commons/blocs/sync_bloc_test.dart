import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/blocs/sync_bloc/sync_bloc.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class MockSyncRepositoryForBloc implements ISyncRepository {
  List<String> queued = [];
  final StreamController<int> _queueStreamController =
      StreamController<int>.broadcast();
  int syncCallCount = 0;
  Duration delay = Duration.zero;
  bool shouldThrow = false;

  @override
  Future<List<String>> syncPendingTrips(String userId) async {
    syncCallCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (shouldThrow) {
      throw Exception('Network disconnected');
    }
    final synced = List<String>.from(queued);
    queued.clear();
    _queueStreamController.add(0);
    return synced;
  }

  @override
  Future<void> enqueueTripForSync(String tripId) async {
    if (!queued.contains(tripId)) {
      queued.add(tripId);
      _queueStreamController.add(queued.length);
    }
  }

  @override
  Future<int> getPendingSyncCount() async => queued.length;

  @override
  Stream<int> watchPendingSyncCount() => _queueStreamController.stream;
}

class MockAuthServiceForBloc implements IFirebaseAuthService {
  @override
  fb.User? get currentUser => null;

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<User?> signInAnonymously() async => null;

  @override
  Future<void> signOut() async {}
}

class MockAuthReposForBloc implements IAuthRepos {
  bool anonCalled = false;

  @override
  Future<User?> login(String username, String password) async => null;

  @override
  Future<User?> signInWithGoogle() async => null;

  @override
  Future<User?> signInAnonymously() async {
    anonCalled = true;
    return User(id: 'anon_user_999', username: 'Khách_999');
  }

  @override
  Future<User?> getProfile() async => null;

  @override
  Future<User?> updateProfile(User user) async => user;

  @override
  Future<bool> logout() async => true;
}

void main() {
  late MockSyncRepositoryForBloc mockSyncRepo;
  late MockAuthServiceForBloc mockAuthService;
  late MockAuthReposForBloc mockAuthRepos;
  late SyncBloc syncBloc;

  setUp(() {
    mockSyncRepo = MockSyncRepositoryForBloc();
    mockAuthService = MockAuthServiceForBloc();
    mockAuthRepos = MockAuthReposForBloc();

    syncBloc = SyncBloc(
      syncRepository: mockSyncRepo,
      authService: mockAuthService,
      authRepos: mockAuthRepos,
    );
  });

  tearDown(() async {
    await syncBloc.close();
  });

  group('SyncBloc Tests', () {
    test('initial state has status initial and pendingCount 0', () {
      expect(syncBloc.state.status, SyncStatus.initial);
      expect(syncBloc.state.pendingCount, 0);
    });

    test('SyncTripQueued increases pendingCount and adds trip to repository queue', () async {
      syncBloc.add(const SyncTripQueued('trip_101'));
      await Future.delayed(const Duration(milliseconds: 20));

      expect(syncBloc.state.pendingCount, 1);
      expect(mockSyncRepo.queued, contains('trip_101'));
    });

    test('Acceptance Criteria: Offline queue 3 trips -> trigger SyncStarted -> sync all 3 trips successfully', () async {
      // 1. Tích lũy 3 trips offline
      syncBloc.add(const SyncTripQueued('trip_1'));
      syncBloc.add(const SyncTripQueued('trip_2'));
      syncBloc.add(const SyncTripQueued('trip_3'));
      await Future.delayed(const Duration(milliseconds: 30));
      expect(syncBloc.state.pendingCount, 3);

      // 2. Trigger SyncStarted (có mạng trở lại)
      syncBloc.add(const SyncStarted());
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Kết quả: status success, pendingCount 0, tất cả 3 trip đã được sync
      expect(syncBloc.state.status, SyncStatus.success);
      expect(syncBloc.state.pendingCount, 0);
      expect(syncBloc.state.syncedTripIds, ['trip_1', 'trip_2', 'trip_3']);
      expect(syncBloc.state.lastSyncedAt, isNotNull);
      expect(mockAuthRepos.anonCalled, isTrue);
    });

    test('Acceptance Criteria: droppable() transformer drops duplicate concurrent sync requests', () async {
      mockSyncRepo.delay = const Duration(milliseconds: 100);
      syncBloc.add(const SyncTripQueued('trip_1'));
      await Future.delayed(const Duration(milliseconds: 20));

      // Gửi 3 sự kiện SyncStarted liên tiếp trong khi sự kiện 1 đang chạy
      syncBloc.add(const SyncStarted());
      syncBloc.add(const SyncStarted());
      syncBloc.add(const SyncStarted());
      await Future.delayed(const Duration(milliseconds: 15));

      expect(syncBloc.state.status, SyncStatus.syncing);

      // Chờ hoàn thành
      await Future.delayed(const Duration(milliseconds: 150));

      expect(syncBloc.state.status, SyncStatus.success);
      // droppable() đảm bảo syncPendingTrips chỉ được gọi đúng 1 lần
      expect(mockSyncRepo.syncCallCount, 1);
    });

    test('SyncStarted on empty queue emits success without calling backend', () async {
      syncBloc.add(const SyncStarted());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(syncBloc.state.status, SyncStatus.success);
      expect(syncBloc.state.pendingCount, 0);
      expect(mockSyncRepo.syncCallCount, 0);
    });

    test('SyncStarted failure emits failure state with error message and preserves pending count', () async {
      syncBloc.add(const SyncTripQueued('trip_fail'));
      await Future.delayed(const Duration(milliseconds: 20));

      mockSyncRepo.shouldThrow = true;
      syncBloc.add(const SyncStarted());
      await Future.delayed(const Duration(milliseconds: 30));

      expect(syncBloc.state.status, SyncStatus.failure);
      expect(syncBloc.state.errorMessage, contains('Network disconnected'));
      expect(syncBloc.state.pendingCount, 1);
    });

    test('SyncReset resets state back to initial', () async {
      syncBloc.add(const SyncTripQueued('trip_reset'));
      await Future.delayed(const Duration(milliseconds: 20));

      syncBloc.add(const SyncReset());
      await Future.delayed(const Duration(milliseconds: 20));

      expect(syncBloc.state.status, SyncStatus.initial);
      expect(syncBloc.state.pendingCount, 0);
    });
  });
}
