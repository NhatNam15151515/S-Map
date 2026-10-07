import 'dart:async';
import 'dart:math' as math;

import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/utils.dart';
import 'package:s_map/commons/validators/validator.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';
import 'package:s_map/search_engine/address/address.dart';
import 'package:s_map/search_engine/poi_search_query_support.dart';
import 'package:s_map/services/services.dart';
import 'package:sqflite/sqflite.dart';
part 'poi_search_repository.dart';
part 'poi_near_search_repository.dart';
part 'poi_spatial_repository.dart';
part 'poi_suggestion_repository.dart';
part 'poi_lookup_repository.dart';

abstract class _PoiRepositoryCore implements IPoiRepository {
  final IPoiDatabaseService _dbService;
  final Database? _directDb;
  final SearchCacheService _searchCache;
  final bool _cacheEnabled;
  final PoiSearchQuerySupport _querySupport = PoiSearchQuerySupport();
  int? _cachedSchemaVersion;

  static final Map<String, Future<List<PoiModel>>> _inFlightSearches = {};
  static final Map<String, Future<List<PoiModel>>> _inFlightBoundsSearches = {};
  static final Map<String, Future<List<String>>> _inFlightSuggestions = {};

  _PoiRepositoryCore({
    IPoiDatabaseService? dbService,
    Database? directDb,
    SearchCacheService? searchCache,
  }) : _dbService = dbService ?? PoiDatabaseServiceImpl.instance,
       _directDb = directDb,
       _searchCache = searchCache ?? SearchCacheService.instance,
       // Direct/custom databases are primarily used by tests or isolated
       // consumers. Do not let their data leak into the shared app cache.
       _cacheEnabled = directDb == null && dbService == null;

  Future<Database> _getDb() async {
    final direct = _directDb;
    if (direct != null && direct.isOpen) {
      return direct;
    }
    final dbInstance = _dbService.database;
    if (_dbService.isOpen && dbInstance != null) {
      return dbInstance;
    }
    return await _dbService.openDatabaseInstance();
  }
}

class PoiRepositoryImpl extends _PoiRepositoryCore
    with
        _PoiTextSearch,
        _PoiNearSearch,
        _PoiSpatialSearch,
        _PoiSuggestionSearch,
        _PoiAddressLookup
    implements IPoiRepository {
  PoiRepositoryImpl({super.dbService, super.directDb, super.searchCache});
}
