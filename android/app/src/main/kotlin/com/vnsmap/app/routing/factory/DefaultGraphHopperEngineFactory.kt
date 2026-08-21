package com.vnsmap.app.routing.factory

import android.util.Log
import com.graphhopper.GHRequest
import com.graphhopper.GHResponse
import com.graphhopper.GraphHopper
import com.graphhopper.GraphHopperConfig
import com.graphhopper.ResponsePath
import com.graphhopper.config.CHProfile
import com.graphhopper.config.Profile
import com.graphhopper.jackson.Jackson
import com.graphhopper.routing.util.EdgeFilter
import com.graphhopper.storage.index.Snap
import com.graphhopper.util.CustomModel
import com.graphhopper.util.Instruction
import com.graphhopper.util.Translation
import com.graphhopper.util.TranslationMap
import com.vnsmap.app.routing.RoutingConstants
import com.vnsmap.app.routing.engine.IGraphHopperEngine
import com.vnsmap.app.routing.models.RouteInstruction
import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.models.SnappedRoadPoint
import java.io.File

class DefaultGraphHopperEngineFactory : IGraphHopperEngineFactory {

    companion object {
        private const val TAG = "GraphHopperFactory"

        private val CUSTOM_MODEL_JSON = """
        {
          "priority": [
            {
              "if": "road_class == MOTORWAY || road_class == STEPS || road_class == FOOTWAY || road_class == PEDESTRIAN || road_class == CYCLEWAY",
              "multiply_by": 0.0
            },
            {
              "else_if": "road_class == TRUNK && max_speed > 60",
              "multiply_by": 0.0
            },
            {
              "else_if": "road_class == TRUNK",
              "multiply_by": 0.4
            },
            {
              "else_if": "road_class == PRIMARY",
              "multiply_by": 0.7
            },
            {
              "else_if": "road_class == SECONDARY",
              "multiply_by": 0.9
            },
            {
              "else_if": "road_class == TERTIARY || road_class == RESIDENTIAL",
              "multiply_by": 1.0
            },
            {
              "else_if": "road_class == LIVING_STREET",
              "multiply_by": 0.9
            },
            {
              "else_if": "road_class == SERVICE",
              "multiply_by": 0.9
            },
            {
              "else_if": "road_class == UNCLASSIFIED",
              "multiply_by": 0.7
            },
            {
              "else_if": "road_class == TRACK",
              "multiply_by": 0.3
            },
            {
              "if": "road_access == PRIVATE || road_access == NO",
              "multiply_by": 0.0
            },
            {
              "if": "road_access == DESTINATION || road_access == DELIVERY",
              "multiply_by": 0.1
            },
            {
              "if": "road_environment == FERRY",
              "multiply_by": 0.0
            },
            {
              "if": "road_environment == TUNNEL",
              "multiply_by": 0.3
            },
            {
              "if": "lanes > 4 && road_class == TRUNK",
              "multiply_by": 0.0
            },
            {
              "if": "lanes > 4 && road_class == PRIMARY",
              "multiply_by": 0.3
            },
            {
              "if": "surface == DIRT || surface == SAND",
              "multiply_by": 0.3
            },
            {
              "else_if": "surface == GRAVEL",
              "multiply_by": 0.5
            },
            {
              "if": "toll == ALL || toll == HGV",
              "multiply_by": 0.1
            }
          ],
          "speed": [
            {
              "if": "road_class == TRUNK",
              "limit_to": 50
            },
            {
              "else_if": "road_class == PRIMARY",
              "limit_to": 40
            },
            {
              "else_if": "road_class == SECONDARY",
              "limit_to": 40
            },
            {
              "else_if": "road_class == TERTIARY",
              "limit_to": 35
            },
            {
              "else_if": "road_class == RESIDENTIAL",
              "limit_to": 30
            },
            {
              "else_if": "road_class == LIVING_STREET || road_class == SERVICE",
              "limit_to": 20
            },
            {
              "else_if": "road_class == UNCLASSIFIED",
              "limit_to": 25
            },
            {
              "else_if": "road_class == TRACK",
              "limit_to": 15
            },
            {
              "if": "surface == SAND",
              "limit_to": 10
            },
            {
              "else_if": "surface == GRAVEL || surface == DIRT",
              "limit_to": 15
            }
          ],
          "distance_influence": 50
        }
        """.trimIndent()
    }

