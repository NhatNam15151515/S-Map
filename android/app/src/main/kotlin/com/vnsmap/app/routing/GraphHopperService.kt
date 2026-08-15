package com.vnsmap.app.routing

import com.vnsmap.app.routing.engine.IGraphHopperEngine
import com.vnsmap.app.routing.factory.DefaultGraphHopperEngineFactory
import com.vnsmap.app.routing.factory.IGraphHopperEngineFactory
import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.utils.GhzExtractor
import com.vnsmap.app.routing.utils.IGhzExtractor
import java.io.File

class GraphHopperService(
    private val engineFactory: IGraphHopperEngineFactory = DefaultGraphHopperEngineFactory(),
    private val ghzExtractor: IGhzExtractor = GhzExtractor,
    @Volatile private var engineInstance: IGraphHopperEngine? = null
) : IGraphHopperService {

    @Volatile
    private var initialized = false

    private val lifecycleLock = Any()

    companion object {
        val instance: GraphHopperService by lazy { GraphHopperService() }
    }

    override fun init(graphPath: String): Boolean {
        return init(File(graphPath))
    }

    fun init(graphLocation: File): Boolean = synchronized(lifecycleLock) {
        dispose()

        return try {
            val targetDir: File = if (graphLocation.isFile && graphLocation.name.endsWith(RoutingConstants.GHZ_EXTENSION, ignoreCase = true)) {
                val extractedDir = File(
                    graphLocation.parentFile ?: File("."),
                    graphLocation.nameWithoutExtension + RoutingConstants.EXTRACTED_DIR_SUFFIX
                )
                val extractSuccess = ghzExtractor.extract(
                    graphLocation.absolutePath,
                    extractedDir.absolutePath,
                    overwrite = false
                )
                if (!extractSuccess) {
                    return false
                }
                extractedDir
            } else {
                graphLocation
            }

            if (!targetDir.exists() || !targetDir.isDirectory) {
                return false
            }

            engineInstance = engineFactory.createAndLoad(targetDir)
            initialized = true
            true
        } catch (_: Exception) {
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
    ): RouteResult = synchronized(lifecycleLock) {
        val engine = engineInstance
        if (!initialized || engine == null) {
            return RouteResult.failure(RoutingConstants.ERR_SERVICE_NOT_INITIALIZED)
        }

        return try {
            engine.route(fromLat, fromLon, toLat, toLon, vehicleProfile)
        } catch (e: Exception) {
            RouteResult.failure("${RoutingConstants.ERR_ROUTING_EXCEPTION}${e.message}")
        }
    }

    override fun isInitialized(): Boolean = synchronized(lifecycleLock) {
        initialized && engineInstance != null
    }

    override fun dispose() {
        synchronized(lifecycleLock) {
            try {
                engineInstance?.close()
            } catch (_: Exception) {
            } finally {
                engineInstance = null
                initialized = false
            }
        }
    }
}
