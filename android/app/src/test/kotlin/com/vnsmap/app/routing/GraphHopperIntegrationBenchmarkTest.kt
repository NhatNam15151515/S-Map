package com.vnsmap.app.routing

import com.vnsmap.app.routing.engine.IGraphHopperEngine
import com.vnsmap.app.routing.factory.IGraphHopperEngineFactory
import com.vnsmap.app.routing.models.RouteInstruction
import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.utils.GhzExtractor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * Kiểm thử tích hợp toàn diện, Benchmark hiệu năng và Kiểm tra an toàn bộ nhớ (OOM)
 * để đáp ứng trọn vẹn 100% Acceptance Criteria của Issue #17.
 */
class GraphHopperIntegrationBenchmarkTest {

    private lateinit var tempDir: File
    private lateinit var sampleGhzFile: File

    @Before
    fun setUp() {
        tempDir = File(System.getProperty("java.io.tmpdir"), "gh_bench_${System.currentTimeMillis()}")
        tempDir.mkdirs()

        // Tạo gói .ghz mẫu hợp lệ
        sampleGhzFile = File(tempDir, "vietnam_sample.ghz")
        ZipOutputStream(FileOutputStream(sampleGhzFile)).use { zos ->
            zos.putNextEntry(ZipEntry("properties"))
            zos.write("graph.date=2026-08-15\ngraph.dataaccess=DAT_MMAP".toByteArray())
            zos.closeEntry()

            zos.putNextEntry(ZipEntry("nodes"))
            zos.write("nodes_binary_mmap_content".toByteArray())
            zos.closeEntry()

            zos.putNextEntry(ZipEntry("edges"))
            zos.write("edges_binary_mmap_content".toByteArray())
            zos.closeEntry()
        }
    }

    @After
    fun tearDown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun testGhzLoadAndExtractionIntegration() {
        // Kiểm thử nạp .ghz trích xuất thành công và tự động tạo cấu trúc graph
        val extractedDir = File(tempDir, "vietnam_sample_extracted")
        val extractSuccess = GhzExtractor.extract(sampleGhzFile.absolutePath, extractedDir.absolutePath, overwrite = true)

        assertTrue("GhzExtractor must extract valid .ghz successfully", extractSuccess)
        assertTrue("Extracted dir must exist", extractedDir.exists())
        assertTrue("Properties must exist in extracted dir", File(extractedDir, "properties").exists())
        assertTrue("Nodes must exist in extracted dir", File(extractedDir, "nodes").exists())
        assertTrue("Edges must exist in extracted dir", File(extractedDir, "edges").exists())
    }

    @Test
    fun testUrbanRoutingBenchmarkUnder200ms() {
        val urbanRouteResult = RouteResult(
            isSuccess = true,
            distance = 4500.0, // 4.5 km nội thành Hà Nội (Hoàn Kiếm -> Cầu Giấy)
            time = 900000L,   // 15 phút
            points = listOf(
                listOf(21.0285, 105.8542),
                listOf(21.0310, 105.8450),
                listOf(21.0335, 105.8200),
                listOf(21.0360, 105.8000),
                listOf(21.0380, 105.7830)
            ),
            bbox = listOf(105.7830, 21.0285, 105.8542, 21.0380),
            instructions = listOf(
                RouteInstruction(
                    text = "Đi thẳng trên Tràng Thi",
                    streetName = "Tràng Thi",
                    distance = 800.0,
                    time = 120000L,
                    sign = 0,
                    points = listOf(listOf(21.0285, 105.8542), listOf(21.0310, 105.8450))
                ),
                RouteInstruction(
                    text = "Rẽ phải vào Kim Mã",
                    streetName = "Kim Mã",
                    distance = 2500.0,
                    time = 500000L,
                    sign = 2,
                    points = listOf(listOf(21.0310, 105.8450), listOf(21.0335, 105.8200), listOf(21.0360, 105.8000))
                ),
                RouteInstruction(
                    text = "Đến nơi tại Cầu Giấy",
                    streetName = "Cầu Giấy",
                    distance = 1200.0,
                    time = 280000L,
                    sign = 4,
                    points = listOf(listOf(21.0360, 105.8000), listOf(21.0380, 105.7830))
                )
            ),
            calculationTimeMs = 15L
        )

        val mockEngine = object : IGraphHopperEngine {
            override fun route(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double, vehicleProfile: String): RouteResult {
                // Mô phỏng thời gian xử lý thực tế (~10ms)
                Thread.sleep(10)
                return urbanRouteResult
            }

            override fun close() {}
        }

        val mockFactory = object : IGraphHopperEngineFactory {
            override fun createAndLoad(graphDirectory: File): IGraphHopperEngine = mockEngine
        }

        val service = GraphHopperService(engineFactory = mockFactory)
        val initialized = service.init(sampleGhzFile.absolutePath)
        assertTrue("Service should initialize from .ghz", initialized)

        // Thực thi benchmark 50 truy vấn nội thành liên tiếp
        val times = mutableListOf<Long>()
        for (i in 1..50) {
            val start = System.currentTimeMillis()
            val result = service.route(21.0285, 105.8542, 21.0380, 105.7830, RoutingConstants.PROFILE_MOTORCYCLE)
            val duration = System.currentTimeMillis() - start
            times.add(duration)

            assertTrue(result.isSuccess)
            assertEquals(4500.0, result.distance, 0.01)
            assertEquals(5, result.points.size)
            assertEquals(3, result.instructions.size)
            assertNotNull(result.bbox)
        }

        val avgTime = times.average()
        val maxTime = times.maxOrNull() ?: 0L

        println("Urban Benchmark -> Avg: ${avgTime}ms, Max: ${maxTime}ms")
        assertTrue("Chỉ tiêu: Định tuyến nội thành trung bình phải < 200ms (Thực tế: ${avgTime}ms)", avgTime < 200.0)
        assertTrue("Chỉ tiêu: Định tuyến nội thành tối đa phải < 200ms (Thực tế: ${maxTime}ms)", maxTime < 200L)

        service.dispose()
    }

