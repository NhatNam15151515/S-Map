import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:s_map/commons/blocs/blocs.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/interfaces/i_location_service.dart';
import 'package:s_map/repos/repos.dart';
import 'package:s_map/search_engine/search_engine.dart';
import 'package:s_map/services/services.dart';
import 'widgets/widgets.dart';

export 'package:s_map/models/search_screen_args.dart';

class SearchScreen extends StatefulWidget {
  final LatLng? userLocation;
  final bool hasExistingDestinations;
  final ILocationService? locationService;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.userLocation,
    this.hasExistingDestinations = false,
    this.locationService,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SearchBloc _searchBloc;
  late final ILocationService _locationService;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService.instance;
    final poiRepository = PoiRepositoryImpl();
    _searchBloc = SearchBloc(
      poiRepository: poiRepository,
      searchOrchestrator: SearchOrchestrator(
        poiRepository: poiRepository,
        trieIndexFuture: TrieIndex.tryLoadAsset(
          'assets/database/trie_index.bin',
        ),
      ),
      recentSearchService: RecentSearchServiceImpl.instance,
      userLocation: widget.userLocation,
    )..add(const SearchHistoryLoadRequested());

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      final q = widget.initialQuery!.trim();
      _searchBloc.add(SearchQueryChanged(q));
    }
  }

  @override
  void dispose() {
    _searchBloc.close();
    super.dispose();
  }

  Future<LatLng?> _acquireLocation() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      DLog.warning('⚠️ [SearchScreen] Could not acquire location: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _searchBloc,
      child: SearchScreenContent(
        hasExistingDestinations: widget.hasExistingDestinations,
        initialQuery: widget.initialQuery,
        onAcquireLocation: _acquireLocation,
      ),
    );
  }
}
