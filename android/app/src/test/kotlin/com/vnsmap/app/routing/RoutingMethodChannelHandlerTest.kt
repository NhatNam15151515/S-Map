package com.vnsmap.app.routing

import com.vnsmap.app.routing.models.RouteInstruction
import com.vnsmap.app.routing.models.RouteResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class RoutingMethodChannelHandlerTest {

    private lateinit var mockService: MockGraphHopperService
    private lateinit var handler: RoutingMethodChannelHandler

    class MockGraphHopperService : IGraphHopperService {
        var initCalled = false
        var initPath: String? = null
        var routeCalled = false
        var lastProfile: String? = null
        var disposeCalled = false
        var initializedState = false

        override fun init(graphPath: String): Boolean {
            initCalled = true
            initPath = graphPath
            initializedState = true
            return true
        }

        override fun route(
            fromLat: Double,
            fromLon: Double,
            toLat: Double,
            toLon: Double,
            vehicleProfile: String
        ): RouteResult {
            routeCalled = true
            lastProfile = vehicleProfile
            return RouteResult(
                isSuccess = true,
                distance = 1500.0,
                time = 180000L,
                points = listOf(listOf(fromLat, fromLon), listOf(toLat, toLon)),
                bbox = listOf(fromLon, fromLat, toLon, toLat),
                instructions = listOf(
                    RouteInstruction("Đi thẳng", "Nguyễn Trãi", 1500.0, 180000L, 0, emptyList())
                ),
                calculationTimeMs = 12L
            )
        }

        override fun isInitialized(): Boolean = initializedState

        override fun dispose() {
            disposeCalled = true
            initializedState = false
        }
    }

    class TestResult : MethodChannel.Result {
        var successResult: Any? = null
        var errorCode: String? = null
        var errorMessage: String? = null
        var errorDetails: Any? = null
        var notImplementedCalled = false

        override fun success(result: Any?) {
            successResult = result
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            this.errorCode = errorCode
            this.errorMessage = errorMessage
            this.errorDetails = errorDetails
        }

        override fun notImplemented() {
            notImplementedCalled = true
        }
    }

    @Before
    fun setUp() {
        mockService = MockGraphHopperService()
        handler = RoutingMethodChannelHandler(mockService)
    }

    @Test
    fun testInitGraphHopperSuccess() {
        val call = MethodCall(
            RoutingConstants.METHOD_INIT_GRAPH_HOPPER,
            mapOf(RoutingConstants.ARG_GRAPH_PATH to "/data/vietnam.ghz")
        )
        val result = TestResult()

        handler.onMethodCall(call, result)

        assertTrue(mockService.initCalled)
        assertEquals("/data/vietnam.ghz", mockService.initPath)
        assertEquals(true, result.successResult)
    }

    @Test
    fun testInitGraphHopperMissingPathReturnsError() {
        val call = MethodCall(
            RoutingConstants.METHOD_INIT_GRAPH_HOPPER,
            mapOf(RoutingConstants.ARG_GRAPH_PATH to "")
        )
        val result = TestResult()

        handler.onMethodCall(call, result)

        assertEquals(RoutingConstants.ERR_CODE_INVALID_ARGUMENTS, result.errorCode)
    }

    @Test
    fun testGetRouteSuccessWithProfileForwarding() {
        val call = MethodCall(
            RoutingConstants.METHOD_GET_ROUTE,
            mapOf(
                RoutingConstants.ARG_FROM_LAT to 21.0285,
                RoutingConstants.ARG_FROM_LON to 105.8542,
                RoutingConstants.ARG_TO_LAT to 21.0380,
                RoutingConstants.ARG_TO_LON to 105.7830,
                RoutingConstants.ARG_VEHICLE_PROFILE to RoutingConstants.PROFILE_MOTORCYCLE
            )
        )
        val result = TestResult()

        handler.onMethodCall(call, result)

        assertTrue(mockService.routeCalled)
        assertEquals(RoutingConstants.PROFILE_MOTORCYCLE, mockService.lastProfile)
        assertNotNull(result.successResult)
        val resultMap = result.successResult as Map<*, *>
        assertEquals(true, resultMap["isSuccess"])
        assertEquals(1500.0, resultMap["distance"])
    }

    @Test
    fun testGetRouteMissingCoordinatesReturnsError() {
        val call = MethodCall(
            RoutingConstants.METHOD_GET_ROUTE,
            mapOf(
                RoutingConstants.ARG_FROM_LAT to 21.0285
                // Missing other coordinates
            )
        )
        val result = TestResult()

        handler.onMethodCall(call, result)

        assertEquals(RoutingConstants.ERR_CODE_INVALID_ARGUMENTS, result.errorCode)
    }

    @Test
    fun testIsInitializedAndDispose() {
        val initCheckResult = TestResult()
        handler.onMethodCall(MethodCall(RoutingConstants.METHOD_IS_INITIALIZED, null), initCheckResult)
        assertEquals(false, initCheckResult.successResult)

        val disposeResult = TestResult()
        handler.onMethodCall(MethodCall(RoutingConstants.METHOD_DISPOSE_GRAPH_HOPPER, null), disposeResult)
        assertTrue(mockService.disposeCalled)
        assertEquals(true, disposeResult.successResult)
    }

    @Test
    fun testUnknownMethodCallsNotImplemented() {
        val result = TestResult()
        handler.onMethodCall(MethodCall("unknownMethodName", null), result)
        assertTrue(result.notImplementedCalled)
    }
}
