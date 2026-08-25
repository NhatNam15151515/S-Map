import 'package:sqflite/sqflite.dart';

abstract class IPoiDatabaseService {
  /// Khởi tạo và mở database POI (read-only)
  Future<Database> openDatabaseInstance({String? customPath});

  /// Lấy instance database hiện tại nếu đã mở
  Database? get database;

  /// Đóng kết nối database
  Future<void> close();

  /// Kiểm tra database đã mở chưa
  bool get isOpen;
}
