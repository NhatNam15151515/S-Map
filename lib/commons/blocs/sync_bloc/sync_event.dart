import 'package:equatable/equatable.dart';

abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

/// Sự kiện bắt đầu đồng bộ các chuyến đi đang chờ lên Firestore
class SyncStarted extends SyncEvent {
  final String? userId;

  const SyncStarted({this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Sự kiện khi một chuyến đi mới được lưu và đưa vào hàng đợi
class SyncTripQueued extends SyncEvent {
  final String tripId;

  const SyncTripQueued(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

/// Sự kiện cập nhật số lượng chuyến đi đang chờ trong hàng đợi
class SyncQueueCountChanged extends SyncEvent {
  final int count;

  const SyncQueueCountChanged(this.count);

  @override
  List<Object?> get props => [count];
}

/// Sự kiện reset trạng thái sync về initial
class SyncReset extends SyncEvent {
  const SyncReset();
}
