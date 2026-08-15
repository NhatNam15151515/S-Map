package com.vnsmap.app.routing.factory

import com.graphhopper.GraphHopper
import com.graphhopper.GraphHopperConfig
import com.vnsmap.app.routing.RoutingConstants
import java.io.File

class DefaultGraphHopperEngineFactory : IGraphHopperEngineFactory {

    override fun createAndLoad(graphDirectory: File): GraphHopper {
        val config = GraphHopperConfig().apply {
            putObject(RoutingConstants.CONFIG_GRAPH_DATAACCESS, RoutingConstants.STORAGE_DAT_MMAP)
            putObject(RoutingConstants.CONFIG_GRAPH_LOCATION, graphDirectory.absolutePath)
            putObject(RoutingConstants.CONFIG_DATAREADER_FILE, "")
            putObject(RoutingConstants.CONFIG_IMPORT_OSM_IGNORED_HIGHWAYS, "")
        }

        val hopper = GraphHopper().init(config)
        hopper.load()
        return hopper
    }
}
