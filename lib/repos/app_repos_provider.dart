import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/services/services.dart';

class AppReposProvider {
  final IAuthRepos authRepos;
  final INotificationRepos notiRepos;
  final IPoiRepository poiRepos;
  final IRoutingRepository routingRepos;
  final ICustomRouteRepository customRouteRepos;
  final ITripRepository tripRepos;

  AppReposProvider({
    IAuthRepos? authRepos,
    INotificationRepos? notiRepos,
    IPoiRepository? poiRepos,
    IRoutingRepository? routingRepos,
    ICustomRouteRepository? customRouteRepos,
    ITripRepository? tripRepos,
    IRoutingService? routingService,
  })  : authRepos = authRepos ?? AuthReposImpl(),
        notiRepos = notiRepos ?? NotificationReposImpl(),
        poiRepos = poiRepos ?? PoiRepositoryImpl(),
        customRouteRepos = customRouteRepos ??
            CustomRouteRepositoryImpl(
              customRouteService: CustomRouteServiceImpl.instance,
            ),
        tripRepos = tripRepos ??
            TripRepositoryImpl(
              tripService: TripServiceImpl.instance,
            ),
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
  static bool get isInitialized => _instance != null;

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
    ICustomRouteRepository? customRouteRepos,
    ITripRepository? tripRepos,
  }) {
    _instance = AppReposProvider(
      routingService: routingService,
      authRepos: authRepos,
      notiRepos: notiRepos,
      poiRepos: poiRepos,
      routingRepos: routingRepos,
      customRouteRepos: customRouteRepos,
      tripRepos: tripRepos,
    );
  }
}
