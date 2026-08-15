package com.vnsmap.app.routing.factory

import com.graphhopper.GHRequest
import com.graphhopper.GHResponse
import com.graphhopper.GraphHopper
import com.graphhopper.GraphHopperConfig
import com.graphhopper.ResponsePath
import com.graphhopper.util.Instruction
import com.graphhopper.util.Translation
import com.graphhopper.util.TranslationMap
import com.vnsmap.app.routing.RoutingConstants
import com.vnsmap.app.routing.engine.IGraphHopperEngine
import com.vnsmap.app.routing.models.RouteInstruction
import com.vnsmap.app.routing.models.RouteResult
import java.io.File

class DefaultGraphHopperEngineFactory : IGraphHopperEngineFactory {

    override fun createAndLoad(graphDirectory: File): IGraphHopperEngine {
        val config = GraphHopperConfig().apply {
            putObject(RoutingConstants.CONFIG_GRAPH_DATAACCESS, RoutingConstants.STORAGE_DAT_MMAP)
            putObject(RoutingConstants.CONFIG_GRAPH_LOCATION, graphDirectory.absolutePath)
            putObject(RoutingConstants.CONFIG_DATAREADER_FILE, "")
            putObject(RoutingConstants.CONFIG_IMPORT_OSM_IGNORED_HIGHWAYS, "")
        }

        val hopper = GraphHopper().init(config)
        if (!hopper.load()) {
            try {
                hopper.close()
            } catch (_: Exception) {}
            throw IllegalStateException("${RoutingConstants.ERR_GRAPH_DATA_INCOMPLETE} at ${graphDirectory.absolutePath}")
        }

        return GraphHopperEngineWrapper(hopper)
    }

    private class GraphHopperEngineWrapper(
        private val hopper: GraphHopper
    ) : IGraphHopperEngine {

        private val translation: Translation by lazy {
            try {
                TranslationMap().doImport().get(RoutingConstants.DEFAULT_LOCALE)
            } catch (_: Exception) {
                TranslationMap().doImport().get("en")
            }
        }

        override fun route(
            fromLat: Double,
            fromLon: Double,
            toLat: Double,
            toLon: Double,
            vehicleProfile: String
        ): RouteResult {
            val startTime = System.currentTimeMillis()

            return try {
                val request = GHRequest(fromLat, fromLon, toLat, toLon)
                if (vehicleProfile.isNotEmpty()) {
                    request.profile = vehicleProfile
                }

                val response: GHResponse = hopper.route(request)
                val elapsed = System.currentTimeMillis() - startTime

                if (response.hasErrors()) {
                    val errors = response.errors.joinToString("; ") { it.message ?: "Unknown error" }
                    return RouteResult.failure("${RoutingConstants.ERR_ROUTING_PREFIX}$errors", elapsed)
                }

                if (response.all.isEmpty()) {
                    return RouteResult.failure(RoutingConstants.ERR_NO_ROUTE_FOUND, elapsed)
                }

                val path: ResponsePath = response.best
                    ?: return RouteResult.failure(RoutingConstants.ERR_NO_ROUTE_FOUND, elapsed)

                // Trích xuất danh sách tọa độ Polyline [lat, lon]
                val pointList = path.points
                val points = ArrayList<List<Double>>(pointList.size())
                for (i in 0 until pointList.size()) {
                    points.add(listOf(pointList.getLat(i), pointList.getLon(i)))
                }

                // Trích xuất danh sách hướng dẫn rẽ (Turn-by-turn Instructions) có mô tả hành động
                val instructionList = path.instructions
                val instructions = ArrayList<RouteInstruction>(instructionList?.size ?: 0)
                if (instructionList != null) {
                    for (ins: Instruction in instructionList) {
                        val insPoints = ArrayList<List<Double>>(ins.points.size())
                        for (j in 0 until ins.points.size()) {
                            insPoints.add(listOf(ins.points.getLat(j), ins.points.getLon(j)))
                        }

                        val street = ins.name ?: ""
                        val turnDescription = try {
                            ins.getTurnDescription(translation)
                        } catch (_: Exception) {
                            ""
                        }

                        val text = when {
                            turnDescription.isNotBlank() -> turnDescription
                            street.isNotBlank() -> street
                            else -> RoutingConstants.DEFAULT_INSTRUCTION_TEXT
                        }

                        instructions.add(
                            RouteInstruction(
                                text = text,
                                streetName = street,
                                distance = ins.distance,
                                time = ins.time,
                                sign = ins.sign,
                                points = insPoints
                            )
                        )
                    }
                }

                // Tính toán Bounding Box [minLon, minLat, maxLon, maxLat]
                val bbox: List<Double>? = if (points.isNotEmpty()) {
                    var minLat = points[0][0]
                    var maxLat = points[0][0]
                    var minLon = points[0][1]
                    var maxLon = points[0][1]
                    for (p in points) {
                        val lat = p[0]
                        val lon = p[1]
                        if (lat < minLat) minLat = lat
                        if (lat > maxLat) maxLat = lat
                        if (lon < minLon) minLon = lon
                        if (lon > maxLon) maxLon = lon
                    }
                    listOf(minLon, minLat, maxLon, maxLat)
                } else null

                RouteResult(
                    isSuccess = true,
                    distance = path.distance,
                    time = path.time,
                    points = points,
                    bbox = bbox,
                    instructions = instructions,
                    calculationTimeMs = elapsed
                )
            } catch (e: Exception) {
                val elapsed = System.currentTimeMillis() - startTime
                RouteResult.failure("${RoutingConstants.ERR_ROUTING_EXCEPTION}${e.message}", elapsed)
            }
        }

        override fun close() {
            hopper.close()
        }
    }
}
