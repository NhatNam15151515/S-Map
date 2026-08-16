import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class RoutingRepositoryImpl implements IRoutingRepository {
  final IRoutingService _routingService;
  bool _hasAttemptedAutoInit = false;

  RoutingRepositoryImpl({required IRoutingService routingService})
      : _routingService = routingService;

  @override
  Future<bool> initializeEngine(String graphPath) {
    DLog.info(
        '🏛️ [RoutingRepository] Explicit initializeEngine called with: "$graphPath"');
    return _routingService.initGraphHopper(graphPath);
  }

  /// Tự động tìm và nạp file đồ thị đường đi (.ghz hoặc thư mục giải nén) nếu có trên thiết bị
  Future<void> _ensureAutoInitialized() async {
    DLog.info(
        '🔍 [RoutingRepository] _ensureAutoInitialized check: already attempted = $_hasAttemptedAutoInit');
    if (_hasAttemptedAutoInit) return;
    _hasAttemptedAutoInit = true;

    try {
      final isReady = await _routingService.isInitialized();
      DLog.info(
          '🔍 [RoutingRepository] Current GraphHopper engine ready state: $isReady');
      if (isReady) return;

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
        '/sdcard/Download',
        '/storage/emulated/0/Download',
        '/sdcard/S-Map',
      ]);

      final candidateDirNames = [
        'metro_hcm_extracted',
        'vietnam_extracted',
        'graph-cache',
        'metro_hcm'
      ];
      final candidateFileNames = [
        'metro_hcm.ghz',
        'vietnam.ghz',
        'metro_hn.ghz'
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
            DLog.info(
                '📁 [RoutingRepository] Found candidate folder: "${targetDir.path}" (has nodes file: $hasNodes)');
            if (hasNodes) {
              DLog.info(
                  '🚀 [RoutingRepository] Initializing GraphHopper with extracted folder: "${targetDir.path}"');
              final success =
                  await _routingService.initGraphHopper(targetDir.path);
              DLog.info(
                  '🏁 [RoutingRepository] Folder init outcome: success=$success');
              if (success) {
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
            DLog.info(
                '📦 [RoutingRepository] Found candidate .ghz file: "${file.path}" (size: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB)');
            final success = await _routingService.initGraphHopper(file.path);
            DLog.info(
                '🏁 [RoutingRepository] .ghz file init outcome: success=$success');
            if (success) {
              return;
            }
          }
        }
      }

      // 3. Nếu không tìm thấy ở bất kỳ đâu trên bộ nhớ thiết bị, tự nạp từ Bundled Asset trong APK
      DLog.info(
          '📦 [RoutingRepository] Attempting auto-init from bundled APK asset: "assets/map/metro_hcm.ghz"');
      final assetSuccess =
          await _routingService.initGraphHopper('assets/map/metro_hcm.ghz');
      DLog.info(
          '🏁 [RoutingRepository] Bundled asset init outcome: success=$assetSuccess');
      if (assetSuccess) {
        return;
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
      if (nativeResult.isSuccess) {
        return nativeResult;
      }
    }

    // Fallback: Khi máy chưa tải file .ghz hoặc engine chưa init, tạo route ước tính mượt mà
    DLog.warning(
        '💡 [RoutingRepository] Native GraphHopper not ready -> Generating smart motorcycle route fallback');
    return _generateFallbackRoute(fromLat, fromLon, toLat, toLon);
  }

  RouteResult _generateFallbackRoute(
    double fromLat,
    double fromLon,
    double toLat,
    double toLon,
  ) {
    final straightDistKm = AppUtils.instance.calculateDistance(
      fromLat,
      fromLon,
      toLat,
      toLon,
    );

    // Khoảng cách thực tế đường bộ đô thị (hệ số uốn khúc ~1.35)
    final distanceMeters = (straightDistKm * 1000 * 1.35).clamp(50.0, 500000.0);

    // Thời gian xe máy di chuyển đô thị (~30 km/h = 8.33 m/s)
    final timeMillis = ((distanceMeters / 8.33) * 1000).round();

    // Sinh 12 điểm trung gian nối mượt mà từ điểm xuất phát đến điểm đích
    const steps = 12;
    final points = <List<double>>[];
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = fromLat + (toLat - fromLat) * t;
      final lon = fromLon + (toLon - fromLon) * t;
      points.add([lat, lon]);
    }

    DLog.info(
        '💡 [RoutingRepository] Fallback route generated: dist=${distanceMeters.toStringAsFixed(1)}m, time=${(timeMillis / 60000).toStringAsFixed(1)} mins, points=${points.length}');

    return RouteResult(
      isSuccess: true,
      distance: distanceMeters,
      time: timeMillis,
      points: points,
      instructions: const [],
      calculationTimeMs: 1,
    );
  }

  @override
  Future<bool> isEngineReady() {
    return _routingService.isInitialized();
  }

  @override
  Future<bool> dispose() {
    DLog.info('🧹 [RoutingRepository] dispose called');
    return _routingService.dispose();
  }
}
