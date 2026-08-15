package com.vnsmap.app.routing.utils

import com.vnsmap.app.routing.RoutingConstants
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

object GhzExtractor : IGhzExtractor {

    override fun extract(ghzPath: String, targetFolderPath: String, overwrite: Boolean): Boolean {
        return extract(File(ghzPath), File(targetFolderPath), overwrite)
    }

    /**
     * Giải nén file .ghz (zip) vào thư mục targetFolder an toàn qua staging directory & backup
     */
    @Throws(IOException::class, SecurityException::class)
    fun extract(ghzFile: File, targetFolder: File, overwrite: Boolean = false): Boolean {
        if (!ghzFile.exists() || !ghzFile.isFile) {
            return false
        }

        val successMarkerFile = File(targetFolder, RoutingConstants.SUCCESS_MARKER)
        if (targetFolder.exists() && !overwrite && successMarkerFile.exists()) {
            return true
        }

        val parentDir = targetFolder.parentFile ?: ghzFile.parentFile ?: File(".")
        val stagingFolder = File(
            parentDir,
            "${targetFolder.name}${RoutingConstants.STAGING_DIR_SUFFIX}${System.nanoTime()}_${UUID.randomUUID()}"
        )
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
            File(stagingFolder, RoutingConstants.SUCCESS_MARKER).createNewFile()

            // Giữ dữ liệu cũ trong backup cho tới khi thay thế thành công
            val backupFolder = File(
                parentDir,
                "${targetFolder.name}${RoutingConstants.BACKUP_DIR_SUFFIX}${System.nanoTime()}_${UUID.randomUUID()}"
            )
            val hasBackup = targetFolder.exists() && targetFolder.renameTo(backupFolder)
            if (targetFolder.exists() && !hasBackup) {
                stagingFolder.deleteRecursively()
                return false
            }

            val replaced = stagingFolder.renameTo(targetFolder) ||
                (stagingFolder.copyRecursively(targetFolder, overwrite = true)
                    .also { copied -> if (copied) stagingFolder.deleteRecursively() })

            if (!replaced) {
                targetFolder.deleteRecursively()
                if (hasBackup) {
                    backupFolder.renameTo(targetFolder)
                }
                stagingFolder.deleteRecursively()
                return false
            }

            if (hasBackup) {
                backupFolder.deleteRecursively()
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
