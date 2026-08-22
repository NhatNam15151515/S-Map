import 'package:equatable/equatable.dart';

abstract class RouteDrawingEvent extends Equatable {
  const RouteDrawingEvent();

  @override
  List<Object?> get props => [];
}

/// Người dùng tap một điểm tọa độ trên bản đồ để thêm waypoint
class RouteDrawingPointTapped extends RouteDrawingEvent {
  final double lat;
  final double lon;

  const RouteDrawingPointTapped({
    required this.lat,
    required this.lon,
  });

  @override
  List<Object?> get props => [lat, lon];
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

/// Lưu lộ trình tùy biến (chuẩn bị tích hợp Hive Storage ở Issue 27)
class RouteDrawingSaveRoute extends RouteDrawingEvent {
  final String? name;

  const RouteDrawingSaveRoute({this.name});

  @override
  List<Object?> get props => [name];
}
