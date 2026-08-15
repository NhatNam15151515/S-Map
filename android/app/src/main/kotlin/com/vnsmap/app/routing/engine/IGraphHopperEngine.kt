package com.vnsmap.app.routing.engine

import com.vnsmap.app.routing.models.RouteResult

interface IGraphHopperEngine {
    /**
     * Thực thi tính toán tuyến đường
     */
    fun route(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
        vehicleProfile: String
    ): RouteResult

    /**
     * Đóng và giải phóng tài nguyên engine
     */
    fun close()
}
