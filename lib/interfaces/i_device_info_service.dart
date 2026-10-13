import 'package:s_map/models/models.dart';

abstract class IDeviceInfoService {
  Future<DeviceOemType> getDeviceOemType();
  Future<String> getManufacturer();
  Future<String> getModel();
  Future<int> getAndroidSdkInt();
  Future<bool> isAndroid();
  Future<bool> isIOS();
}
