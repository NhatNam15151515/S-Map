package com.vnsmap.app.routing

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.Closeable
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class RoutingMethodChannelHandler(
    private val routingService: IGraphHopperService = GraphHopperService.instance,
    private val backgroundExecutor: ExecutorService = Executors.newSingleThreadExecutor(),
    private val resultPoster: (Runnable) -> Unit = { runnable ->
        try {
            if (Looper.myLooper() == Looper.getMainLooper()) {
                runnable.run()
            } else {
                Handler(Looper.getMainLooper()).post(runnable)
            }
        } catch (_: Exception) {
            runnable.run()
        }
    }
) : MethodChannel.MethodCallHandler, Closeable {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            RoutingConstants.METHOD_INIT_GRAPH_HOPPER -> handleInitGraphHopper(call, result)
            RoutingConstants.METHOD_GET_ROUTE -> handleGetRoute(call, result)
            RoutingConstants.METHOD_IS_INITIALIZED -> handleIsInitialized(result)
            RoutingConstants.METHOD_DISPOSE_GRAPH_HOPPER -> handleDisposeGraphHopper(result)
            else -> result.notImplemented()
        }
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        resultPoster(Runnable { result.success(value) })
    }

    private fun postError(result: MethodChannel.Result, errorCode: String, errorMessage: String?, errorDetails: Any?) {
        resultPoster(Runnable { result.error(errorCode, errorMessage, errorDetails) })
    }

    private fun handleInitGraphHopper(call: MethodCall, result: MethodChannel.Result) {
        val graphPath = call.argument<String>(RoutingConstants.ARG_GRAPH_PATH)
        if (graphPath.isNullOrBlank()) {
            postError(
                result,
                RoutingConstants.ERR_CODE_INVALID_ARGUMENTS,
                "Missing or blank '${RoutingConstants.ARG_GRAPH_PATH}' argument",
                null
            )
            return
        }

        if (backgroundExecutor.isShutdown) {
            postError(
                result,
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Routing executor has been shut down",
                null
            )
            return
        }

        backgroundExecutor.execute {
            try {
                val success = routingService.init(graphPath)
                postSuccess(result, success)
            } catch (e: Exception) {
                postError(
                    result,
                    RoutingConstants.ERR_CODE_ROUTING_FAILED,
                    "Failed to initialize GraphHopper: ${e.message}",
                    null
                )
            }
        }
    }

    private fun handleGetRoute(call: MethodCall, result: MethodChannel.Result) {
        val fromLat = call.argument<Number>(RoutingConstants.ARG_FROM_LAT)?.toDouble()
        val fromLon = call.argument<Number>(RoutingConstants.ARG_FROM_LON)?.toDouble()
        val toLat = call.argument<Number>(RoutingConstants.ARG_TO_LAT)?.toDouble()
        val toLon = call.argument<Number>(RoutingConstants.ARG_TO_LON)?.toDouble()
        val vehicleProfile = call.argument<String>(RoutingConstants.ARG_VEHICLE_PROFILE)
            ?: RoutingConstants.DEFAULT_PROFILE

        if (!isValidCoordinate(fromLat, fromLon) || !isValidCoordinate(toLat, toLon)) {
            postError(
                result,
                RoutingConstants.ERR_CODE_INVALID_ARGUMENTS,
                "Coordinates (fromLat, fromLon, toLat, toLon) must be finite numbers within valid GPS ranges (lat: [-90, 90], lon: [-180, 180])",
                null
            )
            return
        }

        if (backgroundExecutor.isShutdown) {
            postError(
                result,
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Routing executor has been shut down",
                null
            )
            return
        }

        backgroundExecutor.execute {
            try {
                val routeResult = routingService.route(fromLat!!, fromLon!!, toLat!!, toLon!!, vehicleProfile)
                postSuccess(result, routeResult.toMap())
            } catch (e: Exception) {
                postError(
                    result,
                    RoutingConstants.ERR_CODE_ROUTING_FAILED,
                    "Error calculating route: ${e.message}",
                    null
                )
            }
        }
    }

    private fun isValidCoordinate(lat: Double?, lon: Double?): Boolean {
        if (lat == null || lon == null) return false
        if (lat.isNaN() || lat.isInfinite() || lon.isNaN() || lon.isInfinite()) return false
        return lat in -90.0..90.0 && lon in -180.0..180.0
    }

    private fun handleIsInitialized(result: MethodChannel.Result) {
        try {
            val initialized = routingService.isInitialized()
            postSuccess(result, initialized)
        } catch (e: Exception) {
            postError(
                result,
                RoutingConstants.ERR_CODE_ROUTING_FAILED,
                "Failed to check initialization status: ${e.message}",
                null
            )
        }
    }

    private fun handleDisposeGraphHopper(result: MethodChannel.Result) {
        if (backgroundExecutor.isShutdown) {
            try {
                routingService.dispose()
                postSuccess(result, true)
            } catch (e: Exception) {
                postError(
                    result,
                    RoutingConstants.ERR_CODE_ROUTING_FAILED,
                    "Failed to dispose GraphHopper: ${e.message}",
                    null
                )
            }
            return
        }

        backgroundExecutor.execute {
            try {
                routingService.dispose()
                postSuccess(result, true)
            } catch (e: Exception) {
                postError(
                    result,
                    RoutingConstants.ERR_CODE_ROUTING_FAILED,
                    "Failed to dispose GraphHopper: ${e.message}",
                    null
                )
            }
        }
    }

    override fun close() {
        if (!backgroundExecutor.isShutdown) {
            backgroundExecutor.shutdown()
        }
    }
}
