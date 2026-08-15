package com.vnsmap.app.routing.utils

import java.io.IOException

interface IGhzExtractor {
    @Throws(IOException::class)
    fun extract(ghzPath: String, targetFolderPath: String, overwrite: Boolean = false): Boolean
}
