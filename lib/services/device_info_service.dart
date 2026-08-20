import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class DeviceInfoService implements IDeviceInfoService {
  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceInfoService({DeviceInfoPlugin? deviceInfoPlugin})
      : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  static final DeviceInfoService instance = DeviceInfoService();

  AndroidDeviceInfo? _cachedAndroidInfo;
  IosDeviceInfo? _cachedIosInfo;

  Future<AndroidDeviceInfo?> _getAndroidInfo() async {
    if (_cachedAndroidInfo != null) return _cachedAndroidInfo;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _cachedAndroidInfo = await _deviceInfoPlugin.androidInfo;
      } catch (e) {
        DLog.error('Lỗi khi lấy thông tin Android device: $e');
      }
    }
    return _cachedAndroidInfo;
  }

  Future<IosDeviceInfo?> _getIosInfo() async {
    if (_cachedIosInfo != null) return _cachedIosInfo;
    if (!kIsWeb && Platform.isIOS) {
      try {
        _cachedIosInfo = await _deviceInfoPlugin.iosInfo;
      } catch (e) {
        DLog.error('Lỗi khi lấy thông tin iOS device: $e');
      }
    }
    return _cachedIosInfo;
  }

  @override
  Future<bool> isAndroid() async => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> isIOS() async => !kIsWeb && Platform.isIOS;

  @override
  Future<String> getManufacturer() async {
    final androidInfo = await _getAndroidInfo();
    if (androidInfo != null) {
      return androidInfo.manufacturer;
    }
    if (!kIsWeb && Platform.isIOS) {
      return 'Apple';
    }
    return 'Unknown';
  }

  @override
  Future<String> getModel() async {
    final androidInfo = await _getAndroidInfo();
    if (androidInfo != null) {
      return androidInfo.model;
    }
    final iosInfo = await _getIosInfo();
    if (iosInfo != null) {
      return iosInfo.utsname.machine;
    }
    return 'Unknown';
  }

  @override
  Future<int> getAndroidSdkInt() async {
    final androidInfo = await _getAndroidInfo();
    if (androidInfo != null) {
      return androidInfo.version.sdkInt;
    }
    return 0;
  }

  @override
  Future<DeviceOemType> getDeviceOemType() async {
    if (!kIsWeb && Platform.isIOS) {
      return DeviceOemType.ios;
    }

    final androidInfo = await _getAndroidInfo();
    if (androidInfo == null) {
      return DeviceOemType.other;
    }

    final manufacturer = androidInfo.manufacturer.toLowerCase();
    final brand = androidInfo.brand.toLowerCase();

    if (manufacturer.contains('samsung') || brand.contains('samsung')) {
      return DeviceOemType.samsung;
    }
    if (manufacturer.contains('xiaomi') ||
        brand.contains('xiaomi') ||
        brand.contains('redmi') ||
        brand.contains('poco')) {
      return DeviceOemType.xiaomi;
    }
    if (manufacturer.contains('huawei') ||
        brand.contains('huawei') ||
        brand.contains('honor')) {
      return DeviceOemType.huawei;
    }
    if (manufacturer.contains('oppo') ||
        brand.contains('oppo') ||
        brand.contains('realme') ||
        brand.contains('oneplus')) {
      return DeviceOemType.oppo;
    }
    if (manufacturer.contains('vivo') ||
        brand.contains('vivo') ||
        brand.contains('iqoo')) {
      return DeviceOemType.vivo;
    }

    return DeviceOemType.genericAndroid;
  }
}
