import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/cubits/cubits.dart';
import 'package:s_map/services/services.dart';
import 'widgets/widgets.dart';

class SearchScreen extends StatefulWidget {
  final LatLng? userLocation;

  const SearchScreen({super.key, this.userLocation});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SearchCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchCubit = SearchCubit(
      recentSearchService: RecentSearchServiceImpl.instance,
      userLocation: widget.userLocation,
    )..loadRecentSearches();
  }

  @override
  void dispose() {
    _searchCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _searchCubit,
      child: const SearchScreenContent(),
    );
  }
}
