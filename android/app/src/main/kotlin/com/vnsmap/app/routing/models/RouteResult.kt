package com.vnsmap.app.routing.models

data class RouteResult(
    val isSuccess: Boolean,
    val distance: Double = 0.0,
    val time: Long = 0L,
    val points: List<List<Double>> = emptyList(),
    val bbox: List<Double>? = null,
    val instructions: List<RouteInstruction> = emptyList(),
    val errorMessage: String? = null,
    val calculationTimeMs: Long = 0L
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "isSuccess" to isSuccess,
        "distance" to distance,
        "time" to time,
        "points" to points,
        "bbox" to bbox,
        "instructions" to instructions.map { it.toMap() },
        "errorMessage" to errorMessage,
        "calculationTimeMs" to calculationTimeMs
    )

    companion object {
        fun failure(message: String, calculationTimeMs: Long = 0L): RouteResult {
            return RouteResult(
                isSuccess = false,
                errorMessage = message,
                calculationTimeMs = calculationTimeMs
            )
        }
    }
}
