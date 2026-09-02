import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/screens/main/home/widgets/widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MapExploreCubit _exploreCubit;
  late final ViewportSearchBloc _viewportBloc;
  NavigationBloc? _localNavigationBloc;

  @override
  void initState() {
    super.initState();
    _exploreCubit = MapExploreCubit()..watchExplorePlaces();
    _viewportBloc = ViewportSearchBloc();
  }

  @override
  void dispose() {
    _exploreCubit.close();
    _viewportBloc.close();
    _localNavigationBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    NavigationBloc navBloc;
    try {
      navBloc = context.read<NavigationBloc>();
    } catch (_) {
      navBloc = _localNavigationBloc ??= NavigationBloc(
        routingRepository: AppReposProvider.instance.routingRepos,
        tripRepository: AppReposProvider.instance.tripRepos,
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _exploreCubit),
        BlocProvider.value(value: _viewportBloc),
        BlocProvider.value(value: navBloc),
      ],
      child: const HomeScreenContent(),
    );
  }
}
