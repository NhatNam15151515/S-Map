import 'package:equatable/equatable.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

abstract class ViewportSearchEvent extends Equatable {
  const ViewportSearchEvent();

  @override
  List<Object?> get props => [];
}

/// Event phát ra khi viewport bản đồ thay đổi (pan/zoom idle) hoặc khi cần tự động tìm trong viewport
class SearchInViewportRequested extends ViewportSearchEvent {
  final LatLngBounds bounds;
  final String? category;
  final int limit;

  const SearchInViewportRequested(
    this.bounds, {
    this.category,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [bounds, category, limit];
}

/// Event phát ra khi người dùng chủ động nhấn nút "Tìm trong khu vực này"
class SearchThisAreaPressed extends ViewportSearchEvent {
  final LatLngBounds bounds;
  final String? category;
  final int limit;

  const SearchThisAreaPressed(
    this.bounds, {
    this.category,
    this.limit = 50,
  });

  @override
  List<Object?> get props => [bounds, category, limit];
}

/// Event phát ra khi chọn filter category trên thanh MapCategoryChips
class ViewportCategoryFilterChanged extends ViewportSearchEvent {
  final String category;
  final LatLngBounds? bounds;

  const ViewportCategoryFilterChanged(this.category, {this.bounds});

  @override
  List<Object?> get props => [category, bounds];
}

/// Event xóa kết quả tìm kiếm viewport
class ClearViewportSearch extends ViewportSearchEvent {
  const ClearViewportSearch();
}
