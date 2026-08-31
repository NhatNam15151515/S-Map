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
            putObject("graph.encoded_values", "road_class,road_environment,road_access,max_speed")
            // Giữ weighting=custom + CustomModel vì GraphHopper 8.0 bắt buộc.
            // Graph data được build với profile này trên desktop JVM (Janino hoạt động).
            // Trên Android, Janino KHÔNG hoạt động nhưng CH đã pre-computed nên
            // routing thực tế chỉ dùng shortcuts, không cần compile expressions.
            setProfiles(listOf(
                Profile("moped_vn")
                    .setVehicle("car")
                    .setWeighting("custom")
                    .setCustomModel(Jackson.newObjectMapper().readValue(CUSTOM_MODEL_JSON, CustomModel::class.java))
            ))
            setCHProfiles(listOf(
                CHProfile("moped_vn")
            ))
        }

        val hopper = GraphHopper().init(config)

        // GraphHopper 8.0 gọi checkProfilesConsistency() bên trong load(),
        // nó compile custom model expressions bằng Janino → FAIL trên Android.
        // Workaround: bỏ qua lỗi Janino bằng Reflection, vì CH đã pre-computed.
        val loadSuccess = try {
            hopper.load()
        } catch (e: IllegalArgumentException) {
            if (e.message?.contains("can't load this type of class file") == true ||
                e.message?.contains("Cannot compile expression") == true) {
                // Lỗi Janino trên Android → bypass checkProfilesConsistency bằng Reflection
                Log.w(TAG, "Janino incompatible on Android (expected). Bypassing with Reflection...")
                loadGraphWithReflection(hopper, graphDirectory)
            } else {
                Log.e(TAG, "hopper.load() threw unexpected error: ${e.message}", e)
                try { hopper.close() } catch (_: Exception) {}
                throw e
            }
        } catch (e: Exception) {
            Log.e(TAG, "hopper.load() threw exception: ${e.message}", e)
            try { hopper.close() } catch (_: Exception) {}
            throw e
        }

        if (!loadSuccess) {
            try { hopper.close() } catch (_: Exception) {}
            Log.e(TAG, "Graph load failed for ${graphDirectory.absolutePath}")
            throw IllegalStateException("${RoutingConstants.ERR_GRAPH_DATA_INCOMPLETE} at ${graphDirectory.absolutePath}")
        }

        val baseGraph = hopper.baseGraph
        val nodeCount = baseGraph?.nodes ?: 0
        val edgeCount = baseGraph?.edges ?: 0
        Log.i(TAG, "GraphHopper READY from ${graphDirectory.absolutePath}! (Nodes: $nodeCount, Edges: $edgeCount)")
        return GraphHopperEngineWrapper(hopper)
    }

    /**
     * Bypass cả checkProfilesConsistency() LẪN loadOrPrepareCH() bằng Reflection.
     *
     * Cả 2 method đều cần Janino (compile custom model expressions) → FAIL trên Android.
     * Nhưng CH shortcuts ĐÃ pre-computed trên desktop JVM và stored trong graph files.
     *
     * Khi load() fail tại checkProfilesConsistency, đã hoàn thành:
     * ✅ properties, encodingManager, baseGraph loaded
     *
     * Cần gọi thủ công:
     * 1. initLocationIndex() - init location index
     * 2. Load CH storage trực tiếp từ files (skip createCHConfigs)
     * 3. directory.loadMMap()
     * 4. setFullyLoaded()
     */
    private fun loadGraphWithReflection(hopper: GraphHopper, graphDirectory: File): Boolean {
        return try {
            // 1. initLocationIndex()
            val initLocMethod = GraphHopper::class.java.getDeclaredMethod("initLocationIndex")
            initLocMethod.isAccessible = true
            initLocMethod.invoke(hopper)
            Log.i(TAG, "Reflection: initLocationIndex() OK")

            // 2. Load CH data trực tiếp bằng CHPreparationHandler
            // Tạo CHConfig thủ công KHÔNG cần Janino
            val baseGraph = hopper.baseGraph!!
            val profilesByNameField = GraphHopper::class.java.getDeclaredField("profilesByName")
            profilesByNameField.isAccessible = true
            @Suppress("UNCHECKED_CAST")
            val profilesByName = profilesByNameField.get(hopper) as Map<String, Profile>
            val profile = profilesByName["moped_vn"]!!

            // Tạo CHConfig với FastestWeighting (không cần Janino)
            val encodingManager = hopper.encodingManager
            val vehicleSpeed = encodingManager.getDecimalEncodedValue(
                com.graphhopper.routing.ev.VehicleSpeed.key("car")
            )
            val vehicleAccess = encodingManager.getBooleanEncodedValue(
                com.graphhopper.routing.ev.VehicleAccess.key("car")
            )
            val turnCostProvider = com.graphhopper.routing.weighting.TurnCostProvider.NO_TURN_COST_PROVIDER
            val fastestWeighting = com.graphhopper.routing.weighting.FastestWeighting(
                vehicleAccess, vehicleSpeed, turnCostProvider
            )

            val chConfig = com.graphhopper.storage.CHConfig.nodeBased(profile.name, fastestWeighting)
            val chConfigs = listOf(chConfig)

            // Gọi CHPreparationHandler.load(baseGraph, chConfigs)
            val chHandlerField = GraphHopper::class.java.getDeclaredField("chPreparationHandler")
            chHandlerField.isAccessible = true
            val chHandler = chHandlerField.get(hopper) as com.graphhopper.routing.ch.CHPreparationHandler
            val existingCHGraphs = chHandler.load(baseGraph.baseGraph, chConfigs)
            Log.i(TAG, "Reflection: CH loaded, found ${existingCHGraphs.size} CH graphs")

            // Set chGraphs field — load() trả về Map<String, RoutingCHGraph>
            val chGraphsField = GraphHopper::class.java.getDeclaredField("chGraphs")
            chGraphsField.isAccessible = true
            val chGraphsMap = LinkedHashMap<String, com.graphhopper.storage.RoutingCHGraph>()
            for ((profileName, chGraph) in existingCHGraphs) {
                chGraphsMap[profileName] = chGraph
            }
            chGraphsField.set(hopper, chGraphsMap)
            Log.i(TAG, "Reflection: chGraphs set with ${chGraphsMap.size} entries")

            // 3. directory.loadMMap()
            val directory = baseGraph.directory
            try {
                val loadMMapMethod = directory.javaClass.getMethod("loadMMap")
                loadMMapMethod.invoke(directory)
                Log.i(TAG, "Reflection: directory.loadMMap() OK")
            } catch (_: NoSuchMethodException) {
                Log.i(TAG, "Reflection: directory.loadMMap() not available (might be DAT mode)")
            }

            // 4. setFullyLoaded()
            val setFullyLoadedMethod = GraphHopper::class.java.getDeclaredMethod("setFullyLoaded")
            setFullyLoadedMethod.isAccessible = true
            setFullyLoadedMethod.invoke(hopper)

            Log.i(TAG, "GraphHopper loaded via Reflection bypass (Janino-free) ✅")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Reflection bypass failed: ${e.message}", e)
            false
        }
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
            val startNano = System.nanoTime()
            return try {
                val locationIndex = hopper.locationIndex
                if (locationIndex == null) {
                    val elapsedMs = (System.nanoTime() - startNano) / 1_000_000L
                    return SnappedRoadPoint.notSnapped(lat, lon, "LocationIndex is null or not loaded", elapsedMs)
                }

                val vehicleAccess = hopper.encodingManager.getBooleanEncodedValue(
                    com.graphhopper.routing.ev.VehicleAccess.key("car")
                )
                val snap: Snap = locationIndex.findClosest(
                    lat,
                    lon,
                    com.graphhopper.routing.util.AccessFilter.allEdges(vehicleAccess)
                )
                val elapsedMs = (System.nanoTime() - startNano) / 1_000_000L

                if (!snap.isValid) {
                    return SnappedRoadPoint.notSnapped(lat, lon, RoutingConstants.ERR_NO_ROAD_FOUND, elapsedMs)
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
                    calculationTimeMs = elapsedMs
                )
            } catch (e: Exception) {
                val elapsedMs = (System.nanoTime() - startNano) / 1_000_000L
                SnappedRoadPoint.notSnapped(lat, lon, "${RoutingConstants.ERR_SNAP_EXCEPTION}${e.message}", elapsedMs)
            }
        }

        override fun close() {
            hopper.close()
        }
    }
}
