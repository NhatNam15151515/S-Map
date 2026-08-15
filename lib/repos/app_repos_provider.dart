import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/services/services.dart';

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
        routingRepos = routingRepos ??
            RoutingRepositoryImpl(
              routingService: routingService ?? RoutingServiceImpl.instance,
            );

  static final AppReposProvider instance = AppReposProvider();
}
