import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Chính sách phần cứng và dịch vụ chạy ngầm cho phiên dẫn đường
///
/// Quản lý:
/// - Battery optimization exemption (OEM aggressive kill)
/// - Keep Screen On (wakelock) — giữ màn hình sáng khi đang chỉ đường
/// - Notification permission (foreground service)
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

  // ============================================================
  // KEEP SCREEN ON — Giữ màn hình sáng khi đang chỉ đường
  // ============================================================
  // Giống Google Maps: khi bắt đầu navigation → màn hình không tắt.
  // Khi kết thúc navigation → trả lại quyền kiểm soát cho OS.
  // Hoạt động xuyên suốt lifecycle: dù user lock screen bằng nút
  // nguồn, khi mở lại vẫn thấy màn hình navigation (do foreground
  // service giữ app sống + wakelock giữ CPU active).

  /// Bật Keep Screen On — gọi khi bắt đầu phiên chỉ đường
  Future<void> enableKeepScreenOn() async {
    try {
      await WakelockPlus.enable();
      DLog.info('🔆 [DevicePolicy] Keep Screen On: ENABLED');
    } catch (e) {
      DLog.error('❌ [DevicePolicy] Failed to enable wakelock: $e');
    }
  }

  /// Tắt Keep Screen On — gọi khi kết thúc phiên chỉ đường
  Future<void> disableKeepScreenOn() async {
    try {
      await WakelockPlus.disable();
      DLog.info('🌙 [DevicePolicy] Keep Screen On: DISABLED');
    } catch (e) {
      DLog.error('❌ [DevicePolicy] Failed to disable wakelock: $e');
    }
  }
}

