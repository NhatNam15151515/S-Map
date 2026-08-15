package com.vnsmap.app.routing

import com.vnsmap.app.routing.models.RouteResult

interface IGraphHopperService {
    /**
     * Khởi tạo GraphHopper từ đường dẫn thư mục graph hoặc file .ghz
     */
    fun init(graphPath: String): Boolean

    /**
     * Tính toán đường đi từ điểm A đến điểm B
     */
    fun route(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
        vehicleProfile: String = RoutingConstants.DEFAULT_PROFILE
    ): RouteResult

    /**
     * Kiểm tra trạng thái đã nạp graph thành công chưa
     */
    fun isInitialized(): Boolean

    /**
     * Giải phóng tài nguyên và đóng graph
     */
    fun dispose()
}
