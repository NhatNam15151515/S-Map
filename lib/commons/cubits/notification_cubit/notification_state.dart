import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

enum NotificationStatus { initial, loading, success, error }

class NotificationState extends Equatable {
  final NotificationStatus systemStatus;
  final NotificationStatus customerStatus;
  final List<NotificationModel> systemNotifications;
  final List<NotificationModel> customerNotifications;
  final int unReadSystem;
  final int unReadCustomer;
  final int systemPage;
  final int customerPage;
  final bool hasMoreSystem;
  final bool hasMoreCustomer;
  final String? errorMessage;

  const NotificationState({
    this.systemStatus = NotificationStatus.initial,
    this.customerStatus = NotificationStatus.initial,
    this.systemNotifications = const [],
    this.customerNotifications = const [],
    this.unReadSystem = 0,
    this.unReadCustomer = 0,
    this.systemPage = 1,
    this.customerPage = 1,
    this.hasMoreSystem = true,
    this.hasMoreCustomer = true,
    this.errorMessage,
  });

  int get unread => unReadSystem + unReadCustomer;
  bool get showBadge => unread > 0;
  bool get isSystemLoading => systemStatus == NotificationStatus.loading;
  bool get isCustomerLoading => customerStatus == NotificationStatus.loading;
  bool get isSystemEmpty =>
      systemStatus == NotificationStatus.success && systemNotifications.isEmpty;
  bool get isCustomerEmpty =>
      customerStatus == NotificationStatus.success && customerNotifications.isEmpty;

  NotificationState copyWith({
    NotificationStatus? systemStatus,
    NotificationStatus? customerStatus,
    List<NotificationModel>? systemNotifications,
    List<NotificationModel>? customerNotifications,
    int? unReadSystem,
    int? unReadCustomer,
    int? systemPage,
    int? customerPage,
    bool? hasMoreSystem,
    bool? hasMoreCustomer,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationState(
      systemStatus: systemStatus ?? this.systemStatus,
      customerStatus: customerStatus ?? this.customerStatus,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      customerNotifications:
          customerNotifications ?? this.customerNotifications,
      unReadSystem: unReadSystem ?? this.unReadSystem,
      unReadCustomer: unReadCustomer ?? this.unReadCustomer,
      systemPage: systemPage ?? this.systemPage,
      customerPage: customerPage ?? this.customerPage,
      hasMoreSystem: hasMoreSystem ?? this.hasMoreSystem,
      hasMoreCustomer: hasMoreCustomer ?? this.hasMoreCustomer,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        systemStatus,
        customerStatus,
        systemNotifications,
        customerNotifications,
        unReadSystem,
        unReadCustomer,
        systemPage,
        customerPage,
        hasMoreSystem,
        hasMoreCustomer,
        errorMessage,
      ];
}
