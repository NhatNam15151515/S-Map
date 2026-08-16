/// Quản lý tập trung toàn bộ Route Paths của ứng dụng.
/// Tránh hardcode chuỗi đường dẫn và không định nghĩa path rải rác trong từng Widget Screen.
abstract final class AppRoutes {
  static const String initial = '/InitialScreen';
  static const String login = '/LoginScreen';
  static const String home = '/HomeScreen';
  static const String search = '/search';
  static const String saved = '/SavedScreen';
  static const String notification = '/NotificationScreen';
  static const String user = '/UserScreen';
  static const String navigation = '/NavigationScreen';
  static const String routeDrawing = '/RouteDrawingScreen';
  static const String stats = '/StatsScreen';
  static const String settings = '/SettingsScreen';
  static const String fullImage = '/FullImageScreen';
}
