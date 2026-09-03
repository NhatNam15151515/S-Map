import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class RoutingRepositoryImpl implements IRoutingRepository {
  final IRoutingService _routingService;
  Future<void>? _autoInitFuture;
  int _lifecycleSession = 0;
  int _activeInitSession = 0;

  RoutingRepositoryImpl({required IRoutingService routingService})
      : _routingService = routingService;

  @override
  Future<bool> initializeEngine(String graphPath) async {
    DLog.info(
        '🏛️ [RoutingRepository] Explicit initializeEngine called with: "$graphPath"');
    final targetSession = ++_lifecycleSession;
    _autoInitFuture = null;
    final success = await _routingService.initGraphHopper(graphPath);
    if (targetSession != _lifecycleSession) {
      if (_activeInitSession == 0) {
        await _routingService.dispose();
      }
      return false;
    }
    if (success) {
      _activeInitSession = targetSession;
    }
    return success;
  }

  /// Tự động tìm và nạp file đồ thị đường đi (.ghz hoặc thư mục giải nén) nếu có trên thiết bị
  Future<void> _ensureAutoInitialized() async {
    final isReady = await _routingService.isInitialized();
    if (isReady) return;

    _autoInitFuture ??= _ensureAutoInitializedImpl();
    await _autoInitFuture;

    final readyAfter = await _routingService.isInitialized();
    if (!readyAfter) {
      _autoInitFuture = null;
    }
  }


  Future<void> _ensureAutoInitializedImpl() async {
    DLog.info('🔍 [RoutingRepository] Executing _ensureAutoInitializedImpl');
    final currentSession = _lifecycleSession;
    try {
      final isReady = await _routingService.isInitialized();
      if (currentSession != _lifecycleSession) return;
      DLog.info(
          '🔍 [RoutingRepository] Current GraphHopper engine ready state: $isReady');
      if (isReady) return;

      Future<bool> tryInit(String path) async {
        if (currentSession != _lifecycleSession) return false;
        final success = await _routingService.initGraphHopper(path);
        if (currentSession != _lifecycleSession) {
          if (_activeInitSession == 0) {
            await _routingService.dispose();
          }
          return false;
        }
        if (success) {
          _activeInitSession = currentSession;
        }
        return success;
      }

      // Dọn dẹp dữ liệu metro_hcm cũ còn sót trên thiết bị (legacy cleanup)
      await _cleanupLegacyData();

      final candidateDirs = <String>[];
      try {
        final docDir = await getApplicationDocumentsDirectory();
        candidateDirs.add(docDir.path);
        DLog.info(
            '📂 [RoutingRepository] Candidate AppDocDir: "${docDir.path}"');
      } catch (e) {
        DLog.warning('⚠️ [RoutingRepository] Cannot get AppDocDir: $e');
      }

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          candidateDirs.add(extDir.path);
          DLog.info(
              '📂 [RoutingRepository] Candidate AppExtDir: "${extDir.path}"');
        }
      } catch (e) {
        DLog.warning('⚠️ [RoutingRepository] Cannot get AppExtDir: $e');
      }

      candidateDirs.addAll([
        '/sdcard/Android/data/com.vnsmap.app/files',
        '/storage/emulated/0/Android/data/com.vnsmap.app/files',
      ]);

      const candidateDirNames = [
        'regions/vietnam',
        'regions/vietnam/graphhopper',
        'vietnam_extracted',
        'vietnam-latest-gh',
        'graphhopper',
      ];

      const candidateFileNames = [
        'regions/vietnam/vietnam.ghz',
        'vietnam.ghz',
      ];

      DLog.info(
          '🔎 [RoutingRepository] Scanning ${candidateDirs.length} candidate directories for graph data...');
      for (final dirPath in candidateDirs) {
        // 1. Ưu tiên nạp thư mục graph đã giải nén sẵn
        for (final dirName in candidateDirNames) {
          final targetDir = Directory(p.join(dirPath, dirName));
          final exists = await targetDir.exists();
          if (exists) {
            final nodesFile = File(p.join(targetDir.path, 'nodes'));
            final hasNodes = await nodesFile.exists();
            
            // Đọc thông tin package version.json nếu có
            final versionFile = File(p.join(targetDir.path, 'version.json'))
                .existsSync() ? File(p.join(targetDir.path, 'version.json'))
                : File(p.join(targetDir.parent.path, 'version.json'));
            if (await versionFile.exists()) {
              try {
                final verContent = await versionFile.readAsString();
                DLog.info('📋 [RoutingRepository] Found version.json: $verContent');
              } catch (_) {}
            }

            // Đọc thông tin properties nếu có
            final propsFile = File(p.join(targetDir.path, 'properties'));
            if (await propsFile.exists()) {
              try {
                final propsBytes = await propsFile.readAsBytes();
                final propsText = String.fromCharCodes(propsBytes);
                final profileMatch = RegExp(r'profiles=([^\r\n\x00]+)').firstMatch(propsText);
                final dateMatch = RegExp(r'datareader\.import\.date=([^\r\n\x00]+)').firstMatch(propsText);
                DLog.info('📄 [RoutingRepository] Graph properties: profile=${profileMatch?.group(1) ?? 'N/A'}, importDate=${dateMatch?.group(1) ?? 'N/A'}');
              } catch (_) {}
            }

            DLog.info(
                '📁 [RoutingRepository] Found candidate folder: "${targetDir.path}" (has nodes file: $hasNodes)');
            if (hasNodes) {
              DLog.info(
                  '🚀 [RoutingRepository] Initializing GraphHopper with extracted folder: "${targetDir.path}"');
              final success = await tryInit(targetDir.path);
              DLog.info(
                  '🏁 [RoutingRepository] Folder init outcome: success=$success');
              if (success) {
                DLog.info('🎉 [RoutingRepository] GraphHopper READY & ROUTING ENABLED from: "${targetDir.path}"');
                return;
              }
            }
          }
        }

        // 2. Nếu không có thư mục sẵn, nạp file nén .ghz
        for (final name in candidateFileNames) {
          final file = File(p.join(dirPath, name));
          final exists = await file.exists();
          if (exists) {
            final size = await file.length();
            final sizeMb = (size / (1024 * 1024)).toStringAsFixed(2);
            DLog.info(
                '📦 [RoutingRepository] Found candidate .ghz file: "${file.path}" (size: $sizeMb MB, modified: ${file.lastModifiedSync()})');
            final success = await tryInit(file.path);
            DLog.info(
                '🏁 [RoutingRepository] .ghz file init outcome: success=$success');
            if (success) {
              DLog.info('🎉 [RoutingRepository] GraphHopper READY & ROUTING ENABLED from archive: "${file.path}"');
              return;
            }
          }
        }
      }

      // 3. Nếu không tìm thấy ở bất kỳ đâu trên bộ nhớ thiết bị, tự nạp từ Bundled Asset trong APK
      for (final bundledAsset in const [
        'assets/map/vietnam.ghz',
      ]) {
        DLog.info(
            '📦 [RoutingRepository] Attempting auto-init from bundled APK asset: "$bundledAsset"');
        final assetSuccess = await tryInit(bundledAsset);
        DLog.info(
            '🏁 [RoutingRepository] Bundled asset init outcome ($bundledAsset): success=$assetSuccess');
        if (assetSuccess) {
          DLog.info('🎉 [RoutingRepository] GraphHopper READY & ROUTING ENABLED from APK asset!');
          return;
        }
      }

      DLog.warning(
          '⚠️ [RoutingRepository] Scan completed: No valid GraphHopper graph data found or initialization failed on all candidates');
    } catch (e, stack) {
      DLog.error(
          '❌ [RoutingRepository] Auto-init check exception: $e', e, stack);
    }
  }

  @override
  Future<RouteResult> calculateRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    DLog.info(
        '🏍️ [RoutingRepository] calculateRoute requested: ($fromLat, $fromLon) -> ($toLat, $toLon) | profile: $vehicleProfile');
    await _ensureAutoInitialized();

    final isReady = await _routingService.isInitialized();
    DLog.info(
        '🏍️ [RoutingRepository] isEngineReady after auto-init check: $isReady');
    if (isReady) {
      final nativeResult = await _routingService.getRoute(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: toLat,
        toLon: toLon,
        vehicleProfile: vehicleProfile,
      );
      DLog.info(
          '🏍️ [RoutingRepository] Native route result status: isSuccess=${nativeResult.isSuccess}, distance=${nativeResult.distance}m, points=${nativeResult.points.length}, error="${nativeResult.errorMessage}"');
      return nativeResult;
    }

    DLog.warning(
        '⚠️ [RoutingRepository] Native GraphHopper not ready -> returning failure result');
    return RouteResult.failure(
      RoutingConstants.errServiceNotInitialized,
    );
  }

  @override
  Future<List<RouteResult>> calculateAlternativeRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    final primaryProfile = vehicleProfile ?? RoutingConstants.profileMopedVn;
    DLog.info(
        '🔀 [RoutingRepository] calculateAlternativeRoutes requested: ($fromLat, $fromLon) -> ($toLat, $toLon) | profile: $primaryProfile');

    // 1. Tính toán lộ trình chính (Primary Route)
    final primaryRoute = await calculateRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      vehicleProfile: primaryProfile,
    );

    if (!primaryRoute.isSuccess || !primaryRoute.hasPoints) {
      return [primaryRoute];
    }

    // 2. Tìm lộ trình thay thế (Alternative Route) bằng chiến lược Profile Duality
    // Xe máy (moped_vn) thử nghiệm đối trọng với Car profile (chọn đường lớn, đại lộ)
    // hoặc ngược lại để tìm một hướng di chuyển hoàn toàn khác biệt.
    final altProfile = (primaryProfile == RoutingConstants.profileMopedVn)
        ? RoutingConstants.profileCar
        : (primaryProfile == RoutingConstants.profileCar
            ? RoutingConstants.profileMopedVn
            : null);

    if (altProfile != null) {
      try {
        final altRoute = await calculateRoute(
          fromLat: fromLat,
          fromLon: fromLon,
          toLat: toLat,
          toLon: toLon,
          vehicleProfile: altProfile,
        );

        if (altRoute.isSuccess && altRoute.hasPoints) {
          final distanceDiff = (altRoute.distance - primaryRoute.distance).abs();
          // Kiểm tra xem lộ trình phụ có thực sự khác biệt không (chênh lệch quãng đường >= 3% hoặc số điểm polyline khác nhau)
          final isDistinct = distanceDiff > (primaryRoute.distance * 0.03) ||
              (altRoute.points.length != primaryRoute.points.length);

          if (isDistinct) {
            final namedPrimary = primaryRoute.copyWith(
              routeTitle: 'Nhanh nhất',
            );
            final namedAlt = altRoute.copyWith(
              routeTitle: altProfile == RoutingConstants.profileCar
                  ? 'Qua đại lộ chính'
                  : 'Đường tránh',
              isAlternative: true,
            );
            DLog.info(
                '✅ [RoutingRepository] Found distinct alternative route: Primary=${primaryRoute.distance}m vs Alt=${altRoute.distance}m');
            return [namedPrimary, namedAlt];
          }
        }
      } catch (e) {
        DLog.warning(
            '⚠️ [RoutingRepository] Failed to calculate alternative route: $e');
      }
    }

    return [primaryRoute.copyWith(routeTitle: 'Lộ trình tối ưu')];
  }

  @override
  Future<SnappedRoadPoint> snapToRoad({
    required double lat,
    required double lon,
  }) async {
    DLog.info('📍 [RoutingRepository] snapToRoad requested: ($lat, $lon)');
    await _ensureAutoInitialized();

    final isReady = await _routingService.isInitialized();
    if (isReady) {
      final snapResult = await _routingService.snapToRoad(
        lat: lat,
        lon: lon,
      );
      DLog.info(
          '📍 [RoutingRepository] Native snap result: isSnapped=${snapResult.isSnapped}, snapped=(${snapResult.snappedLat}, ${snapResult.snappedLon}), street="${snapResult.streetName}", dist=${snapResult.distanceToRoad}m');
      return snapResult;
    }

    DLog.warning(
        '💡 [RoutingRepository] Native GraphHopper not ready -> returning notSnapped fallback');
    return SnappedRoadPoint.notSnapped(
      originalLat: lat,
      originalLon: lon,
      errorMessage: RoutingConstants.errServiceNotInitialized,
    );
  }

  @override
  Future<bool> isEngineReady() async {
    final ready = await _routingService.isInitialized();
    if (ready) return true;
    await _ensureAutoInitialized();
    return _routingService.isInitialized();
  }

  @override
  Future<bool> dispose() {
    DLog.info('🧹 [RoutingRepository] dispose called');
    _lifecycleSession++;
    _activeInitSession = 0;
    _autoInitFuture = null;
    return _routingService.dispose();
  }

  /// Dọn dẹp dữ liệu legacy metro_hcm còn sót trên thiết bị từ các bản build cũ.
  /// Cũng xóa bản copy cũ của bundled asset (metro_hcm.ghz) trong filesDir/docDir.
  Future<void> _cleanupLegacyData() async {
    const legacyNames = [
      'metro_hcm.ghz',
      'metro_hcm_extracted',
      'metro_hcm',
    ];

    final dirsToClean = <String>[];
    try {
      final docDir = await getApplicationDocumentsDirectory();
      dirsToClean.add(docDir.path);
    } catch (_) {}
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) dirsToClean.add(extDir.path);
    } catch (_) {}

    // Thêm các path phổ biến trên Android
    dirsToClean.addAll([
      '/sdcard/Android/data/com.vnsmap.app/files',
      '/storage/emulated/0/Android/data/com.vnsmap.app/files',
    ]);

    for (final dirPath in dirsToClean) {
      for (final name in legacyNames) {
        try {
          final filePath = p.join(dirPath, name);
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete(recursive: true);
            DLog.info(
                '🗑️ [RoutingRepository] Deleted legacy file: "$filePath"');
          }
          final dir = Directory(filePath);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
            DLog.info(
                '🗑️ [RoutingRepository] Deleted legacy directory: "$filePath"');
          }
        } catch (e) {
          DLog.warning(
              '⚠️ [RoutingRepository] Failed to clean legacy "$name" in "$dirPath": $e');
        }
      }
    }
  }
}
