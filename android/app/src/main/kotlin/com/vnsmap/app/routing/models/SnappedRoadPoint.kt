package com.vnsmap.app.routing.models

data class SnappedRoadPoint(
    val isSnapped: Boolean,
    val originalLat: Double,
    val originalLon: Double,
    val snappedLat: Double,
    val snappedLon: Double,
    val streetName: String = "",
    val distanceToRoad: Double = 0.0,
    val edgeId: Int = -1,
    val calculationTimeMs: Long = 0,
    val errorMessage: String? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "isSnapped" to isSnapped,
        "originalLat" to originalLat,
        "originalLon" to originalLon,
        "snappedLat" to snappedLat,
        "snappedLon" to snappedLon,
        "streetName" to streetName,
        "distanceToRoad" to distanceToRoad,
        "edgeId" to edgeId,
        "calculationTimeMs" to calculationTimeMs,
        "errorMessage" to errorMessage
    )

    companion object {
        fun notSnapped(
            originalLat: Double,
            originalLon: Double,
            error: String? = null,
            timeMs: Long = 0
        ): SnappedRoadPoint {
            return SnappedRoadPoint(
                isSnapped = false,
                originalLat = originalLat,
                originalLon = originalLon,
                snappedLat = originalLat,
                snappedLon = originalLon,
                errorMessage = error,
                calculationTimeMs = timeMs
            )
        }
    }
}
