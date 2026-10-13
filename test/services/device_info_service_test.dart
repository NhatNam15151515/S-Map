import 'package:flutter_test/flutter_test.dart';
import 'package:s_map/commons/fallbacks/fallbacks.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/services/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceOemType Model Tests', () {
    test('DeviceOemType properties identify aggressive OEMs correctly', () {
      expect(DeviceOemType.samsung.isSamsung, isTrue);
      expect(DeviceOemType.samsung.isAggressiveOem, isTrue);

      expect(DeviceOemType.xiaomi.isXiaomi, isTrue);
      expect(DeviceOemType.xiaomi.isAggressiveOem, isTrue);

      expect(DeviceOemType.huawei.isAggressiveOem, isTrue);
      expect(DeviceOemType.oppo.isAggressiveOem, isTrue);
      expect(DeviceOemType.vivo.isAggressiveOem, isTrue);

      expect(DeviceOemType.genericAndroid.isAggressiveOem, isFalse);
      expect(DeviceOemType.ios.isAggressiveOem, isFalse);
      expect(DeviceOemType.other.isAggressiveOem, isFalse);
    });
  });

  group('DeviceInfoService / Fallbacks Tests', () {
    test('NoOpDeviceInfoService returns safe defaults', () async {
      const fallback = NoOpDeviceInfoService();

      expect(await fallback.getDeviceOemType(), equals(DeviceOemType.genericAndroid));
      expect(await fallback.getManufacturer(), equals('MockManufacturer'));
      expect(await fallback.getModel(), equals('MockModel'));
      expect(await fallback.getAndroidSdkInt(), equals(34));
      expect(await fallback.isAndroid(), isTrue);
      expect(await fallback.isIOS(), isFalse);
    });

    test('DeviceInfoService instance exists and initializes', () {
      final service = DeviceInfoService.instance;
      expect(service, isNotNull);
    });
  });
}
