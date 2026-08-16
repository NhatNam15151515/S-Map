import 'package:flutter/services.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/constants.dart';
import 'package:s_map/interfaces/interfaces.dart';
import 'package:s_map/models/models.dart';

class RoutingServiceImpl implements IRoutingService {
  final MethodChannel _channel;

  RoutingServiceImpl({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(RoutingConstants.channelName);

  static final RoutingServiceImpl instance = RoutingServiceImpl();

  @override
  Future<bool> initGraphHopper(String graphPath) async {
    DLog.info('⚡ [RoutingService] Invoking MethodChannel "${RoutingConstants.methodInitGraphHopper}" with path: "$graphPath"');
    try {
      final result = await _channel.invokeMethod<bool>(
        RoutingConstants.methodInitGraphHopper,
        {RoutingConstants.argGraphPath: graphPath},
      );
      DLog.info('⚡ [RoutingService] MethodChannel initGraphHopper result: $result');
      return result ?? false;
    } catch (e, stack) {
      DLog.error('❌ [RoutingService] initGraphHopper error: $e', e, stack);
      return false;
    }
  }

  @override
  Future<RouteResult> getRoute({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    String? vehicleProfile,
  }) async {
    final profile = vehicleProfile ?? RoutingConstants.defaultProfile;
    DLog.info('⚡ [RoutingService] Invoking MethodChannel "${RoutingConstants.methodGetRoute}" ($fromLat, $fromLon) -> ($toLat, $toLon) | profile: $profile');
    try {
      final rawResult = await _channel.invokeMethod<dynamic>(
        RoutingConstants.methodGetRoute,
        {
          RoutingConstants.argFromLat: fromLat,
          RoutingConstants.argFromLon: fromLon,
          RoutingConstants.argToLat: toLat,
          RoutingConstants.argToLon: toLon,
          RoutingConstants.argVehicleProfile: profile,
        },
      );

      if (rawResult is Map) {
        final parsed = RouteResult.fromMap(Map<String, dynamic>.from(rawResult));
        DLog.info('⚡ [RoutingService] MethodChannel getRoute SUCCESS: distance=${parsed.distance}m, time=${parsed.time}ms, points=${parsed.points.length}, isSuccess=${parsed.isSuccess}, error="${parsed.errorMessage}"');
        return parsed;
      }
      DLog.warning('⚠️ [RoutingService] MethodChannel getRoute returned non-map result: $rawResult');
      return RouteResult.failure(RoutingConstants.errNoRouteFound);
    } on PlatformException catch (e, stack) {
      DLog.error('❌ [RoutingService] getRoute PlatformException: [${e.code}] ${e.message}', e, stack);
      return RouteResult.failure(e.message ?? RoutingConstants.errPlatformChannel);
    } catch (e, stack) {
      DLog.error('❌ [RoutingService] getRoute error: $e', e, stack);
      return RouteResult.failure('${RoutingConstants.errPlatformChannel}: $e');
    }
  }

  @override
  Future<bool> isInitialized() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        RoutingConstants.methodIsInitialized,
      );
      DLog.info('⚡ [RoutingService] MethodChannel isInitialized result: $result');
      return result ?? false;
    } catch (e, stack) {
      DLog.error('❌ [RoutingService] isInitialized error: $e', e, stack);
      return false;
    }
  }

  @override
  Future<bool> dispose() async {
    DLog.info('⚡ [RoutingService] Invoking MethodChannel "${RoutingConstants.methodDisposeGraphHopper}"');
    try {
      final result = await _channel.invokeMethod<bool>(
        RoutingConstants.methodDisposeGraphHopper,
      );
      DLog.info('⚡ [RoutingService] MethodChannel dispose result: $result');
      return result ?? true;
    } catch (e, stack) {
      DLog.error('❌ [RoutingService] dispose error: $e', e, stack);
      return false;
    }
  }
}
