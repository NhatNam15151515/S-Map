import 'package:equatable/equatable.dart';

enum SyncStatus {
  initial,
  syncing,
  success,
  failure,
}

class SyncState extends Equatable {
  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final List<String> syncedTripIds;

  const SyncState({
    this.status = SyncStatus.initial,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
    this.syncedTripIds = const [],
  });

  bool get isInitial => status == SyncStatus.initial;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get isSuccess => status == SyncStatus.success;
  bool get isFailure => status == SyncStatus.failure;

  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
    List<String>? syncedTripIds,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      syncedTripIds: syncedTripIds ?? this.syncedTripIds,
    );
  }

  @override
  List<Object?> get props => [
        status,
        pendingCount,
        lastSyncedAt,
        errorMessage,
        syncedTripIds,
      ];
}
