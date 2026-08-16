package com.vnsmap.app.routing

import android.util.Log
import com.vnsmap.app.routing.engine.IGraphHopperEngine
import com.vnsmap.app.routing.factory.DefaultGraphHopperEngineFactory
import com.vnsmap.app.routing.factory.IGraphHopperEngineFactory
import com.vnsmap.app.routing.models.RouteResult
import com.vnsmap.app.routing.utils.GhzExtractor
import com.vnsmap.app.routing.utils.IGhzExtractor
import java.io.File
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

class GraphHopperService(
    private val engineFactory: IGraphHopperEngineFactory = DefaultGraphHopperEngineFactory(),
    private val ghzExtractor: IGhzExtractor = GhzExtractor,
    @Volatile private var engineInstance: IGraphHopperEngine? = null
) : IGraphHopperService {

    @Volatile
    private var initialized = false

    private val rwLock = ReentrantReadWriteLock()

    companion object {
        private const val TAG = "GraphHopperService"
        val instance: GraphHopperService by lazy { GraphHopperService() }
    }

    override fun init(graphPath: String): Boolean {
        return init(File(graphPath))
    }

    fun init(graphLocation: File): Boolean = rwLock.write(action = {
        disposeInternal()

        return try {
            Log.i(TAG, "Initializing GraphHopper from location: ${graphLocation.absolutePath}")
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
                    Log.e(TAG, "Failed to extract .ghz archive to ${extractedDir.absolutePath}")
                    return false
                }
                extractedDir
            } else {
                graphLocation
            }

            if (!targetDir.exists() || !targetDir.isDirectory) {
                Log.e(TAG, "Target directory does not exist or is not a directory: ${targetDir.absolutePath}")
                return false
            }

            engineInstance = engineFactory.createAndLoad(targetDir)
            initialized = true
            Log.i(TAG, "GraphHopper successfully initialized!")
            true
        } catch (e: Exception) {
            Log.e(TAG, "GraphHopper init failed: ${e.message}", e)
            disposeInternal()
            false
        }
    })

    override fun route(
        fromLat: Double,
        fromLon: Double,
        toLat: Double,
        toLon: Double,
        vehicleProfile: String
    ): RouteResult = rwLock.read(action = {
        val engine = engineInstance
        if (!initialized || engine == null) {
            return RouteResult.failure(RoutingConstants.ERR_SERVICE_NOT_INITIALIZED)
        }

        return try {
            engine.route(fromLat, fromLon, toLat, toLon, vehicleProfile)
        } catch (e: Exception) {
            RouteResult.failure("${RoutingConstants.ERR_ROUTING_EXCEPTION}${e.message}")
        }
    })

    override fun isInitialized(): Boolean = rwLock.read(action = {
        initialized && engineInstance != null
    })

    override fun dispose() {
        rwLock.write(action = {
            disposeInternal()
        })
    }

    private fun disposeInternal() {
        try {
            engineInstance?.close()
        } catch (_: Exception) {
        } finally {
            engineInstance = null
            initialized = false
        }
    }
}
