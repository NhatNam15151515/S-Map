package com.vnsmap.app.routing

import com.vnsmap.app.routing.utils.GhzExtractor
import org.junit.After
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
    }

    @Test
    fun testExtractNonExistentFileReturnsFalse() {
        val nonExistent = File(tempDir, "does_not_exist.ghz")
        val success = GhzExtractor.extract(nonExistent, targetDir)
        assertFalse(success)
    }
}
