package com.vnsmap.app.routing.engine

import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.models.SnappedRoadPoint

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
     * Bắt / nắn tọa độ vào đường gần nhất thông qua LocationIndex
     */
    fun snapToRoad(
        lat: Double,
        lon: Double
    ): SnappedRoadPoint

    /**
     * Đóng và giải phóng tài nguyên engine
     */
    fun close()
}
