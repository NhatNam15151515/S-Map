import 'package:equatable/equatable.dart';

class NotificationState extends Equatable {
  final int unReadSystem;
  final int unReadCustomer;

  const NotificationState({
    this.unReadSystem = 0,
    this.unReadCustomer = 0,
  });

  int get unread => unReadSystem + unReadCustomer;
  bool get showBadge => unread > 0;

  NotificationState copyWith({
    int? unReadSystem,
    int? unReadCustomer,
  }) {
    return NotificationState(
      unReadSystem: unReadSystem ?? this.unReadSystem,
      unReadCustomer: unReadCustomer ?? this.unReadCustomer,
    );
  }

  @override
  List<Object?> get props => [unReadSystem, unReadCustomer];
}
