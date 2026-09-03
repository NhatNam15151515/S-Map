import 'package:equatable/equatable.dart';
import 'package:s_map/models/models.dart';

abstract class RouteDrawingEvent extends Equatable {
  const RouteDrawingEvent();

  @override
  List<Object?> get props => [];
}

/// Người dùng tap một điểm tọa độ trên bản đồ để thêm waypoint
class RouteDrawingPointTapped extends RouteDrawingEvent {
  final double lat;
  final double lon;
  final bool? isStraightLine;

  const RouteDrawingPointTapped({
    required this.lat,
    required this.lon,
    this.isStraightLine,
  });

  @override
  List<Object?> get props => [lat, lon, isStraightLine];
}

/// Bật / Tắt chế độ vẽ đường chim bay (Direct Line / As-the-crow-flies Mode)
class RouteDrawingToggleStraightLineMode extends RouteDrawingEvent {
  const RouteDrawingToggleStraightLineMode();
}

/// Khởi tạo cặp điểm đầu/cuối trong một transaction.
/// Dùng cho luồng chọn endpoint để tránh hai event snap async huỷ lẫn nhau.
class RouteDrawingEndpointsSelected extends RouteDrawingEvent {
  final RoutePoint origin;
  final RoutePoint? destination;

  const RouteDrawingEndpointsSelected({
    required this.origin,
    this.destination,
  });

  @override
  List<Object?> get props => [origin, destination];
}

/// Hoàn tác (Undo) điểm vừa thêm gần nhất
class RouteDrawingUndoLastPoint extends RouteDrawingEvent {
  const RouteDrawingUndoLastPoint();
}

/// Khôi phục (Redo) điểm vừa hoàn tác
class RouteDrawingRedoPoint extends RouteDrawingEvent {
  const RouteDrawingRedoPoint();
}

/// Xóa toàn bộ lộ trình đang vẽ và đưa state về ban đầu
class RouteDrawingClearRoute extends RouteDrawingEvent {
  const RouteDrawingClearRoute();
}

/// Lưu lộ trình tùy biến vào Hive Storage
class RouteDrawingSaveRoute extends RouteDrawingEvent {
  final String? name;
  final String? description;

  const RouteDrawingSaveRoute({this.name, this.description});

  @override
  List<Object?> get props => [name, description];
}

/// Nạp lại lộ trình tùy biến đã lưu
class RouteDrawingLoadRoute extends RouteDrawingEvent {
  final CustomRouteModel route;

  const RouteDrawingLoadRoute(this.route);

  @override
  List<Object?> get props => [route];
}

/// Đảo chiều toàn bộ lộ trình đang vẽ (từ A -> B thành B -> A)
class RouteDrawingReverseRoute extends RouteDrawingEvent {
  const RouteDrawingReverseRoute();
}

/// Thay đổi cấu hình phương tiện dẫn đường (xe máy, ô tô, đi bộ)
class RouteDrawingChangeProfile extends RouteDrawingEvent {
  final String profile;

  const RouteDrawingChangeProfile(this.profile);

  @override
  List<Object?> get props => [profile];
}

