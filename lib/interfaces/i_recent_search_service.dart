abstract class IRecentSearchService {
  /// Lấy danh sách lịch sử tìm kiếm gần đây
  Future<List<String>> getRecentSearches();

  /// Lấy các truy vấn người dùng tìm thường xuyên, nhiều nhất trước.
  Future<List<String>> getFrequentSearches({int limit = 10});

  /// Thêm một từ khóa vào lịch sử tìm kiếm (đưa lên đầu, deduplicate)
  Future<void> addRecentSearch(
    String query, {
    Map<String, dynamic>? destination,
  });

  /// Xóa một từ khóa khỏi lịch sử tìm kiếm
  Future<void> removeRecentSearch(String query);

  /// Xóa toàn bộ lịch sử tìm kiếm
  Future<void> clearRecentSearches();
}
