package com.vnsmap.app.routing

import com.graphhopper.GHRequest
import com.graphhopper.GHResponse
import com.graphhopper.GraphHopper
import com.graphhopper.ResponsePath
import com.graphhopper.util.Instruction
import com.vnsmap.app.routing.factory.DefaultGraphHopperEngineFactory
import com.vnsmap.app.routing.factory.IGraphHopperEngineFactory
import com.vnsmap.app.routing.models.RouteInstruction
import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.utils.GhzExtractor
import com.vnsmap.app.routing.utils.IGhzExtractor
import java.io.File

class GraphHopperService(
    private val engineFactory: IGraphHopperEngineFactory = DefaultGraphHopperEngineFactory(),
    private val ghzExtractor: IGhzExtractor = GhzExtractor,
    private var hopperInstance: GraphHopper? = null
) : IGraphHopperService {

    private var initialized = false

    companion object {
        val instance: GraphHopperService by lazy { GraphHopperService() }
    }

    override fun init(graphLocation: File): Boolean {
        dispose()

        return try {
            val targetDir: File = if (graphLocation.isFile && graphLocation.name.endsWith(RoutingConstants.GHZ_EXTENSION, ignoreCase = true)) {
                val extractedDir = File(graphLocation.parentFile, graphLocation.nameWithoutExtension + RoutingConstants.EXTRACTED_DIR_SUFFIX)
                ghzExtractor.extract(graphLocation, extractedDir, overwrite = false)
                extractedDir
            } else {
                graphLocation
            }

            if (!targetDir.exists() || !targetDir.isDirectory) {
                return false
            }

            hopperInstance = engineFactory.createAndLoad(targetDir)
            initialized = true
            true
        } catch (e: Exception) {
            e.printStackTrace()
            dispose()
            false
        }
    }

    override fun route(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
        vehicleProfile: String
    ): RouteResult {
        val hopper = hopperInstance
        if (!initialized || hopper == null) {
            return RouteResult.failure(RoutingConstants.ERR_SERVICE_NOT_INITIALIZED)
        }

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

            val path: ResponsePath = response.best
                ?: return RouteResult.failure(RoutingConstants.ERR_NO_ROUTE_FOUND, elapsed)

            // Extract Polyline coordinates [lat, lon]
            val pointList = path.points
            val points = ArrayList<List<Double>>(pointList.size())
            for (i in 0 until pointList.size()) {
                points.add(listOf(pointList.getLat(i), pointList.getLon(i)))
            }

            // Extract Turn-by-turn Instructions
            val instructionList = path.instructions
            val instructions = ArrayList<RouteInstruction>(instructionList?.size ?: 0)
            if (instructionList != null) {
                for (ins: Instruction in instructionList) {
                    val insPoints = ArrayList<List<Double>>(ins.points.size())
                    for (j in 0 until ins.points.size()) {
                        insPoints.add(listOf(ins.points.getLat(j), ins.points.getLon(j)))
                    }

                    val street = ins.name ?: ""
                    val text = if (street.isNotEmpty()) street else RoutingConstants.DEFAULT_INSTRUCTION_TEXT

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

            // Calculate Bounding Box [minLon, minLat, maxLon, maxLat]
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
            } else {
                null
            }

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

    override fun isInitialized(): Boolean = initialized && hopperInstance != null

    override fun dispose() {
        try {
            hopperInstance?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            hopperInstance = null
            initialized = false
        }
    }
}
