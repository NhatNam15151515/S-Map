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
import java.util.concurrent.Executors

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
        var shouldThrow = false

        override fun init(graphPath: String): Boolean {
            if (shouldThrow) throw RuntimeException("Init failed intentionally")
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
            if (shouldThrow) throw RuntimeException("Route computation failed intentionally")
            routeCalled = true
            lastProfile = vehicleProfile
            return RouteResult(
                isSuccess = true,
                distance = 1500.0,
                time = 180000L,
                points = listOf(listOf(fromLat, fromLon), listOf(toLat, toLon)),
                bbox = listOf(fromLon, fromLat, toLon, toLat),
                instructions = listOf(
                    RouteInstruction("Đi thẳng trên đường Nguyễn Trãi", "Nguyễn Trãi", 1500.0, 180000L, 0, listOf(listOf(fromLat, fromLon), listOf(toLat, toLon)))
                ),
                calculationTimeMs = 12L
            )
        }

        override fun isInitialized(): Boolean {
            if (shouldThrow) throw RuntimeException("isInitialized check failed")
            return initializedState
        }

        override fun dispose() {
            if (shouldThrow) throw RuntimeException("Dispose failed intentionally")
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
        // Use synchronous single thread executor for unit tests
        handler = RoutingMethodChannelHandler(
            routingService = mockService,
            backgroundExecutor = Executors.newSingleThreadExecutor(),
            resultPoster = { it.run() }
        )
    }

    @Test
    fun testInitGraphHopperSuccess() {
        val call = MethodCall(
            RoutingConstants.METHOD_INIT_GRAPH_HOPPER,
            mapOf(RoutingConstants.ARG_GRAPH_PATH to "/data/vietnam.ghz")
        )
        val result = TestResult()

        handler.onMethodCall(call, result)
        Thread.sleep(50) // wait for executor

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
    fun testInitGraphHopperExceptionReturnsRoutingFailed() {
        mockService.shouldThrow = true
        val call = MethodCall(
            RoutingConstants.METHOD_INIT_GRAPH_HOPPER,
            mapOf(RoutingConstants.ARG_GRAPH_PATH to "/data/invalid.ghz")
        )
        val result = TestResult()

        handler.onMethodCall(call, result)
        Thread.sleep(50)

        assertEquals(RoutingConstants.ERR_CODE_ROUTING_FAILED, result.errorCode)
    }

    @Test
    fun testGetRouteSuccessWithProfileForwardingAndDeepAssertions() {
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
        Thread.sleep(50)

        assertTrue(mockService.routeCalled)
        assertEquals(RoutingConstants.PROFILE_MOTORCYCLE, mockService.lastProfile)
        assertNotNull(result.successResult)
        
        @Suppress("UNCHECKED_CAST")
        val resultMap = result.successResult as Map<String, Any?>
        assertEquals(true, resultMap["isSuccess"])
        assertEquals(1500.0, resultMap["distance"])
        assertEquals(180000L, resultMap["time"])
        assertEquals(12L, resultMap["calculationTimeMs"])
        
        // Deep assert points and bbox
        @Suppress("UNCHECKED_CAST")
        val points = resultMap["points"] as List<List<Double>>
        assertEquals(2, points.size)
        assertEquals(21.0285, points[0][0], 0.0001)
        assertEquals(105.8542, points[0][1], 0.0001)
        assertEquals(21.0380, points[1][0], 0.0001)
        assertEquals(105.7830, points[1][1], 0.0001)

        @Suppress("UNCHECKED_CAST")
        val bbox = resultMap["bbox"] as List<Double>
        assertEquals(4, bbox.size)
        assertEquals(105.8542, bbox[0], 0.0001)
        assertEquals(21.0285, bbox[1], 0.0001)
        assertEquals(105.7830, bbox[2], 0.0001)
        assertEquals(21.0380, bbox[3], 0.0001)

        // Deep assert instructions
        @Suppress("UNCHECKED_CAST")
        val instructions = resultMap["instructions"] as List<Map<String, Any?>>
        assertEquals(1, instructions.size)
        val ins = instructions[0]
        assertEquals("Đi thẳng trên đường Nguyễn Trãi", ins["text"])
        assertEquals("Nguyễn Trãi", ins["streetName"])
        assertEquals(1500.0, ins["distance"])
        assertEquals(180000L, ins["time"])
        assertEquals(0, ins["sign"])
        @Suppress("UNCHECKED_CAST")
        val insPoints = ins["points"] as List<List<Double>>
        assertEquals(2, insPoints.size)
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
    fun testGetRouteOutOfRangeCoordinatesReturnsError() {
        val call = MethodCall(
            RoutingConstants.METHOD_GET_ROUTE,
            mapOf(
                RoutingConstants.ARG_FROM_LAT to 95.0, // Out of range [-90, 90]
                RoutingConstants.ARG_FROM_LON to 105.8542,
                RoutingConstants.ARG_TO_LAT to 21.0380,
                RoutingConstants.ARG_TO_LON to 105.7830
            )
        )
        val result = TestResult()

        handler.onMethodCall(call, result)

        assertEquals(RoutingConstants.ERR_CODE_INVALID_ARGUMENTS, result.errorCode)
    }

    @Test
    fun testGetRouteNaNCoordinatesReturnsError() {
        val call = MethodCall(
            RoutingConstants.METHOD_GET_ROUTE,
            mapOf(
                RoutingConstants.ARG_FROM_LAT to Double.NaN,
                RoutingConstants.ARG_FROM_LON to 105.8542,
                RoutingConstants.ARG_TO_LAT to 21.0380,
                RoutingConstants.ARG_TO_LON to 105.7830
            )
        )
        val result = TestResult()

        handler.onMethodCall(call, result)

        assertEquals(RoutingConstants.ERR_CODE_INVALID_ARGUMENTS, result.errorCode)
    }

    @Test
    fun testGetRouteExceptionReturnsRoutingFailed() {
        mockService.shouldThrow = true
        val call = MethodCall(
            RoutingConstants.METHOD_GET_ROUTE,
            mapOf(
                RoutingConstants.ARG_FROM_LAT to 21.0285,
                RoutingConstants.ARG_FROM_LON to 105.8542,
                RoutingConstants.ARG_TO_LAT to 21.0380,
                RoutingConstants.ARG_TO_LON to 105.7830
            )
        )
        val result = TestResult()

        handler.onMethodCall(call, result)
        Thread.sleep(50)

        assertEquals(RoutingConstants.ERR_CODE_ROUTING_FAILED, result.errorCode)
    }

    @Test
    fun testIsInitializedAndDispose() {
        val initCheckResult = TestResult()
        handler.onMethodCall(MethodCall(RoutingConstants.METHOD_IS_INITIALIZED, null), initCheckResult)
        assertEquals(false, initCheckResult.successResult)

        val disposeResult = TestResult()
        handler.onMethodCall(MethodCall(RoutingConstants.METHOD_DISPOSE_GRAPH_HOPPER, null), disposeResult)
        Thread.sleep(50)
        assertTrue(mockService.disposeCalled)
        assertEquals(true, disposeResult.successResult)
    }

    @Test
    fun testCloseShutsDownExecutor() {
        handler.close()
        val result = TestResult()
        handler.onMethodCall(
            MethodCall(RoutingConstants.METHOD_INIT_GRAPH_HOPPER, mapOf(RoutingConstants.ARG_GRAPH_PATH to "/test.ghz")),
            result
        )
        assertEquals(RoutingConstants.ERR_CODE_ROUTING_FAILED, result.errorCode)
    }

    @Test
    fun testUnknownMethodCallsNotImplemented() {
        val result = TestResult()
        handler.onMethodCall(MethodCall("unknownMethodName", null), result)
        assertTrue(result.notImplementedCalled)
    }
}