    override fun createAndLoad(graphDirectory: File): IGraphHopperEngine {
        Log.i(TAG, "Loading GraphHopper from directory: ${graphDirectory.absolutePath}")

        val config = GraphHopperConfig().apply {
            putObject(RoutingConstants.CONFIG_GRAPH_DATAACCESS, RoutingConstants.STORAGE_DAT_MMAP)
            putObject(RoutingConstants.CONFIG_GRAPH_LOCATION, graphDirectory.absolutePath)
            putObject(RoutingConstants.CONFIG_DATAREADER_FILE, "")
            putObject(RoutingConstants.CONFIG_IMPORT_OSM_IGNORED_HIGHWAYS, "")
            putObject("graph.encoded_values", "road_class,road_environment,road_access,surface,toll,max_speed,lanes,country")
            setProfiles(listOf(
                Profile("moped_vn")
                    .setVehicle("car")
                    .setWeighting("custom")
                    .setCustomModel(CustomModel().apply { distanceInfluence = null })
            ))
            setCHProfiles(listOf(
                CHProfile("moped_vn")
            ))
        }

        val hopper = object : GraphHopper() {
            override fun createWeightingFactory(): com.graphhopper.routing.WeightingFactory {
                return com.graphhopper.routing.WeightingFactory { profile, _, _ ->
                    val accessEnc = encodingManager.getBooleanEncodedValue(
                        com.graphhopper.routing.ev.VehicleAccess.key(profile.vehicle)
                    )
                    val avSpeedEnc = encodingManager.getDecimalEncodedValue(
                        com.graphhopper.routing.ev.VehicleSpeed.key(profile.vehicle)
                    )
                    com.graphhopper.routing.weighting.FastestWeighting(accessEnc, avSpeedEnc)
                }
            }
        }.init(config)
        val loadSuccess = try {
            hopper.load()
        } catch (e: Exception) {
            Log.e(TAG, "hopper.load() threw exception: ${e.message}", e)
            println("❌ [GraphHopper Native Error] ${e.javaClass.simpleName}: ${e.message}")
            e.printStackTrace()
            try { hopper.close() } catch (_: Exception) {}
            throw e
        }

        if (!loadSuccess) {
            try {
                hopper.close()
            } catch (_: Exception) {}
            Log.e(TAG, "hopper.load() returned false for ${graphDirectory.absolutePath}")
            println("❌ [GraphHopper Native Error] hopper.load() returned false for ${graphDirectory.absolutePath}")
            throw IllegalStateException("${RoutingConstants.ERR_GRAPH_DATA_INCOMPLETE} at ${graphDirectory.absolutePath}")
        }

        Log.i(TAG, "GraphHopper successfully loaded from ${graphDirectory.absolutePath}!")
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

        override fun snapToRoad(lat: Double, lon: Double): SnappedRoadPoint {
            val startTime = System.currentTimeMillis()
            return try {
                val locationIndex = hopper.locationIndex
                if (locationIndex == null) {
                    val elapsed = System.currentTimeMillis() - startTime
                    return SnappedRoadPoint.notSnapped(lat, lon, "LocationIndex is null or not loaded", elapsed)
                }

                val snap: Snap = locationIndex.findClosest(lat, lon, EdgeFilter.ALL_EDGES)
                val elapsed = System.currentTimeMillis() - startTime

                if (!snap.isValid) {
                    return SnappedRoadPoint.notSnapped(lat, lon, RoutingConstants.ERR_NO_ROAD_FOUND, elapsed)
                }

                val snappedPoint = snap.snappedPoint
                val edge = snap.closestEdge
                val streetName = edge?.name ?: ""
                val distance = snap.queryDistance
                val edgeId = edge?.edge ?: -1

                SnappedRoadPoint(
                    isSnapped = true,
                    originalLat = lat,
                    originalLon = lon,
                    snappedLat = snappedPoint.lat,
                    snappedLon = snappedPoint.lon,
                    streetName = streetName,
                    distanceToRoad = distance,
                    edgeId = edgeId,
                    calculationTimeMs = elapsed
                )
            } catch (e: Exception) {
                val elapsed = System.currentTimeMillis() - startTime
                SnappedRoadPoint.notSnapped(lat, lon, "${RoutingConstants.ERR_SNAP_EXCEPTION}${e.message}", elapsed)
            }
        }

        override fun close() {
            hopper.close()
        }
    }
}
