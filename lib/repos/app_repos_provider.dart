import 'package:s_map/repos/auth_repos.dart';
import 'package:s_map/repos/notification_repos.dart';

class AppReposProvider {
  final AuthRepos authRepos;
  final NotificationRepos notiRepos;

  AppReposProvider({
    AuthRepos? authRepos,
    NotificationRepos? notiRepos,
  })  : authRepos = authRepos ?? AuthReposImpl(),
        notiRepos = notiRepos ?? NotificationReposImpl();

  static final AppReposProvider instance = AppReposProvider();
}
