package com.vnsmap.app.routing.models

data class RouteInstruction(
    val text: String,
    val streetName: String,
    val distance: Double,
    val time: Long,
    val sign: Int,
    val points: List<List<Double>>,
    val maxSpeedKmh: Double? = null
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "text" to text,
        "streetName" to streetName,
        "distance" to distance,
        "time" to time,
        "sign" to sign,
        "points" to points,
        "maxSpeedKmh" to maxSpeedKmh
    )
}