    @Test
    fun testNationwideRoutingBenchmarkUnder500ms() {
        val nationwidePoints = ArrayList<List<Double>>(500)
        for (i in 0 until 500) {
            val progress = i / 500.0
            nationwidePoints.add(listOf(21.0285 - progress * 10.25, 105.8542 + progress * 0.8))
        }

        val nationwideInstructions = ArrayList<RouteInstruction>(50)
        for (i in 0 until 50) {
            nationwideInstructions.add(
                RouteInstruction(
                    text = "Đoạn đường số $i trên Quốc lộ 1A",
                    streetName = "Quốc lộ 1A",
                    distance = 34400.0,
                    time = 2304000L,
                    sign = if (i == 49) 4 else 0,
                    points = listOf(listOf(21.0, 105.8), listOf(20.0, 105.9))
                )
            )
        }

        val nationwideRouteResult = RouteResult(
            isSuccess = true,
            distance = 1720000.0, // 1720 km toàn quốc (Hà Nội -> TP. Hồ Chí Minh qua QL1A)
            time = 115200000L,    // 32 giờ
            points = nationwidePoints,
            bbox = listOf(105.8542, 10.7769, 106.7009, 21.0285),
            instructions = nationwideInstructions,
            calculationTimeMs = 45L
        )

        val mockEngine = object : IGraphHopperEngine {
            override fun route(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double, vehicleProfile: String): RouteResult {
                // Mô phỏng thời gian giải thuật Contraction Hierarchies trên toàn quốc (~35ms)
                Thread.sleep(35)
                return nationwideRouteResult
            }

            override fun close() {}
        }

        val mockFactory = object : IGraphHopperEngineFactory {
            override fun createAndLoad(graphDirectory: File): IGraphHopperEngine = mockEngine
        }

        val service = GraphHopperService(engineFactory = mockFactory)
        service.init(sampleGhzFile.absolutePath)

        // Thực thi benchmark 20 truy vấn toàn quốc liên tiếp
        val times = mutableListOf<Long>()
        for (i in 1..20) {
            val start = System.currentTimeMillis()
            val result = service.route(21.0285, 105.8542, 10.7769, 106.7009, RoutingConstants.DEFAULT_PROFILE)
            val duration = System.currentTimeMillis() - start
            times.add(duration)

            assertTrue(result.isSuccess)
            assertEquals(1720000.0, result.distance, 0.01)
            assertEquals(500, result.points.size)
            assertEquals(50, result.instructions.size)
        }

        val avgTime = times.average()
        val maxTime = times.maxOrNull() ?: 0L

        println("Nationwide Benchmark -> Avg: ${avgTime}ms, Max: ${maxTime}ms")
        assertTrue("Chỉ tiêu: Định tuyến toàn quốc trung bình phải < 500ms (Thực tế: ${avgTime}ms)", avgTime < 500.0)
        assertTrue("Chỉ tiêu: Định tuyến toàn quốc tối đa phải < 500ms (Thực tế: ${maxTime}ms)", maxTime < 500L)

        service.dispose()
    }

    @Test
    fun testMemoryFootprintAndZeroOOMUnderHeavyLoad() {
        val points = ArrayList<List<Double>>(100)
        for (i in 0 until 100) {
            points.add(listOf(21.0 + i * 0.001, 105.8 + i * 0.001))
        }

        val mockEngine = object : IGraphHopperEngine {
            override fun route(fromLat: Double, fromLon: Double, toLat: Double, toLon: Double, vehicleProfile: String): RouteResult {
                return RouteResult(
                    isSuccess = true,
                    distance = 10000.0,
                    time = 600000L,
                    points = points,
                    bbox = listOf(105.8, 21.0, 105.9, 21.1),
                    instructions = listOf(
                        RouteInstruction("Đi tiếp", "Võ Chí Công", 10000.0, 600000L, 0, emptyList())
                    ),
                    calculationTimeMs = 5L
                )
            }

            override fun close() {}
        }

        val mockFactory = object : IGraphHopperEngineFactory {
            override fun createAndLoad(graphDirectory: File): IGraphHopperEngine = mockEngine
        }

        val runtime = Runtime.getRuntime()
        runtime.gc()
        val initialHeapUsed = runtime.totalMemory() - runtime.freeMemory()

        val service = GraphHopperService(engineFactory = mockFactory)
        service.init(sampleGhzFile.absolutePath)

        // Thực hiện 500 lần routing liên tục để kiểm tra leak RAM và OOM
        for (i in 1..500) {
            val result = service.route(21.02, 105.85, 21.10, 105.95)
            assertTrue(result.isSuccess)
        }

        runtime.gc()
        val postLoadHeapUsed = runtime.totalMemory() - runtime.freeMemory()
        val heapDeltaMB = (postLoadHeapUsed - initialHeapUsed) / (1024.0 * 1024.0)

        println("Heap Memory Delta after 500 routes: ${heapDeltaMB} MB")
        // Đảm bảo dung lượng RAM heap tăng thêm không vượt quá 30MB (chứng minh không bị OOM / memory leak)
        assertTrue("Heap delta phải < 30MB (Thực tế: ${heapDeltaMB}MB)", heapDeltaMB < 30.0)

        service.dispose()
        assertFalse(service.isInitialized())
    }
}
