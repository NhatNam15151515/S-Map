import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

/// Chính sách phần cứng và dịch vụ chạy ngầm cho phiên dẫn đường
class NavigationDevicePolicy {
  final ILocationService _locationService;
  final IDeviceInfoService _deviceInfoService;

  const NavigationDevicePolicy({
    required ILocationService locationService,
    required IDeviceInfoService deviceInfoService,
  })  : _locationService = locationService,
        _deviceInfoService = deviceInfoService;

  /// Kiểm tra xem thiết bị có thuộc nhóm OEM hung hãn (aggressive kill app) cần nhắc người dùng không
  Future<DeviceOemType?> checkBatteryOptimizationPrompt() async {
    try {
      final isIgnored = await _locationService.isBatteryOptimizationIgnored();
      if (!isIgnored) {
        final oemType = await _deviceInfoService.getDeviceOemType();
        if (oemType.isAggressiveOem) {
          return oemType;
        }
      }
    } catch (e) {
      DLog.error('Lỗi kiểm tra battery optimization: $e');
    }
    return null;
  }

  Future<void> requestIgnoreBatteryOptimization() async {
    try {
      await _locationService.requestIgnoreBatteryOptimization();
    } catch (e) {
      DLog.error('Lỗi khi request ignore battery optimization: $e');
    }
  }

  Future<void> requestNotificationPermission() async {
    await _locationService.requestNotificationPermission();
  }
}
