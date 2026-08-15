import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/repos/repos.dart';

class AppReposProvider {
  final IAuthRepos authRepos;
  final INotificationRepos notiRepos;
  final IPoiRepository poiRepos;

  AppReposProvider({
    IAuthRepos? authRepos,
    INotificationRepos? notiRepos,
    IPoiRepository? poiRepos,
  })  : authRepos = authRepos ?? AuthReposImpl(),
        notiRepos = notiRepos ?? NotificationReposImpl(),
        poiRepos = poiRepos ?? PoiRepositoryImpl();

  static final AppReposProvider instance = AppReposProvider();
}
