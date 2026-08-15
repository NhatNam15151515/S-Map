package com.vnsmap.app.routing

import com.graphhopper.GraphHopper
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

        val success = service.init(invalidDir)
        assertFalse(success)
        assertFalse(service.isInitialized())
    }

    @Test
    fun testDependencyInjectionWithCustomExtractorAndFactory() {
        var extractCalled = false
        val mockExtractor = object : IGhzExtractor {
            override fun extract(ghzFile: File, targetFolder: File, overwrite: Boolean): Boolean {
                extractCalled = true
                targetFolder.mkdirs()
                return true
            }
        }

        var factoryCalled = false
        val mockFactory = object : IGraphHopperEngineFactory {
            override fun createAndLoad(graphDirectory: File): GraphHopper {
                factoryCalled = true
                throw RuntimeException("Mock load failure for safety")
            }
        }

        val service = GraphHopperService(
            engineFactory = mockFactory,
            ghzExtractor = mockExtractor
        )

        val tempGhz = File(System.getProperty("java.io.tmpdir"), "test_${System.currentTimeMillis()}.ghz")
        tempGhz.createNewFile()
        try {
            val success = service.init(tempGhz)
            assertFalse(success)
            assertTrue("Extractor should be called through DI", extractCalled)
            assertTrue("Factory should be called through DI", factoryCalled)
        } finally {
            tempGhz.delete()
            val extractedDir = File(tempGhz.parentFile, tempGhz.nameWithoutExtension + RoutingConstants.EXTRACTED_DIR_SUFFIX)
            extractedDir.deleteRecursively()
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
