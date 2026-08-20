/// Enum định danh hãng sản xuất thiết bị để đưa ra hướng dẫn tối ưu pin phù hợp
enum DeviceOemType {
  samsung,
  xiaomi,
  huawei,
  oppo,
  vivo,
  genericAndroid,
  ios,
  other;

  bool get isSamsung => this == DeviceOemType.samsung;
  bool get isXiaomi => this == DeviceOemType.xiaomi;
  bool get isAggressiveOem =>
      this == DeviceOemType.samsung ||
      this == DeviceOemType.xiaomi ||
      this == DeviceOemType.huawei ||
      this == DeviceOemType.oppo ||
      this == DeviceOemType.vivo;
}
