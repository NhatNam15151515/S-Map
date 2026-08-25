import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/repos/repos.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  final INotificationRepos _notiRepos;

  NotificationCubit({INotificationRepos? notiRepos})
      : _notiRepos = notiRepos ?? AppReposProvider.instance.notiRepos,
        super(const NotificationState());

  @override
  void emit(NotificationState state) {
    if (isClosed) return;
    super.emit(state);
  }

  Future<void> loadSystemNotifications({bool refresh = false}) async {
    final page = refresh ? 1 : state.systemPage;
    if (!refresh && !state.hasMoreSystem && state.systemNotifications.isNotEmpty) {
      return;
    }

    emit(state.copyWith(
      systemStatus: NotificationStatus.loading,
      clearError: true,
    ));

    try {
      final (items, total) = await _notiRepos.getSystemNotification(
        page: page,
        limit: 10,
      );

      final updatedList = refresh
          ? items
          : [...state.systemNotifications, ...items];

      emit(state.copyWith(
        systemStatus: NotificationStatus.success,
        systemNotifications: updatedList,
        systemPage: page + 1,
        hasMoreSystem: items.length >= 10,
        unReadSystem: total,
      ));
    } catch (e) {
      emit(state.copyWith(
        systemStatus: NotificationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadCustomerNotifications({bool refresh = false}) async {
    final page = refresh ? 1 : state.customerPage;
    if (!refresh && !state.hasMoreCustomer && state.customerNotifications.isNotEmpty) {
      return;
    }

    emit(state.copyWith(
      customerStatus: NotificationStatus.loading,
      clearError: true,
    ));

    try {
      final (items, total) = await _notiRepos.getCustomerNotification(
        page: page,
        limit: 10,
      );

      final updatedList = refresh
          ? items
          : [...state.customerNotifications, ...items];

      emit(state.copyWith(
        customerStatus: NotificationStatus.success,
        customerNotifications: updatedList,
        customerPage: page + 1,
        hasMoreCustomer: items.length >= 10,
        unReadCustomer: total,
      ));
    } catch (e) {
      emit(state.copyWith(
        customerStatus: NotificationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadMore(NotificationTab tab) async {
    switch (tab) {
      case NotificationTab.system:
        if (!state.isSystemLoading && state.hasMoreSystem) {
          await loadSystemNotifications();
        }
        break;
      case NotificationTab.customer:
        if (!state.isCustomerLoading && state.hasMoreCustomer) {
          await loadCustomerNotifications();
        }
        break;
    }
  }

  Future<void> refresh(NotificationTab tab) async {
    switch (tab) {
      case NotificationTab.system:
        await loadSystemNotifications(refresh: true);
        break;
      case NotificationTab.customer:
        await loadCustomerNotifications(refresh: true);
        break;
    }
  }

  void applyStats(NotificationTab type, int? count) {
    final value = count ?? 0;
    switch (type) {
      case NotificationTab.system:
        emit(state.copyWith(unReadSystem: value));
        break;
      case NotificationTab.customer:
        emit(state.copyWith(unReadCustomer: value));
        break;
    }
  }

  void reset() {
    emit(const NotificationState());
  }
}
