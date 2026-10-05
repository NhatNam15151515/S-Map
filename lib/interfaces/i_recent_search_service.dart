abstract class IRecentSearchService {
  /// Lấy danh sách lịch sử tìm kiếm gần đây
  Future<List<String>> getRecentSearches();

  /// Thêm một từ khóa vào lịch sử tìm kiếm (đưa lên đầu, deduplicate)
  Future<void> addRecentSearch(String query);

  /// Xóa một từ khóa khỏi lịch sử tìm kiếm
  Future<void> removeRecentSearch(String query);

  /// Xóa toàn bộ lịch sử tìm kiếm
  Future<void> clearRecentSearches();
}
