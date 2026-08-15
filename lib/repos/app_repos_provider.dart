import 'package:s_map/interfaces/i_auth_repos.dart';
import 'package:s_map/interfaces/i_notification_repos.dart';
import 'package:s_map/interfaces/i_poi_repository.dart';
import 'package:s_map/repos/auth_repos.dart';
import 'package:s_map/repos/notification_repos.dart';
import 'package:s_map/repos/poi_repository.dart';

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
