import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/models/notification_model.dart';
import 'notification_state.dart';

class NotificationCubit extends Cubit<NotificationState> {
  NotificationCubit() : super(const NotificationState());

  @override
  void emit(NotificationState state) {
    if (isClosed) return;
    super.emit(state);
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
