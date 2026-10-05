import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/constants/constants.dart';

abstract class ViewportSearchEvent extends Equatable {
  const ViewportSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Event phát ra khi viewport bản đồ thay đổi (pan/zoom idle) hoặc khi cần tự động tìm trong viewport
class SearchInViewportRequested extends ViewportSearchEvent {
  final LatLngBounds bounds;
  final String? category;
  final String? query;
  final int limit;
  final DateTime createdAt;

  SearchInViewportRequested(
    this.bounds, {
    this.category,
    this.query,
    this.limit = 50,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  @override
  List<Object?> get props => [bounds, category, query, limit, createdAt];
}

/// Event phát ra khi người dùng chủ động nhấn nút "Tìm trong khu vực này"
class SearchThisAreaPressed extends ViewportSearchEvent {
  final LatLngBounds bounds;
  final String? category;
  final String? query;
  final int limit;

  const SearchThisAreaPressed(
    this.bounds, {
    this.category,
    this.query,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [bounds, category, query, limit];
}

/// Event phát ra khi chọn filter category trên thanh MapCategoryChips
class ViewportCategoryFilterChanged extends ViewportSearchEvent {
  final String category;
  final LatLngBounds? bounds;

  const ViewportCategoryFilterChanged(this.category, {this.bounds});

  @override
  List<Object?> get props => [category, bounds];
}

/// Tìm kiếm từ một tâm cố định và mở rộng location bias dần khi category
/// chưa có kết quả. Với text search, handler vẫn truy vấn ứng viên toàn cục
/// để location bias không trở thành giới hạn cứng như một bbox filter.
class ProgressiveAreaSearch extends ViewportSearchEvent {
  final LatLng center;
  final String? category;
  final String? query;
  final double initialZoom;
  final int limit;

  const ProgressiveAreaSearch({
    required this.center,
    this.category,
    this.query,
    this.initialZoom = MapConstants.areaSearchInitialZoom,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [center, category, query, initialZoom, limit];
}

/// Event xóa kết quả tìm kiếm viewport
class ClearViewportSearch extends ViewportSearchEvent {
  const ClearViewportSearch();
}
