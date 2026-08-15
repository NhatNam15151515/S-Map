package com.vnsmap.app.routing.utils

import java.io.File
import java.io.IOException

interface IGhzExtractor {
    @Throws(IOException::class)
    fun extract(ghzFile: File, targetFolder: File, overwrite: Boolean = false): Boolean
}
