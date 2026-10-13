package com.vnsmap.app.routing.models

data class RoutePoint(
    val lat: Double,
    val lon: Double
) {
    fun toList(): List<Double> = listOf(lat, lon)

    fun toMap(): Map<String, Any> = mapOf(
        "lat" to lat,
        "lon" to lon
    )
}
