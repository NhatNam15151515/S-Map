package com.vnsmap.app.routing.utils

import com.vnsmap.app.routing.RoutingConstants
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream

object GhzExtractor : IGhzExtractor {

    /**
     * Giải nén file .ghz (zip) vào thư mục targetFolder an toàn
     */
    @Throws(IOException::class)
    override fun extract(ghzFile: File, targetFolder: File, overwrite: Boolean): Boolean {
        if (!ghzFile.exists() || !ghzFile.isFile) {
            return false
        }

        if (targetFolder.exists() && !overwrite) {
            val list = targetFolder.list()
            if (list != null && list.isNotEmpty()) {
                // Đã tồn tại và không rỗng
                return true
            }
        }

        if (!targetFolder.exists()) {
            targetFolder.mkdirs()
        }

        val canonicalTargetPath = targetFolder.canonicalPath

        ZipInputStream(FileInputStream(ghzFile)).use { zis ->
            var entry: ZipEntry? = zis.nextEntry
            val buffer = ByteArray(RoutingConstants.BUFFER_SIZE)

            while (entry != null) {
                val newFile = File(targetFolder, entry.name)
                val canonicalNewPath = newFile.canonicalPath

                // Chống Zip Slip Vulnerability
                if (!canonicalNewPath.startsWith(canonicalTargetPath + File.separator) &&
                    canonicalNewPath != canonicalTargetPath
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
        return true
    }
}
