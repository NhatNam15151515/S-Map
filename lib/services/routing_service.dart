import 'package:flutter/services.dart';
import 'package:s_map/commons/log/log.dart';
import 'package:s_map/constants/routing_constants.dart';
import 'package:s_map/interfaces/i_routing_service.dart';
import 'package:s_map/models/models.dart';

class RoutingServiceImpl implements IRoutingService {
  final MethodChannel _channel;

  RoutingServiceImpl({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(RoutingConstants.channelName);

  static final RoutingServiceImpl instance = RoutingServiceImpl();

  @override
  Future<bool> initGraphHopper(String graphPath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        RoutingConstants.methodInitGraphHopper,
        {RoutingConstants.argGraphPath: graphPath},
      );
      return result ?? false;
    } catch (e, stack) {
      DLog.error('RoutingServiceImpl.initGraphHopper error', e, stack);
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
    try {
      final rawResult = await _channel.invokeMethod<dynamic>(
        RoutingConstants.methodGetRoute,
        {
          RoutingConstants.argFromLat: fromLat,
          RoutingConstants.argFromLon: fromLon,
          RoutingConstants.argToLat: toLat,
          RoutingConstants.argToLon: toLon,
          RoutingConstants.argVehicleProfile:
              vehicleProfile ?? RoutingConstants.defaultProfile,
        },
      );

      if (rawResult is Map) {
        return RouteResult.fromMap(Map<String, dynamic>.from(rawResult));
      }
      return RouteResult.failure(RoutingConstants.errNoRouteFound);
    } on PlatformException catch (e, stack) {
      DLog.error('RoutingServiceImpl.getRoute PlatformException: ${e.message}', e, stack);
      return RouteResult.failure(e.message ?? RoutingConstants.errPlatformChannel);
    } catch (e, stack) {
      DLog.error('RoutingServiceImpl.getRoute error', e, stack);
      return RouteResult.failure('${RoutingConstants.errPlatformChannel}: $e');
    }
  }

  @override
  Future<bool> isInitialized() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        RoutingConstants.methodIsInitialized,
      );
      return result ?? false;
    } catch (e, stack) {
      DLog.error('RoutingServiceImpl.isInitialized error', e, stack);
      return false;
    }
  }

  @override
  Future<bool> dispose() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        RoutingConstants.methodDisposeGraphHopper,
      );
      return result ?? true;
    } catch (e, stack) {
      DLog.error('RoutingServiceImpl.dispose error', e, stack);
      return false;
    }
  }
}
