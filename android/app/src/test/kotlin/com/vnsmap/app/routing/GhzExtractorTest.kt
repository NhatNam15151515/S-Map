package com.vnsmap.app.routing

import com.vnsmap.app.routing.utils.GhzExtractor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.FileOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class GhzExtractorTest {

    private lateinit var tempDir: File
    private lateinit var sampleGhz: File
    private lateinit var targetDir: File

    @Before
    fun setUp() {
        tempDir = File(System.getProperty("java.io.tmpdir"), "ghz_test_${System.currentTimeMillis()}")
        tempDir.mkdirs()

        sampleGhz = File(tempDir, "sample.ghz")
        targetDir = File(tempDir, "extracted")

        // Create sample zip file
        ZipOutputStream(FileOutputStream(sampleGhz)).use { zos ->
            zos.putNextEntry(ZipEntry("properties"))
            zos.write("graph.date=2026-08-15".toByteArray())
            zos.closeEntry()

            zos.putNextEntry(ZipEntry("nodes"))
            zos.write("sample_nodes_content".toByteArray())
            zos.closeEntry()
        }
    }

    @After
    fun tearDown() {
        tempDir.deleteRecursively()
    }

    @Test
    fun testExtractValidGhzFile() {
        val success = GhzExtractor.extract(sampleGhz, targetDir)
        assertTrue(success)
        assertTrue(targetDir.exists())
        assertTrue(File(targetDir, "properties").exists())
        assertTrue(File(targetDir, "nodes").exists())
        assertTrue(File(targetDir, RoutingConstants.SUCCESS_MARKER).exists())
    }

    @Test
    fun testExtractNonExistentFileReturnsFalse() {
        val nonExistent = File(tempDir, "does_not_exist.ghz")
        val success = GhzExtractor.extract(nonExistent, targetDir)
        assertFalse(success)
    }

    @Test(expected = SecurityException::class)
    fun testZipSlipPathTraversalThrowsSecurityException() {
        val maliciousGhz = File(tempDir, "malicious.ghz")
        ZipOutputStream(FileOutputStream(maliciousGhz)).use { zos ->
            zos.putNextEntry(ZipEntry("../outside_file.txt"))
            zos.write("dangerous payload".toByteArray())
            zos.closeEntry()
        }

        val maliciousTarget = File(tempDir, "safe_target")
        try {
            GhzExtractor.extract(maliciousGhz, maliciousTarget)
        } finally {
            val outsideFile = File(tempDir, "outside_file.txt")
            assertFalse("Outside file must never be created", outsideFile.exists())
        }
    }

    @Test
    fun testStagingFolderCleanedUpAfterZipSlip() {
        val maliciousGhz = File(tempDir, "malicious_clean.ghz")
        ZipOutputStream(FileOutputStream(maliciousGhz)).use { zos ->
            zos.putNextEntry(ZipEntry("../outside_clean.txt"))
            zos.write("payload".toByteArray())
            zos.closeEntry()
        }

        try {
            GhzExtractor.extract(maliciousGhz, File(tempDir, "safe_target_clean"))
        } catch (_: SecurityException) {
            // Expected
        }

        val leftovers = tempDir.listFiles { f -> f.isDirectory && f.name.contains(RoutingConstants.STAGING_DIR_SUFFIX) }
        assertTrue("Staging folder must be cleaned up after error", leftovers == null || leftovers.isEmpty())
    }

    @Test
    fun testSecondExtractSkipsWhenMarkerExists() {
        assertTrue(GhzExtractor.extract(sampleGhz, targetDir))
        val nodes = File(targetDir, "nodes")
        nodes.writeText("sentinel_unmodified_content")

        // Second extract with overwrite = false
        assertTrue(GhzExtractor.extract(sampleGhz, targetDir, overwrite = false))
        assertEquals("sentinel_unmodified_content", nodes.readText())
    }
}
