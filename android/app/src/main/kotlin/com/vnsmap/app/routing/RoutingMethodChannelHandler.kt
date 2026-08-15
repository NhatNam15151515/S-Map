package com.vnsmap.app.routing

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class RoutingMethodChannelHandler(
    private val routingService: IGraphHopperService = GraphHopperService.instance
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            RoutingConstants.METHOD_INIT_GRAPH_HOPPER -> handleInitGraphHopper(call, result)
            RoutingConstants.METHOD_GET_ROUTE -> handleGetRoute(call, result)
            RoutingConstants.METHOD_IS_INITIALIZED -> handleIsInitialized(result)
            RoutingConstants.METHOD_DISPOSE_GRAPH_HOPPER -> handleDisposeGraphHopper(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitGraphHopper(call: MethodCall, result: MethodChannel.Result) {
        val graphPath = call.argument<String>(RoutingConstants.ARG_GRAPH_PATH)
        if (graphPath.isNullOrBlank()) {
            result.error(
                RoutingConstants.ERR_CODE_INVALID_ARGUMENTS,
                "Missing or blank '${RoutingConstants.ARG_GRAPH_PATH}' argument",
                null
            )
            return
        }

        try {
            val success = routingService.init(graphPath)
            result.success(success)
        } catch (e: Exception) {
            result.error(
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Failed to initialize GraphHopper: ${e.message}",
                null
            )
        }
    }

    private fun handleGetRoute(call: MethodCall, result: MethodChannel.Result) {
        val fromLat = call.argument<Number>(RoutingConstants.ARG_FROM_LAT)?.toDouble()
        val fromLon = call.argument<Number>(RoutingConstants.ARG_FROM_LON)?.toDouble()
        val toLat = call.argument<Number>(RoutingConstants.ARG_TO_LAT)?.toDouble()
        val toLon = call.argument<Number>(RoutingConstants.ARG_TO_LON)?.toDouble()
        val vehicleProfile = call.argument<String>(RoutingConstants.ARG_VEHICLE_PROFILE)
            ?: RoutingConstants.DEFAULT_PROFILE

        if (fromLat == null || fromLon == null || toLat == null || toLon == null) {
            result.error(
                RoutingConstants.ERR_CODE_INVALID_ARGUMENTS,
                "Coordinates (fromLat, fromLon, toLat, toLon) must all be provided and valid numbers",
                null
            )
            return
        }

        try {
            val routeResult = routingService.route(fromLat, fromLon, toLat, toLon, vehicleProfile)
            result.success(routeResult.toMap())
        } catch (e: Exception) {
            result.error(
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Error calculating route: ${e.message}",
                null
            )
        }
    }

    private fun handleIsInitialized(result: MethodChannel.Result) {
        try {
            val initialized = routingService.isInitialized()
            result.success(initialized)
        } catch (e: Exception) {
            result.error(
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Failed to check initialization status: ${e.message}",
                null
            )
        }
    }

    private fun handleDisposeGraphHopper(result: MethodChannel.Result) {
        try {
            routingService.dispose()
            result.success(true)
        } catch (e: Exception) {
            result.error(
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Failed to dispose GraphHopper: ${e.message}",
                null
            )
        }
    }
}
