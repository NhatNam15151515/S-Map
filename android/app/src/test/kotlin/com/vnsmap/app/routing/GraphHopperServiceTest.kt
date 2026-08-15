package com.vnsmap.app.routing

import com.vnsmap.app.routing.engine.IGraphHopperEngine
import com.vnsmap.app.routing.factory.IGraphHopperEngineFactory
import com.vnsmap.app.routing.models.RouteInstruction
import com.vnsmap.app.routing.models.RoutePoint
import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.utils.IGhzExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class GraphHopperServiceTest {

    @Test
    fun testInitialState() {
        val service = GraphHopperService()
        assertFalse(service.isInitialized())
    }

    @Test
    fun testRouteWhenUninitializedReturnsFailure() {
        val service = GraphHopperService()
        val result = service.route(21.03, 105.85, 21.04, 105.86)

        assertFalse(result.isSuccess)
        assertNotNull(result.errorMessage)
        assertTrue(result.errorMessage!!.contains(RoutingConstants.ERR_SERVICE_NOT_INITIALIZED, ignoreCase = true))
    }

    @Test
    fun testInitWithInvalidDirectoryReturnsFalse() {
        val service = GraphHopperService()
        val invalidDir = File(System.getProperty("java.io.tmpdir"), "non_existent_graph_dir_${System.currentTimeMillis()}")

        val success = service.init(invalidDir.absolutePath)
        assertFalse(success)
        assertFalse(service.isInitialized())
    }

    @Test
    fun testInitAbortsWhenExtractionFails() {
        val failingExtractor = object : IGhzExtractor {
            override fun extract(ghzPath: String, targetFolderPath: String, overwrite: Boolean): Boolean {
                return false
            }
        }

        val service = GraphHopperService(ghzExtractor = failingExtractor)
        val tempGhz = File(System.getProperty("java.io.tmpdir"), "failing_${System.currentTimeMillis()}.ghz")
        tempGhz.createNewFile()
        try {
            val success = service.init(tempGhz.absolutePath)
            assertFalse("Init must fail when extraction returns false", success)
            assertFalse(service.isInitialized())
        } finally {
            tempGhz.delete()
        }
    }

    @Test
    fun testSuccessfulInitAndRouteWithMockEngineAndProfileForwarding() {
        val samplePoints = listOf(
            listOf(21.0285, 105.8542),
            listOf(21.0300, 105.8560),
            listOf(21.0350, 105.8600)
        )

        val sampleInstructions = listOf(
            RouteInstruction(
                text = "Rẽ phải vào Tràng Tiền",
                streetName = "Tràng Tiền",
                distance = 350.0,
                time = 45000L,
                sign = 2,
                points = listOf(listOf(21.0285, 105.8542), listOf(21.0300, 105.8560))
            )
        )

        val expectedResult = RouteResult(
            isSuccess = true,
            distance = 1250.0,
            time = 120000L,
            points = samplePoints,
            bbox = listOf(105.8542, 21.0285, 105.8600, 21.0350),
            instructions = sampleInstructions,
            calculationTimeMs = 35L
        )

        var lastProfile: String? = null
        val mockEngine = object : IGraphHopperEngine {
            override fun route(
                fromLat: Double,
                fromLon: Double,
                toLat: Double,
                toLon: Double,
                vehicleProfile: String
            ): RouteResult {
                lastProfile = vehicleProfile
                return expectedResult
            }

            override fun close() {}
        }

        val mockFactory = object : IGraphHopperEngineFactory {
            override fun createAndLoad(graphDirectory: File): IGraphHopperEngine {
                return mockEngine
            }
        }

        val tempDir = File(System.getProperty("java.io.tmpdir"), "valid_graph_${System.currentTimeMillis()}")
        tempDir.mkdirs()

        try {
            val service = GraphHopperService(engineFactory = mockFactory)
            val initSuccess = service.init(tempDir.absolutePath)
            assertTrue(initSuccess)
            assertTrue(service.isInitialized())

            // Test explicit profile forwarding
            val routeResult = service.route(21.0285, 105.8542, 21.0350, 105.8600, RoutingConstants.PROFILE_MOTORCYCLE)
            assertEquals(RoutingConstants.PROFILE_MOTORCYCLE, lastProfile)
            assertTrue(routeResult.isSuccess)
            assertEquals(1250.0, routeResult.distance, 0.01)
            assertEquals(120000L, routeResult.time)
            assertEquals(3, routeResult.points.size)
            assertEquals(1, routeResult.instructions.size)
            assertEquals("Rẽ phải vào Tràng Tiền", routeResult.instructions[0].text)
            assertEquals(listOf(105.8542, 21.0285, 105.8600, 21.0350), routeResult.bbox)

            // Test default profile forwarding
            service.route(21.0285, 105.8542, 21.0350, 105.8600)
            assertEquals(RoutingConstants.DEFAULT_PROFILE, lastProfile)

            service.dispose()
            assertFalse(service.isInitialized())
        } finally {
            tempDir.deleteRecursively()
        }
    }

    @Test
    fun testRouteResultSerialization() {
        val instruction = RouteInstruction(
            text = "Turn right",
            streetName = "Tràng Tiền",
            distance = 150.0,
            time = 15000L,
            sign = 2,
            points = listOf(listOf(21.025, 105.855), listOf(21.026, 105.856))
        )

        val result = RouteResult(
            isSuccess = true,
            distance = 1500.0,
            time = 120000L,
            points = listOf(listOf(21.02, 105.85), listOf(21.03, 105.86)),
            bbox = listOf(105.85, 21.02, 105.86, 21.03),
            instructions = listOf(instruction),
            calculationTimeMs = 45L
        )

        val map = result.toMap()
        assertEquals(true, map["isSuccess"])
        assertEquals(1500.0, map["distance"])
        assertEquals(120000L, map["time"])
        assertEquals(45L, map["calculationTimeMs"])

        val insMapList = map["instructions"] as List<*>
        assertEquals(1, insMapList.size)
        val insMap = insMapList[0] as Map<*, *>
        assertEquals("Turn right", insMap["text"])
        assertEquals("Tràng Tiền", insMap["streetName"])
        assertEquals(2, insMap["sign"])
    }

    @Test
    fun testRoutePointModel() {
        val point = RoutePoint(21.0285, 105.8542)
        assertEquals(21.0285, point.lat, 0.0001)
        assertEquals(105.8542, point.lon, 0.0001)
        assertEquals(listOf(21.0285, 105.8542), point.toList())
    }

    @Test
    fun testDisposeResetsState() {
        val service = GraphHopperService()
        service.dispose()
        assertFalse(service.isInitialized())
    }
}
