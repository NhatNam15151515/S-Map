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
  })  : authRepos = authRepos ?? AuthReposImpl(),
        notiRepos = notiRepos ?? NotificationReposImpl(),
        poiRepos = poiRepos ?? PoiRepositoryImpl(),
        routingRepos = routingRepos ?? RoutingRepositoryImpl();

  static final AppReposProvider instance = AppReposProvider();
}
