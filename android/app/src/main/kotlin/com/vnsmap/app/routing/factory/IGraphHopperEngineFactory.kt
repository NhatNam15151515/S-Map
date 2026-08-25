package com.vnsmap.app.routing.factory

import com.vnsmap.app.routing.engine.IGraphHopperEngine
import java.io.File

interface IGraphHopperEngineFactory {
    /**
     * Tạo và khởi tạo instance IGraphHopperEngine với cấu hình MMAP
     */
    fun createAndLoad(graphDirectory: File): IGraphHopperEngine
}
