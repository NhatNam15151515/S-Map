package com.vnsmap.app.routing.utils

import com.vnsmap.app.routing.RoutingConstants
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

object GhzExtractor : IGhzExtractor {

    private const val SUCCESS_MARKER = ".extracted_success"

    override fun extract(ghzPath: String, targetFolderPath: String, overwrite: Boolean): Boolean {
        return extract(File(ghzPath), File(targetFolderPath), overwrite)
    }

    /**
     * Giải nén file .ghz (zip) vào thư mục targetFolder an toàn qua staging directory
     */
    @Throws(IOException::class)
    fun extract(ghzFile: File, targetFolder: File, overwrite: Boolean = false): Boolean {
        if (!ghzFile.exists() || !ghzFile.isFile) {
            return false
        }

        val successMarkerFile = File(targetFolder, SUCCESS_MARKER)
        if (targetFolder.exists() && !overwrite && successMarkerFile.exists()) {
            return true
        }

        // Tạo thư mục staging cùng cấp để giải nén an toàn
        val parentDir = targetFolder.parentFile ?: ghzFile.parentFile ?: File(".")
        val stagingFolder = File(parentDir, "${targetFolder.name}_staging_${System.currentTimeMillis()}")
        if (!stagingFolder.exists()) {
            stagingFolder.mkdirs()
        }

        val canonicalStagingPath = stagingFolder.canonicalPath

        try {
            ZipInputStream(FileInputStream(ghzFile)).use { zis ->
                var entry: ZipEntry? = zis.nextEntry
                val buffer = ByteArray(RoutingConstants.BUFFER_SIZE)

                while (entry != null) {
                    val newFile = File(stagingFolder, entry.name)
                    val canonicalNewPath = newFile.canonicalPath

                    // Chống Zip Slip Vulnerability
                    if (!canonicalNewPath.startsWith(canonicalStagingPath + File.separator) &&
                        canonicalNewPath != canonicalStagingPath
                    ) {
                        throw SecurityException(RoutingConstants.ERR_ZIP_SLIP_ATTEMPT + entry.name)
                    }

                    if (entry.isDirectory) {
                        newFile.mkdirs()
                    } else {
                        newFile.parentFile?.mkdirs()
                        FileOutputStream(newFile).use { fos ->
                            var len: Int
                            while (zis.read(buffer).also { len = it } > 0) {
                                fos.write(buffer, 0, len)
                            }
                        }
                    }
                    zis.closeEntry()
                    entry = zis.nextEntry
                }
            }

            // Ghi file marker báo hiệu giải nén toàn vẹn
            File(stagingFolder, SUCCESS_MARKER).createNewFile()

            // Xóa targetFolder cũ nếu có và rename stagingFolder sang targetFolder
            if (targetFolder.exists()) {
                targetFolder.deleteRecursively()
            }

            val renamed = stagingFolder.renameTo(targetFolder)
            if (!renamed) {
                // Fallback nếu renameTo khác partition
                stagingFolder.copyRecursively(targetFolder, overwrite = true)
                stagingFolder.deleteRecursively()
            }

            return true
        } catch (e: Exception) {
            stagingFolder.deleteRecursively()
            if (e is SecurityException) {
                throw e
            }
            return false
        }
    }
}
