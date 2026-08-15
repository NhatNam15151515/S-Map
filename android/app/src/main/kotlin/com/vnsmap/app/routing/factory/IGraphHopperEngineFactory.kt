package com.vnsmap.app.routing.factory

import com.graphhopper.GraphHopper
import java.io.File

interface IGraphHopperEngineFactory {
    /**
     * Tạo và khởi tạo instance GraphHopper với cấu hình MMAP
     */
    fun createAndLoad(graphDirectory: File): GraphHopper
}
