import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/repos/repos.dart';

class AppReposProvider {
  final IAuthRepos authRepos;
  final INotificationRepos notiRepos;
  final IPoiRepository poiRepos;
  final IRoutingRepository routingRepos;

  AppReposProvider({
    IAuthRepos? authRepos,
    INotificationRepos? notiRepos,
    IPoiRepository? poiRepos,
    IRoutingRepository? routingRepos,
    IRoutingService? routingService,
  })  : authRepos = authRepos ?? AuthReposImpl(),
        notiRepos = notiRepos ?? NotificationReposImpl(),
        poiRepos = poiRepos ?? PoiRepositoryImpl(),
        routingRepos = routingRepos ?? _resolveRoutingRepos(routingService);

  static IRoutingRepository _resolveRoutingRepos(IRoutingService? routingService) {
    if (routingService == null) {
      throw ArgumentError(
        'Either routingRepos or routingService must be provided to AppReposProvider',
      );
    }
    return RoutingRepositoryImpl(routingService: routingService);
  }

  static AppReposProvider? _instance;
  static AppReposProvider get instance =>
      _instance ??
      (() {
        throw StateError(
          'AppReposProvider has not been initialized. Call AppReposProvider.init(routingService: ...) in main() or initialize an instance.',
        );
      })();

  static set instance(AppReposProvider provider) {
    _instance = provider;
  }

  static void init({
    required IRoutingService routingService,
    IAuthRepos? authRepos,
    INotificationRepos? notiRepos,
    IPoiRepository? poiRepos,
    IRoutingRepository? routingRepos,
  }) {
    _instance = AppReposProvider(
      routingService: routingService,
      authRepos: authRepos,
      notiRepos: notiRepos,
      poiRepos: poiRepos,
      routingRepos: routingRepos,
    );
  }
}
