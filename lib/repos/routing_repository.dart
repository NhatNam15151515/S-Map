import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/commons/utils/app_utils.dart';
import 'package:s_map/commons/utils/map_geometry_utils.dart';
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
    // S-Map chuyên dụng cho xe máy (moped_vn), mọi yêu cầu điều hướng đều dùng profile này
    const effectiveProfile = RoutingConstants.profileMopedVn;
    DLog.info(
        '🏍️ [RoutingRepository] calculateRoute requested: ($fromLat, $fromLon) -> ($toLat, $toLon) | profile: $effectiveProfile (requested: $vehicleProfile)');
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
        vehicleProfile: effectiveProfile,
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

    // 2. Tìm lộ trình thay thế (Alternative Route):
    // Hệ thống chỉ hỗ trợ chuyên dụng xe máy (moped_vn), sử dụng chiến lược
    // Waypoint Perturbation (Tìm đường song song/đường tránh qua snapToRoad)
    final altRoute = await _findAlternativeViaPointRoute(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      primaryRoute: primaryRoute,
      profile: primaryProfile,
    );

    if (altRoute != null) {
      final namedPrimary = primaryRoute.copyWith(
        routeTitle: 'Nhanh nhất',
      );
      DLog.info(
          '✅ [RoutingRepository] Found distinct alternative route: Primary=${primaryRoute.distance}m vs Alt=${altRoute.distance}m (${altRoute.routeTitle})');
      return [namedPrimary, altRoute];
    }

    return [primaryRoute.copyWith(routeTitle: 'Lộ trình tối ưu')];
  }

  /// Tìm lộ trình thay thế bằng chiến lược Waypoint Perturbation.
  /// Lấy điểm dọc lộ trình chính, chiếu pháp tuyến vuông góc sang 2 bên để tìm
  /// đường song song/đường tránh qua `snapToRoad`, sau đó tính lộ trình 2 chặng:
  /// Start -> ViaPoint và ViaPoint -> Destination rồi ghép lại.
  Future<RouteResult?> _findAlternativeViaPointRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    required RouteResult primaryRoute,
    required String profile,
  }) async {
    final points = primaryRoute.points;
    if (points.length < 8 || primaryRoute.distance < 400.0) {
      return null;
    }

    // Thử các vị trí lấy mẫu dọc theo lộ trình: 50% (giữa), 40%, 60%
    final sampleRatios = [0.5, 0.4, 0.6];
    // Thử các độ lệch sang 2 bên đường (mét): ±250m, ±450m, ±650m
    final offsets = [250.0, -250.0, 450.0, -450.0, 650.0, -650.0];

    for (final ratio in sampleRatios) {
      final midIndex =
          (points.length * ratio).round().clamp(1, points.length - 2);
      final midPoint = points[midIndex];
      final step = math.max(1, (points.length * 0.05).round());
      final prevPoint = points[math.max(0, midIndex - step)];
      final nextPoint = points[math.min(points.length - 1, midIndex + step)];

      final dLat = nextPoint[0] - prevPoint[0];
      final dLon = nextPoint[1] - prevPoint[1];
      final latRad = midPoint[0] * MapGeometryUtils.degToRad;
      final cosLat = math.cos(latRad);

      final dY = dLat * MapGeometryUtils.metersPerDegreeLat;
      final dX = dLon * MapGeometryUtils.metersPerDegreeLat * cosLat;
      final len = math.sqrt(dX * dX + dY * dY);
      if (len < 10.0) continue;

      // Vector pháp tuyến vuông góc
      final normX = -dY / len;
      final normY = dX / len;

      for (final offset in offsets) {
        final candLat =
            midPoint[0] + (normY * offset) / MapGeometryUtils.metersPerDegreeLat;
        final candLon = midPoint[1] +
            (normX * offset) / (MapGeometryUtils.metersPerDegreeLat * cosLat);

        try {
          final snapped = await snapToRoad(lat: candLat, lon: candLon);
          if (!snapped.isSnapped) continue;

          // Đảm bảo điểm snap cách đường cũ ít nhất 70m để không đi lại trùng đường cũ
          final distKm = AppUtils.instance.calculateDistance(
            midPoint[0],
            midPoint[1],
            snapped.snappedLat,
            snapped.snappedLon,
          );
          if (distKm * 1000.0 < 70.0) continue;

          // Tính 2 chặng: Start -> ViaPoint và ViaPoint -> End
          final leg1 = await calculateRoute(
            fromLat: fromLat,
            fromLon: fromLon,
            toLat: snapped.snappedLat,
            toLon: snapped.snappedLon,
            vehicleProfile: profile,
          );
          if (!leg1.isSuccess || !leg1.hasPoints) continue;

          final leg2 = await calculateRoute(
            fromLat: snapped.snappedLat,
            fromLon: snapped.snappedLon,
            toLat: toLat,
            toLon: toLon,
            vehicleProfile: profile,
          );
          if (!leg2.isSuccess || !leg2.hasPoints) continue;

          // BỘ LỌC QUAN TRỌNG: Phát hiện & từ chối nhánh cụt quay đầu (Backtracking / U-turn spur)
          if (_hasBacktrackingSpur(leg1.points, leg2.points)) {
            DLog.info(
                '↩️ [RoutingRepository] Rejecting via-point candidate at ($candLat, $candLon) due to backtracking spur');
            continue;
          }

          final totalDist = leg1.distance + leg2.distance;
          final totalTime = leg1.time + leg2.time;

          // Lộ trình thay thế hợp lý: không dài hơn 1.45 lần đường chính
          // và phải có sự khác biệt (quãng đường lệch >= 3% hoặc khác số lượng điểm)
          final distanceDiff = (totalDist - primaryRoute.distance).abs();
          final isDistinct = distanceDiff > (primaryRoute.distance * 0.03) ||
              ((leg1.points.length + leg2.points.length) !=
                  primaryRoute.points.length);

          if (!isDistinct || totalDist > primaryRoute.distance * 1.45) {
            continue;
          }

          // Ghép 2 chặng thành 1 lộ trình thay thế hoàn chỉnh
          final combinedPoints = <List<double>>[
            ...leg1.points,
            if (leg2.points.length > 1) ...leg2.points.sublist(1),
          ];

          // Làm sạch Turn-by-Turn instructions khi ghép lộ trình
          final cleanedLeg1Instructions = leg1.instructions.isNotEmpty &&
                  (leg1.instructions.last.sign == 4 ||
                      leg1.instructions.last.text.toLowerCase().contains('đến'))
              ? leg1.instructions.sublist(0, leg1.instructions.length - 1)
              : leg1.instructions;

          final cleanedLeg2Instructions = leg2.instructions.isNotEmpty &&
                  leg2.instructions.first.sign == 0 &&
                  cleanedLeg1Instructions.isNotEmpty
              ? leg2.instructions.sublist(1)
              : leg2.instructions;

          final combinedInstructions = <RouteInstruction>[
            ...cleanedLeg1Instructions,
            ...cleanedLeg2Instructions,
          ];

          // Xác định tiêu đề lộ trình thay thế có ý nghĩa
          final rawStreet = snapped.streetName.trim();
          final isAlleyName = rawStreet.toLowerCase().startsWith('hẻm') ||
              rawStreet.toLowerCase().startsWith('ngõ') ||
              rawStreet.toLowerCase().startsWith('đường nội bộ');

          String title;
          if (rawStreet.isNotEmpty && !isAlleyName) {
            title = 'Qua $rawStreet';
          } else {
            final prominentStreet =
                _findProminentStreetName(combinedInstructions);
            title = prominentStreet != null
                ? 'Qua $prominentStreet'
                : 'Đường tránh';
          }

          return RouteResult(
            isSuccess: true,
            distance: totalDist,
            time: totalTime,
            points: combinedPoints,
            instructions: combinedInstructions,
            routeTitle: title,
            isAlternative: true,
          );
        } catch (_) {
          continue;
        }
      }
    }

    return null;
  }

  /// Kiểm tra xem điểm nối giữa leg1 và leg2 có tạo thành nhánh cụt quay đầu (Backtracking Spur) hay không.
  ///
  /// 1. Retracing Check: leg2 đi lùi lại các toạ độ trước đó của leg1 để thoát ra đường lớn.
  /// 2. Sharp U-turn Check: Góc giữa vector tới via-point và vector rời đi > 105° (cosAngle < -0.25).
  bool _hasBacktrackingSpur(
    List<List<double>> leg1Points,
    List<List<double>> leg2Points,
  ) {
    if (leg1Points.length < 2 || leg2Points.length < 2) return false;

    // 1. Retracing Check: leg2 có đi lùi lại các toạ độ trước đó của leg1 không?
    final checkCount1 = math.min(12, leg1Points.length - 1);
    final checkCount2 = math.min(12, leg2Points.length - 1);

    for (int i = 1; i <= checkCount1; i++) {
      final p = leg1Points[leg1Points.length - 1 - i];
      for (int j = 1; j <= checkCount2; j++) {
        final q = leg2Points[j];
        final dist =
            MapGeometryUtils.haversineDistanceMeters(p[0], p[1], q[0], q[1]);
        if (dist < 18.0) {
          DLog.info(
              '⚠️ [RoutingRepository] Detected backtracking retraced point: ${dist.toStringAsFixed(1)}m (< 18m)');
          return true;
        }
      }
    }

    // 2. Sharp U-turn Check:
    final endPoint = leg1Points.last;
    List<double>? inPoint;
    for (int i = leg1Points.length - 2; i >= 0; i--) {
      final p = leg1Points[i];
      final d = MapGeometryUtils.haversineDistanceMeters(
          p[0], p[1], endPoint[0], endPoint[1]);
      if (d >= 15.0 || i == 0) {
        inPoint = p;
        break;
      }
    }

    final startPoint = leg2Points.first;
    List<double>? outPoint;
    for (int i = 1; i < leg2Points.length; i++) {
      final q = leg2Points[i];
      final d = MapGeometryUtils.haversineDistanceMeters(
          q[0], q[1], startPoint[0], startPoint[1]);
      if (d >= 15.0 || i == leg2Points.length - 1) {
        outPoint = q;
        break;
      }
    }

    if (inPoint != null && outPoint != null) {
      final latRad = endPoint[0] * MapGeometryUtils.degToRad;
      final cosLat = math.cos(latRad);

      final inDy =
          (endPoint[0] - inPoint[0]) * MapGeometryUtils.metersPerDegreeLat;
      final inDx =
          (endPoint[1] - inPoint[1]) * MapGeometryUtils.metersPerDegreeLat * cosLat;
      final inLen = math.sqrt(inDx * inDx + inDy * inDy);

      final outDy =
          (outPoint[0] - startPoint[0]) * MapGeometryUtils.metersPerDegreeLat;
      final outDx = (outPoint[1] - startPoint[1]) *
          MapGeometryUtils.metersPerDegreeLat *
          cosLat;
      final outLen = math.sqrt(outDx * outDx + outDy * outDy);

      if (inLen > 1.0 && outLen > 1.0) {
        final cosAngle = (inDx * outDx + inDy * outDy) / (inLen * outLen);
        if (cosAngle < -0.25) {
          DLog.info(
              '⚠️ [RoutingRepository] Detected sharp U-turn at via-point: cosAngle = ${cosAngle.toStringAsFixed(2)}');
          return true;
        }
      }
    }

    return false;
  }

  /// Trích xuất tên đường lớn xuất hiện dài nhất trong danh sách instructions
  String? _findProminentStreetName(List<RouteInstruction> instructions) {
    String? bestStreet;
    double maxDist = 0;
    for (final ins in instructions) {
      final name = ins.streetName.trim();
      if (name.isNotEmpty &&
          !name.toLowerCase().startsWith('hẻm') &&
          !name.toLowerCase().startsWith('ngõ') &&
          !name.toLowerCase().startsWith('đường nội bộ') &&
          ins.distance > maxDist) {
        maxDist = ins.distance;
        bestStreet = name;
      }
    }
    return bestStreet;
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
