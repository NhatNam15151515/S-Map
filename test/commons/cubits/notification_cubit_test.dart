import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/models/models.dart';

void main() {
  group('NotificationCubit Tests', () {
    test('Initial state has 0 unread and showBadge is false', () {
      final cubit = NotificationCubit();
      expect(cubit.state.unReadSystem, 0);
      expect(cubit.state.unReadCustomer, 0);
      expect(cubit.state.unread, 0);
      expect(cubit.state.showBadge, false);
      cubit.close();
    });

    test('applyStats updates system notification count and showBadge', () {
      final cubit = NotificationCubit();
      cubit.applyStats(NotificationTab.system, 5);

      expect(cubit.state.unReadSystem, 5);
      expect(cubit.state.unReadCustomer, 0);
      expect(cubit.state.unread, 5);
      expect(cubit.state.showBadge, true);
      cubit.close();
    });

    test('applyStats updates customer notification count and showBadge', () {
      final cubit = NotificationCubit();
      cubit.applyStats(NotificationTab.customer, 3);

      expect(cubit.state.unReadSystem, 0);
      expect(cubit.state.unReadCustomer, 3);
      expect(cubit.state.unread, 3);
      expect(cubit.state.showBadge, true);
      cubit.close();
    });

    test('reset resets state to default initial', () {
      final cubit = NotificationCubit();
      cubit.applyStats(NotificationTab.system, 5);
      cubit.applyStats(NotificationTab.customer, 2);

      expect(cubit.state.unread, 7);

      cubit.reset();
      expect(cubit.state, const NotificationState());
      cubit.close();
    });
  });
}
