import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/commons/enums/enums.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class FakeNotificationRepos implements INotificationRepos {
  List<NotificationModel> systemList = [];
  List<NotificationModel> customerList = [];
  bool shouldThrow = false;

  @override
  Future<(List<NotificationModel>, int)> getSystemNotification({
    int page = 1,
    int limit = 10,
  }) async {
    if (shouldThrow) throw Exception('Fetch system notifications failed');
    return (systemList, systemList.length);
  }

  @override
  Future<(List<NotificationModel>, int)> getCustomerNotification({
    int page = 1,
    int limit = 10,
  }) async {
    if (shouldThrow) throw Exception('Fetch customer notifications failed');
    return (customerList, customerList.length);
  }
}

void main() {
  final sampleNoti1 = NotificationModel(
    id: '1',
    content: 'Cập nhật bản đồ phiên bản mới',
    notiType: NotificationType.system,
  );
  final sampleNoti2 = NotificationModel(
    id: '2',
    content: 'Bạn có thông báo mới',
    notiType: NotificationType.general,
  );

  late FakeNotificationRepos fakeRepo;
  late NotificationCubit cubit;

  setUp(() {
    fakeRepo = FakeNotificationRepos();
    cubit = NotificationCubit(notiRepos: fakeRepo);
  });

  tearDown(() {
    cubit.close();
  });

  group('NotificationCubit Tests', () {
    test('Initial state has 0 unread and showBadge is false', () {
      expect(cubit.state.unReadSystem, 0);
      expect(cubit.state.unReadCustomer, 0);
      expect(cubit.state.unread, 0);
      expect(cubit.state.showBadge, false);
      expect(cubit.state.systemStatus, NotificationStatus.initial);
      expect(cubit.state.customerStatus, NotificationStatus.initial);
    });

    test('loadSystemNotifications fetches system notifications successfully', () async {
      fakeRepo.systemList = [sampleNoti1];

      await cubit.loadSystemNotifications();

      expect(cubit.state.systemStatus, NotificationStatus.success);
      expect(cubit.state.systemNotifications, [sampleNoti1]);
      expect(cubit.state.unReadSystem, 1);
      expect(cubit.state.showBadge, true);
    });

    test('loadCustomerNotifications fetches customer notifications successfully', () async {
      fakeRepo.customerList = [sampleNoti2];

      await cubit.loadCustomerNotifications();

      expect(cubit.state.customerStatus, NotificationStatus.success);
      expect(cubit.state.customerNotifications, [sampleNoti2]);
      expect(cubit.state.unReadCustomer, 1);
      expect(cubit.state.showBadge, true);
    });

    test('loadSystemNotifications handles error state', () async {
      fakeRepo.shouldThrow = true;

      await cubit.loadSystemNotifications();

      expect(cubit.state.systemStatus, NotificationStatus.error);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('applyStats updates notification count and showBadge', () {
      cubit.applyStats(NotificationTab.system, 5);
      expect(cubit.state.unReadSystem, 5);
      expect(cubit.state.unread, 5);
      expect(cubit.state.showBadge, true);

      cubit.applyStats(NotificationTab.customer, 3);
      expect(cubit.state.unReadCustomer, 3);
      expect(cubit.state.unread, 8);
    });

    test('reset resets state to default initial', () {
      cubit.applyStats(NotificationTab.system, 5);
      cubit.applyStats(NotificationTab.customer, 2);

      expect(cubit.state.unread, 7);

      cubit.reset();
      expect(cubit.state, const NotificationState());
    });
  });
}
