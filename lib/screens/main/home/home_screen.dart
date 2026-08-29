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
  late final MapDisplayCubit _mapCubit;
  late final MapExploreCubit _exploreCubit;
  late final ViewportSearchBloc _viewportBloc;
  late final RoutePreviewCubit _routePreviewCubit;
  late final NavigationBloc _navigationBloc;

  @override
  void initState() {
    super.initState();
    _mapCubit = MapDisplayCubit();
    _exploreCubit = MapExploreCubit()..watchExplorePlaces();


    _viewportBloc = ViewportSearchBloc();
    _routePreviewCubit = RoutePreviewCubit(
      routingRepository: AppReposProvider.instance.routingRepos,
    );
    _navigationBloc = NavigationBloc(
      routingRepository: AppReposProvider.instance.routingRepos,
      tripRepository: AppReposProvider.instance.tripRepos,
    );
  }

  @override
  void dispose() {
    _mapCubit.close();
    _exploreCubit.close();
    _viewportBloc.close();
    _routePreviewCubit.close();
    _navigationBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _mapCubit),
        BlocProvider.value(value: _exploreCubit),
        BlocProvider.value(value: _viewportBloc),
        BlocProvider.value(value: _routePreviewCubit),
        BlocProvider.value(value: _navigationBloc),
      ],
      child: const HomeScreenContent(),
    );
  }
}
